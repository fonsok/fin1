'use strict';

const {
  settleAndDistribute,
  bookTraderBuyEntryIfMissing,
  bookTraderSellDeltaIfAny,
  bookInvestorPartialRealizationDeltaIfAny,
} = require('../utils/accountingHelper');
const { syncMirrorTradeWhenTraderLegCompletes } = require('../utils/pairedTradeMirrorSync');
const { enqueueSettlementRetry } = require('../utils/accountingHelper/retryQueue');
const { logTradeAudit } = require('./tradeTriggerAudit');
const { ensurePoolActivationForNewTrade } = require('./tradeTriggerPoolActivation');
const { applyPartialSellRealizationToInvestments } = require('./tradeTriggerPartialSell');

Parse.Cloud.afterSave('Trade', async (request) => {
  const trade = request.object;
  const isNew = !request.original;

  if (isNew) {
    const initialStatus = trade.get('status') || 'pending';
    await logTradeAudit('Trade', trade.id, 'created', null, { status: initialStatus });
    try {
      await bookTraderBuyEntryIfMissing(trade);
    } catch (err) {
      console.error(`❌ Trade #${trade.get('tradeNumber')} immediate trade_buy booking failed:`, err.message, err.stack);
    }
    try {
      await ensurePoolActivationForNewTrade(trade);
    } catch (err) {
      console.error(`❌ Trade #${trade.get('tradeNumber')} pool activation failed:`, err.message, err.stack);
    }
    if (initialStatus === 'completed') {
      try {
        await syncMirrorTradeWhenTraderLegCompletes(trade);
      } catch (err) {
        console.error(`❌ Trade #${trade.get('tradeNumber')} paired mirror sync (on-create) failed:`, err.message, err.stack);
      }
      try {
        const settlement = await settleAndDistribute(trade);
        if (settlement) {
          console.log(`✅ Trade #${trade.get('tradeNumber')} settled on create: commission=€${settlement.totalCommission}, investors=${settlement.investorCount}`);
        }
      } catch (err) {
        console.error(`❌ Trade #${trade.get('tradeNumber')} settlement-on-create failed:`, err.message, err.stack);
        try {
          await enqueueSettlementRetry({
            tradeId: trade.id,
            reason: err.message || 'settlement-on-create failed',
            source: 'trade_after_save_create_completed',
            context: { tradeNumber: trade.get('tradeNumber') || null },
          });
        } catch (retryErr) {
          console.error(`❌ Trade #${trade.get('tradeNumber')} retry enqueue failed:`, retryErr.message, retryErr.stack);
        }
      }
    }
  }

  if (request.original) {
    const oldStatus = request.original.get('status');
    const newStatus = trade.get('status');
    const willCompleteOnThisSave = newStatus === 'completed' && oldStatus !== 'completed';
    try {
      await bookTraderSellDeltaIfAny({
        trade,
        previousTrade: request.original,
      });
      if (!willCompleteOnThisSave) {
        await bookInvestorPartialRealizationDeltaIfAny({
          trade,
          previousTrade: request.original,
        });
        await applyPartialSellRealizationToInvestments({
          trade,
          previousTrade: request.original,
        });
      } else {
        console.log(`ℹ️ Trade #${trade.get('tradeNumber')} completes on this save — skipping partial-sell delta path; settleAndDistribute handles the final state`);
      }
    } catch (err) {
      console.error(`❌ Trade #${trade.get('tradeNumber')} immediate trade_sell booking failed:`, err.message, err.stack);
    }

    if (oldStatus !== newStatus) {
      await logTradeAudit('Trade', trade.id, 'status_change',
        { status: oldStatus }, { status: newStatus });

      if (newStatus === 'completed') {
        try {
          await syncMirrorTradeWhenTraderLegCompletes(trade);
        } catch (err) {
          console.error(`❌ Trade #${trade.get('tradeNumber')} paired mirror sync failed:`, err.message, err.stack);
        }
        try {
          const settlement = await settleAndDistribute(trade);
          if (settlement) {
            console.log(`✅ Trade #${trade.get('tradeNumber')} fully settled: commission=€${settlement.totalCommission}, investors=${settlement.investorCount}`);
          }
        } catch (err) {
          console.error(`❌ Trade #${trade.get('tradeNumber')} settlement failed:`, err.message, err.stack);
          try {
            await enqueueSettlementRetry({
              tradeId: trade.id,
              reason: err.message || 'settlement failed',
              source: 'trade_after_save_status_completed',
              context: { tradeNumber: trade.get('tradeNumber') || null },
            });
          } catch (retryErr) {
            console.error(`❌ Trade #${trade.get('tradeNumber')} retry enqueue failed:`, retryErr.message, retryErr.stack);
          }
        }
      }
    }
  }
});
