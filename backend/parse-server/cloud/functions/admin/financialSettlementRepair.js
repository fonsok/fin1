'use strict';

const { repairTradeSettlement } = require('../../utils/accountingHelper/repair');
const { settleAndDistribute } = require('../../utils/accountingHelper');
const { backfillMissingSettlementGLForTrade } = require('../../utils/accountingHelper/settlementGLPoster');
const { repairPartialSellEscrowGapsForTraderLeg } = require('../../utils/accountingHelper/settlementInvestorPartialRealization');
const { backfillResidualReturnIfMissing } = require('../../utils/accountingHelper/settlementBackfill');
const investmentEscrow = require('../../utils/accountingHelper/investmentEscrow');
const { mergeInvestorFeeConfig } = require('../../utils/accountingHelper/feeConfigSnapshot');
const { loadConfig } = require('../../utils/configHelper/index.js');
const { logPermissionCheck } = require('../../utils/permissions');
const { audit } = require('../../utils/structuredLogger');
const { round2 } = require('../../utils/accountingHelper/shared');
const { resolveCanonicalUserId } = require('../../utils/canonicalUserId');

async function handleRepairTradeSettlement(request) {
  const { tradeId, dryRun = false, reSettle = true } = request.params || {};
  if (!tradeId) {
    throw new Parse.Error(Parse.Error.INVALID_VALUE, 'tradeId required');
  }

  const initiatedByUserId = request.user && request.user.id ? request.user.id : null;
  audit.info('settlement.admin.repairTradeSettlement.request', {
    tradeId,
    dryRun: !!dryRun,
    reSettle: reSettle !== false,
    initiatedByUserId,
    message: 'repairTradeSettlement: admin invoke',
  });

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
  const tradeNumber = trade.get('tradeNumber') || null;
  const businessCaseIdRaw = trade.get('businessCaseId');
  const businessCaseId = businessCaseIdRaw != null && String(businessCaseIdRaw).trim() !== ''
    ? String(businessCaseIdRaw).trim()
    : null;
  const initiatedByUserId = request.user && request.user.id ? request.user.id : null;

  audit.info('settlement.admin.backfillTradeSettlement.start', {
    tradeId,
    tradeNumber,
    businessCaseId,
    initiatedByUserId,
    message: 'backfillTradeSettlement: settleAndDistribute starting',
  });

  let summary;
  try {
    summary = await settleAndDistribute(trade);
  } catch (err) {
    audit.error('settlement.admin.backfillTradeSettlement.failure', {
      tradeId,
      tradeNumber,
      businessCaseId,
      initiatedByUserId,
      error: err && err.message ? err.message : String(err),
      stack: err && err.stack ? err.stack : undefined,
      message: 'backfillTradeSettlement: settleAndDistribute failed',
    });
    throw err;
  }

  audit.info('settlement.admin.backfillTradeSettlement.done', {
    tradeId,
    tradeNumber,
    businessCaseId,
    initiatedByUserId,
    investorCount: summary && summary.investorCount,
    totalCommission: summary && summary.totalCommission,
    message: 'backfillTradeSettlement: settleAndDistribute completed',
  });

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

async function loadInvestmentByIdOrNumber({ investmentId, investmentNumber }) {
  const id = investmentId != null ? String(investmentId).trim() : '';
  const num = investmentNumber != null ? String(investmentNumber).trim() : '';
  if (id) {
    return new Parse.Query('Investment').get(id, { useMasterKey: true });
  }
  if (num) {
    const row = await new Parse.Query('Investment')
      .equalTo('investmentNumber', num)
      .first({ useMasterKey: true });
    if (!row) {
      throw new Parse.Error(Parse.Error.OBJECT_NOT_FOUND, `Investment not found: ${num}`);
    }
    return row;
  }
  throw new Parse.Error(Parse.Error.INVALID_VALUE, 'investmentId or investmentNumber required');
}

async function handleBackfillTradingResidualEscrow(request) {
  const { investmentId, investmentNumber } = request.params || {};
  const investment = await loadInvestmentByIdOrNumber({ investmentId, investmentNumber });
  const investorId = investment.get('investorId');
  const invNum = investment.get('investmentNumber') || '';

  const participation = await new Parse.Query('PoolTradeParticipation')
    .equalTo('investmentId', investment.id)
    .descending('createdAt')
    .first({ useMasterKey: true });
  if (!participation) {
    throw new Parse.Error(Parse.Error.OBJECT_NOT_FOUND, `No PoolTradeParticipation for ${investment.id}`);
  }

  const tradeId = participation.get('tradeId');
  if (!tradeId) {
    throw new Parse.Error(Parse.Error.INVALID_VALUE, 'Participation has no tradeId');
  }
  const trade = await new Parse.Query('Trade').get(tradeId, { useMasterKey: true });
  const tradeNumber = trade.get('tradeNumber') || trade.get('number') || '';

  const bill = await new Parse.Query('Document')
    .equalTo('type', 'investorCollectionBill')
    .equalTo('investmentId', investment.id)
    .equalTo('tradeId', trade.id)
    .equalTo('source', 'backend')
    .first({ useMasterKey: true });
  if (!bill) {
    throw new Parse.Error(Parse.Error.OBJECT_NOT_FOUND, `No investorCollectionBill for investment ${investment.id}`);
  }

  const tradeBuyPrice = trade.get('entryPrice') || trade.get('buyPrice') || 0;
  const live = await loadConfig();
  const feeConfig = mergeInvestorFeeConfig(investment, trade, live.financial || {});

  const buyLeg = (bill.get('metadata') || {}).buyLeg || {};
  const residualRounded = round2(Number(buyLeg.residualAmount) || 0);

  const escrowBefore = {
    reserveCapitalTradeSplit: await investmentEscrow.hasEscrowLeg(
      investment.id,
      'reserveCapitalTradeSplit',
      { tradeId: trade.id },
    ),
    tradingResidualReturn: await investmentEscrow.hasEscrowLeg(
      investment.id,
      'tradingResidualReturn',
      { tradeId: trade.id },
    ),
  };

  const purgedLegacyRows = (
    (await investmentEscrow.purgeReleaseTradingResidualCorrectionLeg(investment.id, trade.id))
    + (await investmentEscrow.purgeTradingResidualReturnLeg(investment.id, trade.id))
    + (await investmentEscrow.purgeReserveCapitalTradeSplitLeg(investment.id, trade.id))
    + (await investmentEscrow.purgeDeployReversalForCapitalSplitLeg(investment.id, trade.id))
  );

  await backfillResidualReturnIfMissing({
    investorId,
    investmentId: investment.id,
    trade,
    tradeNumber,
    bill,
    investment,
    participation,
    feeConfig,
    tradeBuyPrice,
  });

  const escrowAfter = {
    reserveCapitalTradeSplit: await investmentEscrow.hasEscrowLeg(
      investment.id,
      'reserveCapitalTradeSplit',
      { tradeId: trade.id },
    ),
    deployReversalForCapitalSplit: await investmentEscrow.hasEscrowLeg(
      investment.id,
      'deployReversalForCapitalSplit',
      { tradeId: trade.id },
    ),
  };

  if (!request.master) {
    await logPermissionCheck(request, 'backfillTradingResidualEscrow', 'Investment', investment.id);
  }

  return {
    investmentId: investment.id,
    investmentNumber: invNum,
    tradeId: trade.id,
    tradeNumber,
    residualAmount: buyLeg.residualAmount || null,
    purgedLegacyRows,
    escrowBefore,
    escrowAfter,
  };
}

async function handleEnsureCapitalSplitOnActivation(request) {
  const { investmentId, investmentNumber, forceRebook } = request.params || {};
  const investment = await loadInvestmentByIdOrNumber({ investmentId, investmentNumber });

  const participation = await new Parse.Query('PoolTradeParticipation')
    .equalTo('investmentId', investment.id)
    .descending('createdAt')
    .first({ useMasterKey: true });
  if (!participation) {
    throw new Parse.Error(
      Parse.Error.OBJECT_NOT_FOUND,
      `No PoolTradeParticipation for ${investment.id}`,
    );
  }

  const tradeId = participation.get('tradeId');
  if (!tradeId) {
    throw new Parse.Error(Parse.Error.INVALID_VALUE, 'Participation has no tradeId');
  }
  const trade = await new Parse.Query('Trade').get(tradeId, { useMasterKey: true });

  let purgedRows = 0;
  if (forceRebook) {
    purgedRows = await investmentEscrow.purgeReserveCapitalTradeSplitLeg(investment.id, trade.id);
    purgedRows += await investmentEscrow.purgeDeployReversalForCapitalSplitLeg(investment.id, trade.id);
    const canonicalUserId = await resolveCanonicalUserId(investment.get('investorId'));
    const badResidual = await new Parse.Query('AccountStatement')
      .equalTo('userId', canonicalUserId)
      .equalTo('investmentId', investment.id)
      .equalTo('tradeId', trade.id)
      .equalTo('entryType', 'residual_return')
      .equalTo('source', 'backend')
      .first({ useMasterKey: true });
    if (badResidual) {
      await badResidual.destroy({ useMasterKey: true });
      purgedRows += 1;
    }
    investment.unset('poolTradingAmount');
    await investment.save(null, { useMasterKey: true });
  }

  const result = await investmentEscrow.ensureReserveCapitalTradeSplitOnActivation(investment, trade);

  if (!request.master) {
    await logPermissionCheck(request, 'ensureCapitalSplitOnActivation', 'Investment', investment.id);
  }

  return {
    investmentId: investment.id,
    investmentNumber: investment.get('investmentNumber') || '',
    tradeId: trade.id,
    forceRebook: Boolean(forceRebook),
    purgedRows,
    ...result,
  };
}

async function handleBackfillMissingSettlementGL(request) {
  const { tradeId, dryRun = false } = request.params || {};
  if (!tradeId) {
    throw new Parse.Error(Parse.Error.INVALID_VALUE, 'tradeId required');
  }

  const report = await backfillMissingSettlementGLForTrade(tradeId, { dryRun: !!dryRun });
  if (!request.master) {
    await logPermissionCheck(request, 'backfillMissingSettlementGL', 'Trade', tradeId);
  }
  return report;
}

async function handleRepairPartialSellEscrow(request) {
  const { tradeId, dryRun = false } = request.params || {};
  if (!tradeId) {
    throw new Parse.Error(Parse.Error.INVALID_VALUE, 'tradeId required');
  }

  const trade = await new Parse.Query('Trade').get(tradeId, { useMasterKey: true });
  const report = await repairPartialSellEscrowGapsForTraderLeg(trade, { dryRun: !!dryRun });

  if (!request.master) {
    await logPermissionCheck(request, 'repairPartialSellEscrow', 'Trade', tradeId);
  }

  audit.info('settlement.admin.repairPartialSellEscrow.done', {
    tradeId,
    dryRun: !!dryRun,
    repairedCount: report?.gaps?.repaired?.length || 0,
    replayedCount: Array.isArray(report?.replayed) ? report.replayed.length : 0,
  });

  return report;
}

module.exports = {
  handleRepairTradeSettlement,
  handleBackfillTradeSettlement,
  handleBackfillTradingResidualEscrow,
  handleEnsureCapitalSplitOnActivation,
  handleBackfillMissingSettlementGL,
  handleRepairPartialSellEscrow,
};
