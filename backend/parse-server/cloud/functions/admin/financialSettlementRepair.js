'use strict';

const { repairTradeSettlement } = require('../../utils/accountingHelper/repair');
const { settleAndDistribute } = require('../../utils/accountingHelper');
const { logPermissionCheck } = require('../../utils/permissions');

async function handleRepairTradeSettlement(request) {
  const { tradeId, dryRun = false, reSettle = true } = request.params || {};
  if (!tradeId) {
    throw new Parse.Error(Parse.Error.INVALID_VALUE, 'tradeId required');
  }

  const report = await repairTradeSettlement(tradeId, { dryRun: !!dryRun, reSettle: reSettle !== false });
  if (!request.master) {
    await logPermissionCheck(request, 'repairTradeSettlement', 'Trade', tradeId);
  }
  return report;
}

async function handleBackfillTradeSettlement(request) {
  const { tradeId } = request.params || {};
  if (!tradeId) {
    throw new Parse.Error(Parse.Error.INVALID_VALUE, 'tradeId required');
  }

  const trade = await new Parse.Query('Trade').get(tradeId, { useMasterKey: true });
  const summary = await settleAndDistribute(trade);

  const investmentRows = await new Parse.Query('PoolTradeParticipation')
    .equalTo('tradeId', tradeId)
    .find({ useMasterKey: true });
  const investmentIds = Array.from(new Set(
    investmentRows.map((p) => p.get('investmentId')).filter(Boolean),
  ));
  const investments = investmentIds.length
    ? await new Parse.Query('Investment')
      .containedIn('objectId', investmentIds)
      .find({ useMasterKey: true })
    : [];

  if (!request.master) {
    await logPermissionCheck(request, 'backfillTradeSettlement', 'Trade', tradeId);
  }

  return {
    tradeId,
    settlementSummary: summary || null,
    investmentsAfter: investments.map((inv) => ({
      objectId: inv.id,
      investmentNumber: inv.get('investmentNumber'),
      status: inv.get('status'),
      profit: inv.get('profit') || 0,
      currentValue: inv.get('currentValue') || 0,
      totalCommissionPaid: inv.get('totalCommissionPaid') || 0,
      numberOfTrades: inv.get('numberOfTrades') || 0,
      profitPercentage: inv.get('profitPercentage') || 0,
      completedAt: inv.get('completedAt') || null,
    })),
  };
}

module.exports = {
  handleRepairTradeSettlement,
  handleBackfillTradeSettlement,
};
