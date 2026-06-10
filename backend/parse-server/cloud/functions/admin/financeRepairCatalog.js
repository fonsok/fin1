'use strict';

/**
 * Advisory repair catalog — maps invariant / issue codes to Cloud Functions (dry-run first).
 * No mutations from this handler; operators call listed functions explicitly.
 */
const REPAIR_CATALOG = [
  {
    id: 'paired_sell_investor_chain',
    layer: 'detection',
    script: 'scripts/e2e-paired-sell-integrity-smoke.js',
    notes: 'E2E seed + assert; assert-only: E2E_SKIP_SEED=1',
    relatedChecks: ['paired_sell_investor_chain', 'settlement_consistency'],
  },
  {
    id: 'settlement_retry_blocked',
    layer: 'repair',
    cloudFunction: 'reconcileStaleSettlementRetryJobs',
    defaultParams: { dryRun: true, limit: 100, runQueueAfter: false },
    applyParams: { dryRun: false, runQueueAfter: true },
    relatedChecks: ['paired_sell_investor_chain', 'settlement_consistency'],
  },
  {
    id: 'settlement_retry_queue',
    layer: 'repair',
    cloudFunction: 'runSettlementRetryQueue',
    defaultParams: { dryRun: false, limit: 25 },
    relatedChecks: ['paired_sell_investor_chain'],
  },
  {
    id: 'pool_mirror_eigenbeleg_missing',
    layer: 'repair',
    cloudFunction: 'backfillPoolMirrorExecutionEigenbeleg',
    defaultParams: { dryRun: true, executionType: 'buy' },
    applyParams: { dryRun: false },
    relatedChecks: ['paired_sell_investor_chain'],
  },
  {
    id: 'trader_cash_duplicates',
    layer: 'repair',
    cloudFunction: 'repairTradeSettlement',
    defaultParams: { dryRun: true, reSettle: false },
    notes: 'Advisory only — AccountStatement changes via Storno+Re-Book; inspect duplicates first',
    relatedChecks: ['trader_cash_duplicates'],
  },
  {
    id: 'settlement_consistency_drift',
    layer: 'repair',
    cloudFunction: 'backfillTradeSettlement',
    defaultParams: { dryRun: true },
    relatedChecks: ['settlement_consistency'],
  },
  {
    id: 'mirror_basis_drift',
    layer: 'repair',
    cloudFunction: 'backfillTraderCollectionBillBeleg',
    defaultParams: { dryRun: true, limit: 25 },
    relatedChecks: ['mirror_basis_drift'],
  },
  {
    id: 'pool_mirror_buy_quantity_drift',
    layer: 'repair',
    cloudFunction: 'repairMirrorPoolBuyQuantity',
    defaultParams: { dryRun: true, limit: 50 },
    applyParams: { dryRun: false, limit: 50, resyncSellFromTrader: true },
    notes: 'Align MIRROR_POOL trade qty/buyAmount from PoolTradeParticipation.buySnapshot; optional sell resync from trader leg',
    relatedChecks: ['mirror_basis_drift', 'paired_sell_investor_chain', 'trader_pool_bid_ask_contract'],
  },
  {
    id: 'settlement_gl_pairs_missing',
    layer: 'repair',
    cloudFunction: 'backfillMissingSettlementGL',
    defaultParams: { dryRun: true },
    applyParams: { dryRun: false },
    notes: 'Replay AppLedger pairs from AccountStatement rows (per-investor commission/tax legs)',
    relatedChecks: ['settlement_consistency'],
  },
  {
    id: 'trader_pool_bid_ask_contract',
    layer: 'detection',
    cloudFunction: 'getTraderPoolBidAskContractStatus',
    defaultParams: { limit: 100 },
    notes: 'ADR-016: pool must not copy trader Einstand/Gebühren when piece counts differ; Bid must match',
    relatedChecks: ['trader_pool_bid_ask_contract'],
  },
  {
    id: 'finance_prevention_indexes',
    layer: 'prevention',
    script: 'backend/scripts/ensure-finance-integrity-indexes.js',
    verifyScript: 'backend/scripts/verify-finance-integrity-indexes.js',
    notes: 'Run via mongosh on fin1 DB; unique indexes block duplicate trade_buy/trade_sell',
    relatedChecks: ['finance_prevention_indexes'],
  },
  {
    id: 'statement_reference_gaps',
    layer: 'repair',
    cloudFunction: 'reconcileAccountStatementDocumentReferences',
    defaultParams: { dryRun: true },
    relatedChecks: ['settlement_consistency'],
  },
];

function handleGetFinanceRepairCatalog(request) {
  const issueFilter = String(request.params?.issueCode || request.params?.issue || '').trim();
  const layerFilter = String(request.params?.layer || '').trim().toLowerCase();

  let entries = REPAIR_CATALOG;
  if (issueFilter) {
    entries = entries.filter(
      (entry) => entry.id === issueFilter
        || (Array.isArray(entry.relatedChecks) && entry.relatedChecks.includes(issueFilter)),
    );
  }
  if (layerFilter) {
    entries = entries.filter((entry) => entry.layer === layerFilter);
  }

  return {
    count: entries.length,
    entries,
    usage: 'Call cloudFunction with defaultParams (dry-run) before applyParams',
    checkedAt: new Date().toISOString(),
  };
}

module.exports = {
  REPAIR_CATALOG,
  handleGetFinanceRepairCatalog,
};
