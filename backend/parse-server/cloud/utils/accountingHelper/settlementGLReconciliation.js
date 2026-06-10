'use strict';

const { round2 } = require('./shared');
const { getSettlementGLRule } = require('./settlementGLRules');
const { resolveSettlementGLLeg } = require('./settlementGLPoster');

const MONEY_EPS = 0.02;

const GL_RECONCILED_ENTRY_TYPES = [
  'commission_debit',
  'commission_credit',
  'withholding_tax_debit',
  'solidarity_surcharge_debit',
  'church_tax_debit',
];

function normalizeStatementRow(stmt) {
  if (!stmt) return null;
  if (stmt.get) {
    return {
      id: stmt.id,
      entryType: String(stmt.get('entryType') || ''),
      amount: Number(stmt.get('amount') || 0),
      investmentId: String(stmt.get('investmentId') || '').trim(),
      userId: String(stmt.get('userId') || '').trim(),
      tradeId: String(stmt.get('tradeId') || '').trim(),
      source: String(stmt.get('source') || ''),
    };
  }
  return {
    id: stmt.id || '',
    entryType: String(stmt.entryType || ''),
    amount: Number(stmt.amount || 0),
    investmentId: String(stmt.investmentId || '').trim(),
    userId: String(stmt.userId || '').trim(),
    tradeId: String(stmt.tradeId || '').trim(),
    source: String(stmt.source || ''),
  };
}

function normalizeLedgerRow(row) {
  if (!row) return null;
  const md = row.get ? (row.get('metadata') || {}) : (row.metadata || {});
  return {
    id: row.id || '',
    account: String(row.get ? row.get('account') : row.account || ''),
    side: String(row.get ? row.get('side') : row.side || ''),
    amount: Number(row.get ? row.get('amount') : row.amount || 0),
    transactionType: String(row.get ? row.get('transactionType') : row.transactionType || ''),
    referenceId: String(row.get ? row.get('referenceId') : row.referenceId || ''),
    userId: String(row.get ? row.get('userId') : row.userId || ''),
    metadata: md,
  };
}

function ledgerSideForStatement(entryType) {
  const rule = getSettlementGLRule(entryType);
  if (!rule) return null;
  if (entryType === 'commission_credit') {
    return { account: rule.debitAccount, side: 'debit' };
  }
  return { account: rule.creditAccount, side: 'credit' };
}

function hasLedgerLegForStatement(stmt, ledgerRows) {
  const rule = getSettlementGLRule(stmt.entryType);
  if (!rule) return { ok: true, leg: null };

  const leg = resolveSettlementGLLeg(rule.leg, stmt.investmentId);
  const target = ledgerSideForStatement(stmt.entryType);
  if (!target) return { ok: true, leg };

  const scoped = ledgerRows.some((row) =>
    row.referenceId === stmt.tradeId
    && row.transactionType === rule.transactionType
    && row.metadata?.leg === leg
    && row.account === target.account
    && row.side === target.side
    && Math.abs(row.amount - Math.abs(stmt.amount)) <= MONEY_EPS,
  );
  if (scoped) return { ok: true, leg, mode: 'scoped' };

  if (stmt.investmentId) {
    const legacy = ledgerRows.some((row) =>
      row.referenceId === stmt.tradeId
      && row.transactionType === rule.transactionType
      && row.metadata?.leg === rule.leg
      && row.userId === stmt.userId
      && row.account === target.account
      && row.side === target.side,
    );
    if (legacy) return { ok: false, leg, mode: 'legacy_only' };
  }

  return { ok: false, leg, mode: 'missing' };
}

/**
 * Pure reconciliation: AccountStatement rows with GL rules vs AppLedgerEntry legs.
 */
function reconcileSettlementGLForTrade(tradeId, rawStatements, rawLedgerRows) {
  const statements = (rawStatements || [])
    .map(normalizeStatementRow)
    .filter((s) => s && s.tradeId === tradeId && s.source === 'backend');
  const ledgerRows = (rawLedgerRows || [])
    .map(normalizeLedgerRow)
    .filter((r) => r && r.referenceId === tradeId);

  const violations = [];
  const glStatements = statements.filter((s) => GL_RECONCILED_ENTRY_TYPES.includes(s.entryType));

  for (const stmt of glStatements) {
    const amount = Math.abs(stmt.amount);
    if (!(amount > 0)) continue;

    const legCheck = hasLedgerLegForStatement(stmt, ledgerRows);
    if (legCheck.ok) continue;

    violations.push({
      type: legCheck.mode === 'legacy_only' ? 'legacy_gl_leg_only' : 'missing_gl_leg',
      tradeId,
      statementId: stmt.id,
      entryType: stmt.entryType,
      investmentId: stmt.investmentId || null,
      userId: stmt.userId || null,
      expectedLeg: legCheck.leg,
      amount: round2(amount),
    });
  }

  const commissionStmts = glStatements.filter((s) => s.entryType.startsWith('commission_'));
  if (commissionStmts.length > 0) {
    const comLedger = ledgerRows.filter((r) => r.transactionType === 'commission' && r.account === 'PLT-LIAB-COM');
    const ledgerDebit = round2(comLedger.filter((r) => r.side === 'debit').reduce((s, r) => s + r.amount, 0));
    const ledgerCredit = round2(comLedger.filter((r) => r.side === 'credit').reduce((s, r) => s + r.amount, 0));
    const stmtInvestor = round2(
      commissionStmts
        .filter((s) => s.entryType === 'commission_debit')
        .reduce((s, row) => s + Math.abs(row.amount), 0),
    );
    const stmtTrader = round2(
      commissionStmts
        .filter((s) => s.entryType === 'commission_credit')
        .reduce((s, row) => s + Math.abs(row.amount), 0),
    );

    if (stmtInvestor > 0 && Math.abs(ledgerCredit - stmtInvestor) > MONEY_EPS) {
      violations.push({
        type: 'plt_liab_com_credit_mismatch',
        tradeId,
        statementTotal: stmtInvestor,
        ledgerCredit,
        delta: round2(ledgerCredit - stmtInvestor),
      });
    }
    if (stmtTrader > 0 && Math.abs(ledgerDebit - stmtTrader) > MONEY_EPS) {
      violations.push({
        type: 'plt_liab_com_debit_mismatch',
        tradeId,
        statementTotal: stmtTrader,
        ledgerDebit,
        delta: round2(ledgerDebit - stmtTrader),
      });
    }
    if (stmtInvestor > 0 && stmtTrader > 0 && Math.abs(stmtInvestor - stmtTrader) > MONEY_EPS) {
      violations.push({
        type: 'commission_statement_imbalance',
        tradeId,
        investorCommissionTotal: stmtInvestor,
        traderCommissionTotal: stmtTrader,
        delta: round2(stmtTrader - stmtInvestor),
      });
    }
  }

  return violations;
}

module.exports = {
  MONEY_EPS,
  GL_RECONCILED_ENTRY_TYPES,
  normalizeStatementRow,
  normalizeLedgerRow,
  reconcileSettlementGLForTrade,
  hasLedgerLegForStatement,
};
