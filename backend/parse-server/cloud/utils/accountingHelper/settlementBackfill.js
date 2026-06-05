'use strict';

const { round2 } = require('./shared');
const { computeInvestorBuyLeg } = require('./legs');
const { ensureBusinessCaseIdForTrade } = require('./businessCaseId');
const { bookAccountStatementEntry } = require('./statements');
const { audit } = require('../structuredLogger');
const {
  bookReserveCapitalTradeSplit,
  purgeReleaseTradingResidualCorrectionLeg,
  purgeTradingResidualReturnLeg,
  purgeReserveCapitalTradeSplitLeg,
  purgeDeployReversalForCapitalSplitLeg,
  hasEscrowLeg,
} = require('./investmentEscrow');
const { resolveDocumentReference } = require('./documentReferenceResolver');

async function backfillInvestmentFromBillMetadata({
  investment,
  bill,
  grossProfit,
  commission,
  netProfit,
}) {
  if (!investment) return;
  const meta = (bill && bill.get('metadata')) || {};
  const initialValue = investment.get('initialValue') || investment.get('amount') || 0;
  const updates = {};

  const currentProfit = Number(investment.get('profit') || 0);
  if (currentProfit === 0 && Number.isFinite(netProfit) && netProfit !== 0) {
    updates.profit = round2(netProfit);
  }

  const currentValue = Number(investment.get('currentValue') || 0);
  if (
    Number.isFinite(initialValue)
    && Number.isFinite(netProfit)
    && netProfit !== 0
    && (currentValue === 0 || currentValue === initialValue)
  ) {
    updates.currentValue = round2(initialValue + netProfit);
  }

  const totalCommissionPaid = Number(investment.get('totalCommissionPaid') || 0);
  if (totalCommissionPaid === 0 && Number.isFinite(commission) && commission > 0) {
    updates.totalCommissionPaid = round2(commission);
  }

  const numberOfTrades = Number(investment.get('numberOfTrades') || 0);
  if (numberOfTrades === 0) {
    updates.numberOfTrades = 1;
  }

  const profitPercentage = Number(investment.get('profitPercentage') || 0);
  if (
    profitPercentage === 0
    && Number.isFinite(initialValue)
    && initialValue > 0
    && Number.isFinite(netProfit)
    && netProfit !== 0
  ) {
    updates.profitPercentage = round2((netProfit / initialValue) * 100);
  }

  const totalBuyFromBill = round2(Number(meta.totalBuyCost ?? meta.poolTradingAmount ?? 0));
  if (totalBuyFromBill > 0) {
    const curPool = Number(investment.get('poolTradingAmount') || 0);
    if (
      !Number.isFinite(curPool)
      || curPool <= 0.005
      || Math.abs(curPool - totalBuyFromBill) > 0.02
    ) {
      updates.poolTradingAmount = totalBuyFromBill;
    }
  }

  const status = String(investment.get('status') || '');
  if (status !== 'completed') {
    updates.status = 'completed';
    if (!investment.get('completedAt')) {
      const billGenerated = meta.generatedAt
        || (bill && bill.get('createdAt') && new Date(bill.get('createdAt')).toISOString())
        || new Date().toISOString();
      updates.completedAt = billGenerated;
    }
  }

  if (Object.keys(updates).length === 0) return;

  for (const [key, value] of Object.entries(updates)) {
    investment.set(key, value);
  }
  await investment.save(null, { useMasterKey: true });
  audit.info('settlement.backfill.investment', {
    investmentId: investment.id,
    investmentNumber: investment.get('investmentNumber') || null,
    tradeId: bill && bill.get && bill.get('tradeId') ? bill.get('tradeId') : null,
    businessCaseId:
      (bill && bill.get && bill.get('businessCaseId'))
      || investment.get('businessCaseId')
      || null,
    billId: bill && bill.id ? bill.id : null,
    fields: Object.keys(updates),
    message: '🔧 backfillInvestmentFromBillMetadata: investment fields updated',
  });
}

async function backfillCommissionRecordIfMissing({
  traderId,
  investment,
  trade,
  participation,
  commission,
  createCommissionRecord,
}) {
  if (!Number.isFinite(commission) || commission <= 0) return;
  if (!investment || !trade || !participation) return;

  const existing = await new Parse.Query('Commission')
    .equalTo('tradeId', trade.id)
    .equalTo('investmentId', investment.id)
    .first({ useMasterKey: true });
  if (existing) return;

  await createCommissionRecord(traderId, investment, trade, participation, commission);
  console.log(`  🔧 Backfilled Commission record for investment ${investment.id} / trade ${trade.id}`);
}

async function backfillResidualReturnIfMissing({
  investorId,
  investmentId,
  trade,
  tradeNumber,
  bill,
  investment,
  participation,
  feeConfig,
  tradeBuyPrice,
}) {
  if (!investorId || !investmentId || !trade || !bill) return;

  const meta = bill.get('metadata') || {};
  const buyLeg = meta.buyLeg || {};
  let residualAmount = Number(buyLeg.residualAmount || 0);

  if ((!Number.isFinite(residualAmount) || residualAmount <= 0) && investment) {
    const investmentCapital = Number(investment.get('amount') || 0);
    if (
      Number.isFinite(investmentCapital)
      && investmentCapital > 0
      && Number.isFinite(tradeBuyPrice)
      && tradeBuyPrice > 0
    ) {
      try {
        const recomputed = computeInvestorBuyLeg(investmentCapital, tradeBuyPrice, feeConfig || {});
        if (recomputed && Number.isFinite(recomputed.residualAmount) && recomputed.residualAmount > 0) {
          residualAmount = recomputed.residualAmount;
        }
      } catch (_) { /* fall through — leave residualAmount as-is */ }
    }
  }

  if ((!Number.isFinite(residualAmount) || residualAmount <= 0) && investment && participation) {
    const investmentCapital = Number(investment.get('amount') || 0);
    const allocated = Number(participation.get('allocatedAmount') || 0);
    if (Number.isFinite(investmentCapital) && Number.isFinite(allocated) && investmentCapital > allocated) {
      residualAmount = round2(investmentCapital - allocated);
    }
  }

  if (!Number.isFinite(residualAmount) || residualAmount <= 0) return;

  const investmentNumber = investment ? String(investment.get('investmentNumber') || '').trim() : '';
  const businessCaseId = await ensureBusinessCaseIdForTrade(trade);
  const residualRounded = round2(residualAmount);
  const nominal = investment ? round2(Number(investment.get('amount') || 0)) : 0;

  await purgeReleaseTradingResidualCorrectionLeg(investmentId, trade.id);
  await purgeTradingResidualReturnLeg(investmentId, trade.id);
  await purgeReserveCapitalTradeSplitLeg(investmentId, trade.id);
  await purgeDeployReversalForCapitalSplitLeg(investmentId, trade.id);

  if (nominal > 0 && !(await hasEscrowLeg(investmentId, 'reserveCapitalTradeSplit', { tradeId: trade.id }))) {
    await bookReserveCapitalTradeSplit({
      investorId,
      nominal,
      tradingAmount: round2(nominal - residualRounded),
      availableAmount: residualRounded,
      investmentId,
      investmentNumber,
      tradeId: trade.id,
      tradeNumber,
      businessCaseId,
    });
  }

  const existing = await new Parse.Query('AccountStatement')
    .equalTo('userId', investorId)
    .equalTo('investmentId', investmentId)
    .equalTo('tradeId', trade.id)
    .equalTo('entryType', 'residual_return')
    .equalTo('source', 'backend')
    .first({ useMasterKey: true });
  if (existing) return;

  await bookAccountStatementEntry({
    userId: investorId,
    entryType: 'residual_return',
    amount: residualRounded,
    tradeId: trade.id,
    tradeNumber,
    investmentId,
    investmentNumber,
    description: investmentNumber
      ? `Restbetrag aus Investment ${investmentNumber}`
      : `Restbetrag aus Investment (Rundungsdifferenz Stückkauf)`,
    ...resolveDocumentReference(bill, { context: 'residual_return_backfill' }),
    businessCaseId,
  });
  console.log(`  🔧 Backfilled residual_return €${residualRounded} for investor ${investorId} / trade ${trade.id}`);
}

module.exports = {
  backfillInvestmentFromBillMetadata,
  backfillCommissionRecordIfMissing,
  backfillResidualReturnIfMissing,
};
