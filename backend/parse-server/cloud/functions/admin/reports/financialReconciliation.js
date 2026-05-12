'use strict';

/**
 * P1 financial reconciliation: period aggregates + data-quality / plausibility checks.
 * Vertiefte Abstimmung: Eröffnung aus Snapshot + Paarregeln (Kontenrahmen).
 * Read-only; uses master key. Same permission as financial dashboard.
 */

const { requirePermission } = require('../../../utils/permissions');
const { round2 } = require('../../../utils/accountingHelper/shared');
const { getLatestLedgerOpeningSnapshotBefore } = require('../../../utils/accountingHelper/ledgerOpeningSnapshot');
const {
  buildAccountChartMeta,
  PERIOD_NET_ZERO_PAIRS,
  accountsForDetailedAggregation,
} = require('./financialReconciliationRules');

const DEFAULT_MAX_ROWS = 50000;
const ABS_HARD_MAX = 200000;

function parseRange(params) {
  const dateFrom = params.dateFrom || params.from;
  const dateTo = params.dateTo || params.to;
  if (!dateFrom || !dateTo) {
    throw new Parse.Error(Parse.Error.INVALID_QUERY, 'Parameter „dateFrom“ und „dateTo“ (ISO-Datum) sind erforderlich.');
  }
  const from = new Date(dateFrom);
  const to = new Date(dateTo);
  if (Number.isNaN(from.getTime()) || Number.isNaN(to.getTime())) {
    throw new Parse.Error(Parse.Error.INVALID_QUERY, 'Ungültiges Datumsformat für dateFrom/dateTo.');
  }
  if (from > to) {
    throw new Parse.Error(Parse.Error.INVALID_QUERY, 'dateFrom darf nicht nach dateTo liegen.');
  }
  return { from, to };
}

function maxRowsParam(params) {
  const n = Number(params.maxRows);
  if (!Number.isFinite(n) || n <= 0) return DEFAULT_MAX_ROWS;
  return Math.min(Math.floor(n), ABS_HARD_MAX);
}

/**
 * Paginated find for bounded periods. Skip/limit is acceptable for read-only admin reports
 * on closed intervals; avoids complex compound Parse queries.
 */
async function fetchAllCreatedBetween(className, from, to, maxRows) {
  const rows = [];
  let skip = 0;
  const pageSize = 500;
  while (rows.length < maxRows) {
    const q = new Parse.Query(className);
    q.greaterThanOrEqualTo('createdAt', from);
    q.lessThanOrEqualTo('createdAt', to);
    q.ascending('createdAt');
    q.skip(skip);
    q.limit(Math.min(pageSize, maxRows - rows.length));
    // eslint-disable-next-line no-await-in-loop
    const batch = await q.find({ useMasterKey: true });
    if (batch.length === 0) break;
    rows.push(...batch);
    skip += batch.length;
    if (batch.length < pageSize) break;
  }
  return { rows, truncated: rows.length >= maxRows };
}

async function fetchLedgerOpeningSnapshotById(objectId) {
  const id = String(objectId || '').trim();
  if (!id) return null;
  try {
    const q = new Parse.Query('LedgerOpeningSnapshot');
    const row = await q.get(id, { useMasterKey: true });
    return {
      objectId: row.id,
      effectiveDate: row.get('effectiveDate'),
      label: row.get('label') || '',
      notes: row.get('notes') || '',
      balances: row.get('balances') || {},
      source: row.get('source') || '',
      createdAt: row.get('createdAt'),
    };
  } catch {
    throw new Parse.Error(Parse.Error.OBJECT_NOT_FOUND, `LedgerOpeningSnapshot nicht gefunden: ${id}`);
  }
}

function aggregateAccountStatements(rows) {
  let sumAmount = 0;
  const byEntryType = {};
  let missingBusinessCaseId = 0;
  let missingReferenceDocument = 0;

  for (const e of rows) {
    const amt = Number(e.get('amount'));
    if (Number.isFinite(amt)) sumAmount += amt;
    const et = String(e.get('entryType') || 'unknown');
    if (!byEntryType[et]) byEntryType[et] = { count: 0, sumAmount: 0 };
    byEntryType[et].count += 1;
    if (Number.isFinite(amt)) byEntryType[et].sumAmount += amt;

    const bc = String(e.get('businessCaseId') || '').trim();
    if (!bc) missingBusinessCaseId += 1;

    const src = String(e.get('source') || '');
    const rid = String(e.get('referenceDocumentId') || '').trim();
    const rnum = String(e.get('referenceDocumentNumber') || '').trim();
    if (src === 'backend' && (!rid || !rnum)) {
      missingReferenceDocument += 1;
    }
  }

  return {
    rowCount: rows.length,
    sumAmount: round2(sumAmount),
    byEntryType,
    missingBusinessCaseId,
    missingReferenceDocument,
  };
}

/**
 * @param {Parse.Object[]} rows
 * @param {{ detailAccounts?: Set<string> }} [opts]
 */
function aggregateAppLedger(rows, opts = {}) {
  const detailAccounts = opts.detailAccounts instanceof Set ? opts.detailAccounts : null;
  /** @type {Record<string, Record<string, { debitSum: number, creditSum: number, rowCount: number, netDebitMinusCredit?: number }>>|undefined} */
  let byAccountByTransactionType;
  if (detailAccounts && detailAccounts.size > 0) {
    byAccountByTransactionType = {};
  }

  const byAccount = {};
  let missingBusinessCaseId = 0;
  const bcSensitiveTypes = new Set([
    'commission',
    'withholdingTax',
    'solidaritySurcharge',
    'churchTax',
    'orderFee',
    'exchangeFee',
    'foreignCosts',
    'tradeCash',
    'walletDeposit',
    'walletWithdrawal',
    'appServiceCharge',
    'investmentEscrow',
  ]);

  for (const e of rows) {
    const account = String(e.get('account') || 'unknown');
    const side = String(e.get('side') || '');
    const amt = Math.abs(Number(e.get('amount')) || 0);
    if (!byAccount[account]) {
      byAccount[account] = { debitSum: 0, creditSum: 0, rowCount: 0 };
    }
    byAccount[account].rowCount += 1;
    if (side === 'debit') byAccount[account].debitSum += amt;
    else if (side === 'credit') byAccount[account].creditSum += amt;

    const tt = String(e.get('transactionType') || '');
    if (byAccountByTransactionType && detailAccounts && detailAccounts.has(account)) {
      if (!byAccountByTransactionType[account]) byAccountByTransactionType[account] = {};
      if (!byAccountByTransactionType[account][tt]) {
        byAccountByTransactionType[account][tt] = { debitSum: 0, creditSum: 0, rowCount: 0 };
      }
      const cell = byAccountByTransactionType[account][tt];
      cell.rowCount += 1;
      if (side === 'debit') cell.debitSum += amt;
      else if (side === 'credit') cell.creditSum += amt;
    }

    const meta = e.get('metadata') || {};
    const bc = String(meta.businessCaseId || '').trim();
    if (bcSensitiveTypes.has(tt) && !bc) {
      missingBusinessCaseId += 1;
    }
  }

  for (const k of Object.keys(byAccount)) {
    const b = byAccount[k];
    b.debitSum = round2(b.debitSum);
    b.creditSum = round2(b.creditSum);
    b.netDebitMinusCredit = round2(b.debitSum - b.creditSum);
  }

  if (byAccountByTransactionType) {
    for (const acc of Object.keys(byAccountByTransactionType)) {
      const types = byAccountByTransactionType[acc];
      for (const t of Object.keys(types)) {
        const c = types[t];
        c.debitSum = round2(c.debitSum);
        c.creditSum = round2(c.creditSum);
        c.netDebitMinusCredit = round2(c.debitSum - c.creditSum);
      }
    }
  }

  const out = { rowCount: rows.length, byAccount, missingBusinessCaseId };
  if (byAccountByTransactionType) {
    out.byAccountByTransactionType = byAccountByTransactionType;
  }
  return out;
}

function aggregateBankContra(rows) {
  const byAccount = {};
  for (const p of rows) {
    const account = String(p.get('account') || 'unknown');
    const side = String(p.get('side') || '');
    const amt = Math.abs(Number(p.get('amount')) || 0);
    if (!byAccount[account]) {
      byAccount[account] = { creditSum: 0, debitSum: 0, rowCount: 0 };
    }
    byAccount[account].rowCount += 1;
    if (side === 'credit') byAccount[account].creditSum += amt;
    else if (side === 'debit') byAccount[account].debitSum += amt;
  }
  for (const k of Object.keys(byAccount)) {
    const b = byAccount[k];
    b.creditSum = round2(b.creditSum);
    b.debitSum = round2(b.debitSum);
    b.netCreditMinusDebit = round2(b.creditSum - b.debitSum);
  }
  return { rowCount: rows.length, byAccount };
}

/**
 * Netto Soll−Haben für eine Leg-Definition (Konto + transactionTypes).
 */
function netForLeg(byAccountByType, account, transactionTypes) {
  const acc = byAccountByType[account];
  if (!acc) return 0;
  if (!transactionTypes || transactionTypes.length === 0) {
    let s = 0;
    for (const c of Object.values(acc)) {
      s += c.netDebitMinusCredit ?? 0;
    }
    return round2(s);
  }
  let s = 0;
  for (const tt of transactionTypes) {
    const c = acc[tt];
    if (c) s += c.netDebitMinusCredit ?? 0;
  }
  return round2(s);
}

/**
 * @param {Record<string, Record<string, { netDebitMinusCredit: number }>>} byAccountByType
 * @param {typeof PERIOD_NET_ZERO_PAIRS} rules
 */
function evaluatePeriodNetPairRules(byAccountByType, rules) {
  const results = [];
  for (const rule of rules) {
    const legNets = rule.legs.map((leg) => ({
      account: leg.account,
      transactionTypes: leg.transactionTypes,
      netDebitMinusCredit: netForLeg(byAccountByType, leg.account, leg.transactionTypes),
    }));
    const pairSum = round2(legNets.reduce((a, l) => a + l.netDebitMinusCredit, 0));
    const tol = rule.toleranceEUR ?? 0.05;
    results.push({
      id: rule.id,
      description: rule.description,
      toleranceEUR: tol,
      legNets,
      pairSumNetDebitMinusCredit: pairSum,
      ok: Math.abs(pairSum) <= tol,
    });
  }
  return results;
}

/**
 * Schätzung Schluss-Saldo = Eröffnung (netDebitMinusCredit) + Periodenbewegung (Hauptbuch).
 */
function buildClosingByAccount(openingSnapshot, ledgerAgg) {
  const opening = openingSnapshot?.balances || {};
  const period = ledgerAgg.byAccount;
  const accounts = new Set([...Object.keys(opening), ...Object.keys(period)]);
  const closingByAccount = {};
  for (const code of accounts) {
    const openRaw = opening[code];
    const open = typeof openRaw === 'number' && Number.isFinite(openRaw)
      ? openRaw
      : Number(openRaw?.netDebitMinusCredit);
    const openN = Number.isFinite(open) ? open : 0;
    const move = period[code]?.netDebitMinusCredit ?? 0;
    closingByAccount[code] = {
      openingNetDebitMinusCredit: round2(openN),
      periodNetDebitMinusCredit: round2(move),
      closingEstimateNetDebitMinusCredit: round2(openN + move),
    };
  }
  return closingByAccount;
}

/**
 * @param {object} input
 * @param {{ truncated: boolean, stmtTrunc: boolean, ledgerTrunc: boolean, bankTrunc: boolean }} flags
 */
function buildChecks({ stmtAgg, ledgerAgg, bankAgg, byEntryType }, flags) {
  const checks = [];

  if (flags.truncated) {
    checks.push({
      id: 'truncated_sample',
      severity: 'warning',
      message:
        'Abbruch bei maxRows — Aggregationen sind unvollständig. Zeitraum verkleinern oder maxRows erhöhen (bis Obergrenze).',
      details: flags,
    });
  }

  if (stmtAgg.missingBusinessCaseId > 0) {
    checks.push({
      id: 'statement_missing_business_case',
      severity: 'warning',
      message:
        'AccountStatement-Zeilen ohne businessCaseId (Nachvollziehbarkeit / WP). Altdaten oder Randpfade prüfen.',
      value: stmtAgg.missingBusinessCaseId,
    });
  }

  if (stmtAgg.missingReferenceDocument > 0) {
    checks.push({
      id: 'statement_missing_beleg_referenz',
      severity: 'warning',
      message:
        'Backend-AccountStatement-Zeilen ohne referenceDocumentId/Number (GoB-Risiko).',
      value: stmtAgg.missingReferenceDocument,
    });
  }

  if (ledgerAgg.missingBusinessCaseId > 0) {
    checks.push({
      id: 'ledger_missing_business_case',
      severity: 'warning',
      message:
        'AppLedgerEntry-Zeilen (relevante transactionTypes) ohne metadata.businessCaseId.',
      value: ledgerAgg.missingBusinessCaseId,
    });
  }

  const commDebit = byEntryType.commission_debit?.sumAmount ?? 0;
  const commCredit = byEntryType.commission_credit?.sumAmount ?? 0;
  const commNet = round2(commDebit + commCredit);
  const commAbs = Math.max(Math.abs(commDebit), Math.abs(commCredit));
  const tol = Math.max(1, 0.02 * commAbs);
  if (commAbs > 0 && Math.abs(commNet) > tol) {
    checks.push({
      id: 'commission_statement_asymmetry',
      severity: 'warning',
      message:
        'Summe commission_debit + commission_credit auf Personenkonto weicht spürbar von 0 ab (Perioden-/Timing-Effekt oder fehlende Gegenbuchung prüfen).',
      details: { commission_debit_sum: commDebit, commission_credit_sum: commCredit, net: commNet, toleranceEUR: tol },
    });
  }

  const ava = ledgerAgg.byAccount['CLT-LIAB-AVA'];
  if (ava && ava.rowCount > 0) {
    checks.push({
      id: 'ledger_clt_liab_ava_net',
      severity: 'info',
      message:
        'Netto-Soll/Haben CLT-LIAB-AVA im Zeitraum (App-Hauptbuch). Für Saldo-Abschluss Eröffnung außerhalb Zeitraum beachten.',
      details: {
        debitSum: ava.debitSum,
        creditSum: ava.creditSum,
        netDebitMinusCredit: ava.netDebitMinusCredit,
      },
    });
  }

  if (bankAgg && bankAgg.rowCount > 0) {
    checks.push({
      id: 'bank_contra_activity',
      severity: 'info',
      message: 'BankContraPosting-Aktivität im Zeitraum (Service-Charge Clearing).',
      details: bankAgg.byAccount,
    });
  }

  return checks;
}

/**
 * Ergänzt Checks für Snapshot-Auswahl und Paarregeln.
 */
function appendDeepReconciliationChecks(checks, ctx) {
  const {
    openingSelection,
    openingSnapshot,
    pairResults,
    ledgerHadDetailAgg,
  } = ctx;

  if (openingSelection === 'latestBeforePeriod' && !openingSnapshot) {
    checks.push({
      id: 'opening_snapshot_missing',
      severity: 'info',
      message:
        'Kein LedgerOpeningSnapshot vor Periodenbeginn — vertiefte Salden-Schätzung (Eröffnung+Periode) und Paar-Checks nutzen Eröffnung 0. Snapshot anlegen oder openingSnapshotObjectId setzen.',
      details: { openingSelection },
    });
  }

  if (openingSnapshot) {
    checks.push({
      id: 'opening_snapshot_applied',
      severity: 'info',
      message: `Eröffnungssnapshot angewendet: ${openingSnapshot.label || openingSnapshot.objectId} (Stichtag ${new Date(openingSnapshot.effectiveDate).toISOString().slice(0, 10)}).`,
      details: {
        objectId: openingSnapshot.objectId,
        effectiveDate: openingSnapshot.effectiveDate,
        openingSelection,
      },
    });
  }

  if (!ledgerHadDetailAgg) {
    checks.push({
      id: 'deep_pairs_skipped',
      severity: 'info',
      message: 'Feinaggregation (Konto×Typ) fehlt — Paarregeln nicht ausgewertet.',
    });
    return;
  }

  const failedPairs = pairResults.filter((p) => !p.ok);
  const okCount = pairResults.length - failedPairs.length;
  checks.push({
    id: 'pair_rules_summary',
    severity: 'info',
    message: `Paarregeln (Perioden-Netto Soll−Haben): ${okCount}/${pairResults.length} innerhalb Toleranz.`,
    details: { pairResults },
  });

  for (const pr of failedPairs) {
    checks.push({
      id: `pair_fail_${pr.id}`,
      severity: 'warning',
      message:
        `Paarregel „${pr.id}“: Summe Perioden-Netto (${pr.pairSumNetDebitMinusCredit}) außerhalb Toleranz (${pr.toleranceEUR} €) — Buchungslücken, Zeitraum oder Typ-Mapping prüfen.`,
      details: pr,
    });
  }
}

async function handleGetFinancialReconciliationReport(request) {
  requirePermission(request, 'getFinancialDashboard');
  const params = request.params || {};
  const { from, to } = parseRange(params);
  const maxRows = maxRowsParam(params);

  const explicitOpeningId = params.openingSnapshotObjectId || params.openingSnapshotId;
  const useLatestOpening =
    params.useLatestOpeningBeforePeriod !== false && params.useLatestOpeningBeforePeriod !== 'false';

  let openingSnapshot = null;
  let openingSelection = 'none';
  if (explicitOpeningId) {
    openingSnapshot = await fetchLedgerOpeningSnapshotById(explicitOpeningId);
    openingSelection = 'explicit';
  } else if (useLatestOpening) {
    openingSnapshot = await getLatestLedgerOpeningSnapshotBefore(from);
    openingSelection = 'latestBeforePeriod';
  }

  const detailAccounts = accountsForDetailedAggregation();

  const [stmtRes, ledgerRes, bankRes] = await Promise.all([
    fetchAllCreatedBetween('AccountStatement', from, to, maxRows),
    fetchAllCreatedBetween('AppLedgerEntry', from, to, maxRows),
    (async () => {
      try {
        return await fetchAllCreatedBetween('BankContraPosting', from, to, maxRows);
      } catch {
        return { rows: [], truncated: false };
      }
    })(),
  ]);

  const stmtAgg = aggregateAccountStatements(stmtRes.rows);
  const ledgerAgg = aggregateAppLedger(ledgerRes.rows, { detailAccounts });
  const bankAgg = bankRes.rows.length
    ? aggregateBankContra(bankRes.rows)
    : { rowCount: 0, byAccount: {} };

  const truncated = stmtRes.truncated || ledgerRes.truncated || bankRes.truncated;
  const checks = buildChecks(
    { stmtAgg, ledgerAgg, bankAgg, byEntryType: stmtAgg.byEntryType },
    {
      truncated,
      stmtTrunc: stmtRes.truncated,
      ledgerTrunc: ledgerRes.truncated,
      bankTrunc: bankRes.truncated,
    },
  );

  const byType = ledgerAgg.byAccountByTransactionType;
  const ledgerHadDetailAgg = byType != null;
  const pairResults = ledgerHadDetailAgg ? evaluatePeriodNetPairRules(byType, PERIOD_NET_ZERO_PAIRS) : [];

  const closingByAccount = buildClosingByAccount(openingSnapshot, ledgerAgg);

  appendDeepReconciliationChecks(checks, {
    openingSelection,
    openingSnapshot,
    pairResults,
    ledgerHadDetailAgg,
  });

  const accountCatalog = buildAccountChartMeta();

  return {
    generatedAt: new Date().toISOString(),
    period: { from: from.toISOString(), to: to.toISOString() },
    parameters: {
      maxRows,
      openingSelection,
      useLatestOpeningBeforePeriod: useLatestOpening,
      openingSnapshotObjectId: explicitOpeningId || null,
    },
    truncation: {
      accountStatement: stmtRes.truncated,
      appLedgerEntry: ledgerRes.truncated,
      bankContraPosting: bankRes.truncated,
      any: truncated,
    },
    rowCounts: {
      accountStatement: stmtAgg.rowCount,
      appLedgerEntry: ledgerAgg.rowCount,
      bankContraPosting: bankAgg.rowCount,
    },
    accountStatement: stmtAgg,
    appLedger: ledgerAgg,
    bankContraPosting: bankAgg,
    checks,
    accountCatalog,
    openingSnapshot,
    reconciliationDeep: {
      periodPairRuleDefinitions: PERIOD_NET_ZERO_PAIRS,
      pairResults,
      closingByAccount,
    },
  };
}

function registerFinancialReconciliationFunctions() {
  Parse.Cloud.define('getFinancialReconciliationReport', handleGetFinancialReconciliationReport);
}

module.exports = {
  registerFinancialReconciliationFunctions,
  handleGetFinancialReconciliationReport,
  buildChecks,
  appendDeepReconciliationChecks,
  aggregateAccountStatements,
  aggregateAppLedger,
  evaluatePeriodNetPairRules,
  buildClosingByAccount,
  netForLeg,
};
