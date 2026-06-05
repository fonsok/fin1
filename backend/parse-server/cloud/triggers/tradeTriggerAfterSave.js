'use strict';

const {
  bookTraderBuyEntryIfMissing,
  bookTraderSellDeltaIfAny,
  bookInvestorPartialRealizationDeltaIfAny,
} = require('../utils/accountingHelper');
const {
  syncMirrorTradeWhenTraderLegCompletes,
  syncMirrorPoolSellProgressFromTraderLeg,
} = require('../utils/pairedTradeMirrorSync');
const {
  enqueueSettlementRetry,
  processDueSettlementRetries,
} = require('../utils/accountingHelper/retryQueue');
const { audit } = require('../utils/structuredLogger');
const { logTradeAudit } = require('./tradeTriggerAudit');
const { ensurePoolActivationForNewTrade } = require('./tradeTriggerPoolActivation');
const {
  hasOrderOrchestrationMarker,
  isMirrorPoolTradeLeg,
} = require('../services/poolMirrorActivation/poolActivationPolicy');
const { applyPartialSellRealizationToInvestments } = require('./tradeTriggerPartialSell');

/**
 * Settlement aus dem synchronen afterSave-Pfad auslagern: Job + kurzer Drain über den
 * bestehenden SettlementRetryWorker (main.js setInterval), damit der Trade-Save nicht
 * die volle O(N)-Abrechnung blockiert. Mirror-Sync bleibt davor await, damit Pool-Ökonomie
 * konsistent ist, bevor der Worker läuft.
 */
function scheduleSettlementAfterTradeComplete(trade, source) {
  if (isMirrorPoolTradeLeg(trade)) {
    console.log(
      `ℹ️ Trade #${trade.get('tradeNumber')} MIRROR_POOL leg — skip trader settlement enqueue `
      + '(pool economics settle via TRADER leg settleAndDistribute)',
    );
    return;
  }

  const tradeId = trade.id;
  const tradeNumber = trade.get('tradeNumber') || null;
  const businessCaseIdRaw = trade.get('businessCaseId');
  const businessCaseId = businessCaseIdRaw != null && String(businessCaseIdRaw).trim() !== ''
    ? String(businessCaseIdRaw).trim()
    : null;
  void enqueueSettlementRetry({
    tradeId,
    reason: 'trade_status_completed',
    source,
    context: { tradeNumber },
  })
    .then(() => {
      setImmediate(() => {
        processDueSettlementRetries({ limit: 15 })
          .then((result) => {
            if (Number(result?.processed || 0) > 0) {
              audit.info('settlement.retry.trigger.drain', {
                tradeId,
                tradeNumber,
                businessCaseId,
                source,
                processed: result.processed,
                message: 'Trade after-save settlement drain processed job(s)',
              });
            }
          })
          .catch((err) => {
            audit.error('settlement.retry.trigger.drainFailure', {
              tradeId,
              tradeNumber,
              businessCaseId,
              source,
              error: err && err.message ? err.message : String(err),
              stack: err && err.stack ? err.stack : undefined,
              message: 'Trade after-save settlement drain failed',
            });
          });
      });
    })
    .catch((err) => {
      audit.error('settlement.retry.trigger.enqueueFailure', {
        tradeId,
        tradeNumber,
        businessCaseId,
        source,
        error: err && err.message ? err.message : String(err),
        stack: err && err.stack ? err.stack : undefined,
        message: 'Trade after-save settlement enqueue failed',
      });
    });
}

Parse.Cloud.afterSave('Trade', async (request) => {
  const trade = request.object;
  const isNew = !request.original;
  const isMirrorLeg = isMirrorPoolTradeLeg(trade);

  if (isNew) {
    const initialStatus = trade.get('status') || 'pending';
    await logTradeAudit('Trade', trade.id, 'created', null, { status: initialStatus });
    if (!isMirrorLeg) {
      try {
        await bookTraderBuyEntryIfMissing(trade);
      } catch (err) {
        console.error(`❌ Trade #${trade.get('tradeNumber')} immediate trade_buy booking failed:`, err.message, err.stack);
      }
    }
    try {
      // Pool mirror (RSV→PTR) SSOT: paired buys via Order MIRROR_POOL leg only.
      // Legacy client upsertTrade trades without order orchestration markers only.
      if (!hasOrderOrchestrationMarker(trade)) {
        await ensurePoolActivationForNewTrade(trade);
      }
    } catch (err) {
      console.error(`❌ Trade #${trade.get('tradeNumber')} pool activation failed:`, err.message, err.stack);
    }
    if (initialStatus === 'completed' && !isMirrorLeg) {
      try {
        await syncMirrorTradeWhenTraderLegCompletes(trade);
      } catch (err) {
        console.error(`❌ Trade #${trade.get('tradeNumber')} paired mirror sync (on-create) failed:`, err.message, err.stack);
      }
      scheduleSettlementAfterTradeComplete(trade, 'trade_after_save_create_completed');
    }
  }

  if (request.original) {
    const oldStatus = request.original.get('status');
    const newStatus = trade.get('status');
    const willCompleteOnThisSave = newStatus === 'completed' && oldStatus !== 'completed';

    if (!isMirrorLeg) {
      try {
        if (!willCompleteOnThisSave) {
          await bookTraderSellDeltaIfAny({
            trade,
            previousTrade: request.original,
          });
          try {
            await syncMirrorPoolSellProgressFromTraderLeg(trade);
          } catch (err) {
            console.error(
              `❌ Trade #${trade.get('tradeNumber')} paired mirror partial-sell sync failed:`,
              err.message,
              err.stack,
            );
          }
        } else {
          console.log(
            `ℹ️ Trade #${trade.get('tradeNumber')} completes on this save — skipping trade_sell delta; settlement queued`,
          );
        }
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
          console.log(`ℹ️ Trade #${trade.get('tradeNumber')} completes on this save — skipping partial-sell delta path; settlement queued`);
        }
      } catch (err) {
        console.error(`❌ Trade #${trade.get('tradeNumber')} immediate trade_sell booking failed:`, err.message, err.stack);
      }
    } else if (!willCompleteOnThisSave) {
      console.log(
        `ℹ️ Trade #${trade.get('tradeNumber')} MIRROR_POOL leg update — skip trader sell/partial booking hooks`,
      );
    }

    if (oldStatus !== newStatus) {
      await logTradeAudit('Trade', trade.id, 'status_change',
        { status: oldStatus }, { status: newStatus });

      if (newStatus === 'completed' && !isMirrorLeg) {
        try {
          await syncMirrorTradeWhenTraderLegCompletes(trade);
        } catch (err) {
          console.error(`❌ Trade #${trade.get('tradeNumber')} paired mirror sync failed:`, err.message, err.stack);
        }
        scheduleSettlementAfterTradeComplete(trade, 'trade_after_save_status_completed');
      }
    }
  }
});
