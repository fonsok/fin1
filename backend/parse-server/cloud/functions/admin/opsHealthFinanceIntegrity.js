'use strict';

const { handleGetMirrorBasisDriftStatus } = require('./opsHealthMirrorBasisDrift');
const { handleGetTraderCashBookingDuplicatesStatus } = require('./opsHealthTraderCashBookingDuplicates');
const { handleGetPairedOrderStatusIntegrityStatus } = require('./opsHealthPairedOrderStatusIntegrity');
const { handleGetTraderMirrorBookingIntegrityStatus } = require('./opsHealthTraderMirrorBookingIntegrity');
const { handleGetTradeSettlementConsistencyStatus } = require('./opsHealthTradeSettlementConsistency');
const { handleGetPairedSellInvestorChainStatus } = require('./opsHealthPairedSellInvestorChain');
const { handleGetFinanceIntegrityPreventionStatus } = require('./opsHealthFinancePrevention');
const { handleGetTraderPoolBidAskContractStatus } = require('./opsHealthTraderPoolBidAskContract');

const OVERALL_RANK = {
  healthy: 1,
  unknown: 2,
  degraded: 3,
  down: 4,
};

function worstOverall(checks) {
  let worst = 'healthy';
  for (const check of checks) {
    const overall = String(check.overall || 'unknown');
    if ((OVERALL_RANK[overall] || 0) > (OVERALL_RANK[worst] || 0)) {
      worst = overall;
    }
  }
  return worst;
}

function collectIssues(checks) {
  return checks
    .filter((check) => check.overall && check.overall !== 'healthy')
    .map((check) => `${check.id}_${check.overall}`);
}

async function safeCheck(id, label, fn, params = {}) {
  try {
    const result = await fn({ params });
    return Object.assign({ id, label }, result);
  } catch (err) {
    return {
      id,
      label,
      overall: 'down',
      reason: err && err.message ? err.message : String(err),
      error: true,
    };
  }
}

/**
 * Closed finance integrity rollup: snapshot checks (cron) + live guards (Parse queries).
 */
async function handleGetFinanceIntegrityStatus(request) {
  const settlementLimit = Number(request.params?.settlementLimit || 50);

  const checks = await Promise.all([
    safeCheck(
      'finance_prevention_indexes',
      'AccountStatement unique booking indexes',
      handleGetFinanceIntegrityPreventionStatus,
    ),
    safeCheck('mirror_basis_drift', 'Mirror-basis ROI drift', handleGetMirrorBasisDriftStatus),
    safeCheck(
      'trader_cash_duplicates',
      'Trader cash duplicate bookings',
      handleGetTraderCashBookingDuplicatesStatus,
    ),
    safeCheck(
      'paired_order_status',
      'Paired order leg status',
      handleGetPairedOrderStatusIntegrityStatus,
    ),
    safeCheck(
      'trader_mirror_booking',
      'Trader bookings on MIRROR_POOL trades',
      handleGetTraderMirrorBookingIntegrityStatus,
    ),
    safeCheck(
      'settlement_consistency',
      'Trade settlement consistency',
      handleGetTradeSettlementConsistencyStatus,
      { limit: settlementLimit },
    ),
    safeCheck(
      'paired_sell_investor_chain',
      'Paired sell → mirror sync → investor bills',
      handleGetPairedSellInvestorChainStatus,
      { limit: Math.min(50, settlementLimit) },
    ),
    safeCheck(
      'trader_pool_bid_ask_contract',
      'Trader↔Pool Bid/Ask-only economics',
      handleGetTraderPoolBidAskContractStatus,
      { limit: Math.min(100, settlementLimit * 2) },
    ),
  ]);

  const overall = worstOverall(checks);
  const issues = collectIssues(checks);

  return {
    overall,
    checkedAt: new Date().toISOString(),
    issues,
    checks,
    layers: {
      prevention: 'DB unique indexes on AccountStatement booking keys (ensure-finance-integrity-indexes.js)',
      detection: 'OpsHealthSnapshot cron + live Parse integrity handlers',
      repair: 'Advisory-only scripts; AccountStatement changes via Storno+Re-Book only',
    },
  };
}

module.exports = {
  handleGetFinanceIntegrityStatus,
  worstOverall,
  collectIssues,
};
