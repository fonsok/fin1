'use strict';

const { round2 } = require('./shared');
const {
  backfillInvestmentFromBillMetadata,
  backfillCommissionRecordIfMissing,
  backfillResidualReturnIfMissing,
} = require('./settlementBackfill');
const { createCommissionRecord } = require('./settlementSupport');

async function trySettleFromExistingBill({
  participation,
  investment,
  traderId,
  trade,
  tradeNumber,
  commissionRate,
  feeConfig,
  tradeBuyPrice,
}) {
  const existingBill = await new Parse.Query('Document')
    .equalTo('type', 'investorCollectionBill')
    .equalTo('investmentId', investment.id)
    .equalTo('tradeId', trade.id)
    .equalTo('source', 'backend')
    .first({ useMasterKey: true });
  if (!existingBill) return null;

  const investorId = investment.get('investorId');
  const meta = existingBill.get('metadata') || {};
  const existingGross = Number(meta.grossProfit);
  const existingComm = Number(meta.commission);
  const existingTax = Number((meta.taxBreakdown && meta.taxBreakdown.totalTax) || 0);
  const grossForBackfill = Number.isFinite(existingGross) ? existingGross : (participation.get('profitShare') || 0);
  const commForBackfill = Number.isFinite(existingComm) ? existingComm : (participation.get('commissionAmount') || 0);
  const netForBackfill = round2(grossForBackfill - commForBackfill);

  if (!participation.get('isSettled')) {
    participation.set('isSettled', true);
    participation.set('settledAt', new Date());
  }
  if (!Number.isFinite(participation.get('profitShare')) || participation.get('profitShare') === 0) {
    participation.set('profitShare', grossForBackfill);
  }
  if (!Number.isFinite(participation.get('commissionAmount')) || participation.get('commissionAmount') === 0) {
    participation.set('commissionAmount', commForBackfill);
  }
  if (!participation.get('commissionRate')) {
    participation.set('commissionRate', commissionRate);
  }
  await participation.save(null, { useMasterKey: true });

  await backfillInvestmentFromBillMetadata({
    investment,
    bill: existingBill,
    grossProfit: grossForBackfill,
    commission: commForBackfill,
    netProfit: netForBackfill,
  });

  await backfillCommissionRecordIfMissing({
    traderId,
    investment,
    trade,
    participation,
    commission: commForBackfill,
    createCommissionRecord,
  });

  await backfillResidualReturnIfMissing({
    investorId,
    investmentId: investment.id,
    trade,
    tradeNumber,
    bill: existingBill,
    investment,
    participation,
    feeConfig,
    tradeBuyPrice,
  });

  return {
    investorId,
    investmentId: investment.id,
    grossProfit: grossForBackfill,
    commission: commForBackfill,
    taxWithheld: Number.isFinite(existingTax) ? existingTax : 0,
  };
}

module.exports = {
  trySettleFromExistingBill,
};
