'use strict';

const {
  GL_RECONCILED_ENTRY_TYPES,
  reconcileSettlementGLForTrade,
} = require('../../utils/accountingHelper/settlementGLReconciliation');

const GL_TRANSACTION_TYPES = ['commission', 'withholdingTax', 'solidaritySurcharge', 'churchTax'];

async function loadStatementsByTradeId(tradeIds) {
  if (!tradeIds.length) return new Map();
  const q = new Parse.Query('AccountStatement');
  q.containedIn('tradeId', tradeIds);
  q.equalTo('source', 'backend');
  q.containedIn('entryType', GL_RECONCILED_ENTRY_TYPES);
  q.limit(5000);
  const rows = await q.find({ useMasterKey: true });
  const byTrade = new Map();
  for (const row of rows) {
    const tid = row.get('tradeId');
    if (!tid) continue;
    if (!byTrade.has(tid)) byTrade.set(tid, []);
    byTrade.get(tid).push(row);
  }
  return byTrade;
}

async function loadLedgerByTradeId(tradeIds) {
  if (!tradeIds.length) return new Map();
  const q = new Parse.Query('AppLedgerEntry');
  q.containedIn('referenceId', tradeIds);
  q.containedIn('transactionType', GL_TRANSACTION_TYPES);
  q.limit(5000);
  const rows = await q.find({ useMasterKey: true });
  const byTrade = new Map();
  for (const row of rows) {
    const tid = row.get('referenceId');
    if (!tid) continue;
    if (!byTrade.has(tid)) byTrade.set(tid, []);
    byTrade.get(tid).push(row);
  }
  return byTrade;
}

/**
 * Live guard: every settlement AccountStatement with GL mapping has a matching AppLedger leg.
 */
async function handleGetSettlementGLReconciliationStatus(request) {
  const limit = Math.min(100, Math.max(1, Number(request.params?.limit || 50)));

  const tradeQuery = new Parse.Query('Trade');
  tradeQuery.equalTo('status', 'completed');
  tradeQuery.descending('updatedAt');
  tradeQuery.limit(limit);
  const trades = await tradeQuery.find({ useMasterKey: true });

  const tradeIds = trades.map((t) => t.id);
  const statementsByTrade = await loadStatementsByTradeId(tradeIds);
  const ledgerByTrade = await loadLedgerByTradeId(tradeIds);

  const violations = [];
  let checkedTrades = 0;
  let checkedStatements = 0;

  for (const trade of trades) {
    const tradeId = trade.id;
    const statements = statementsByTrade.get(tradeId) || [];
    const ledgerRows = ledgerByTrade.get(tradeId) || [];
    if (!statements.length) continue;

    checkedTrades += 1;
    checkedStatements += statements.length;
    violations.push(
      ...reconcileSettlementGLForTrade(tradeId, statements, ledgerRows).map((v) => ({
        ...v,
        tradeNumber: trade.get('tradeNumber') || null,
        buyLegType: trade.get('buyLegType') || null,
      })),
    );
  }

  return {
    overall: violations.length === 0 ? 'healthy' : 'degraded',
    checkedTrades,
    checkedStatements,
    violationCount: violations.length,
    violations: violations.slice(0, 50),
    repairHint: violations.length > 0
      ? 'Cloud: backfillMissingSettlementGL { tradeId, dryRun:false } on affected pool/trader trade IDs'
      : null,
    message: violations.length === 0
      ? 'AccountStatement ↔ AppLedger settlement GL reconciliation OK'
      : `${violations.length} settlement GL reconciliation violation(s)`,
    checkedAt: new Date().toISOString(),
  };
}

module.exports = {
  handleGetSettlementGLReconciliationStatus,
  loadStatementsByTradeId,
  loadLedgerByTradeId,
};
