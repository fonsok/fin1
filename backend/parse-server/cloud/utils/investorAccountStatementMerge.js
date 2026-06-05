'use strict';

const { round2 } = require('./accountingHelper/shared');
const { collectLedgerUserIdCandidates } = require('./canonicalUserId');
const {
  CLT_LIAB_AVA,
  CLT_LIAB_RSV,
  CLT_LIAB_PTR,
  normalizeClientLiabilityAccount,
} = require('./accountingHelper/clientLiabilityAccounts');

const INVESTMENT_REF_TYPES = ['Investment', 'investment'];
const ESCROW_TX_TYPES = ['investmentEscrow', 'appServiceCharge'];

/**
 * AVA legs posted with trade settlement that split pool vs profit credits on CLT-LIAB-AVA.
 * The customer-facing line is AccountStatement `investment_return`; showing these rows
 * duplicates the same cash effect (see statements.js SETTLEMENT_GL_RULES.investment_return).
 */
const INTERNAL_TRADE_SETTLEMENT_RELEASE_LEGS = new Set([
  'tradeSettlementPoolRelease',
  'tradeSettlementProfitRelease',
]);

function dedupeParseObjectsById(rows) {
  const seen = new Set();
  return rows.filter((row) => {
    if (!row?.id || seen.has(row.id)) return false;
    seen.add(row.id);
    return true;
  });
}

/** Netto-Saldo Kundensicht auf Teil-Verbindlichkeit (Haben − Soll). */
function netClientLiabilityBalance(rows, accountCode) {
  const target = normalizeClientLiabilityAccount(accountCode);
  let net = 0;
  for (const row of rows) {
    if (normalizeClientLiabilityAccount(row.get('account')) !== target) continue;
    const amt = Number(row.get('amount')) || 0;
    net += row.get('side') === 'credit' ? amt : -amt;
  }
  return round2(net);
}

async function listInvestorInvestmentIds(user) {
  if (!user?.id || user.get('role') !== 'investor') return [];
  const keys = new Set([user.id]);
  const email = String(user.get('email') || '').toLowerCase().trim();
  if (email) keys.add(`user:${email}`);
  const queries = [...keys].map((investorId) => {
    const q = new Parse.Query('Investment');
    q.equalTo('investorId', investorId);
    return q;
  });
  const combined = queries.length === 1 ? queries[0] : Parse.Query.or(...queries);
  combined.select('objectId');
  combined.limit(500);
  const rows = await combined.find({ useMasterKey: true });
  return rows.map((r) => r.id);
}

const INVESTOR_STMT_SOURCE_LIMIT = 500;
const INVESTOR_ESCROW_SOURCE_LIMIT = 1000;

async function fetchAccountStatementRowsForInvestor({ userKeys, investmentIds }) {
  const queries = [];
  if (userKeys?.length) {
    const q = new Parse.Query('AccountStatement');
    q.containedIn('userId', userKeys);
    queries.push(q);
  }
  if (investmentIds?.length) {
    const q = new Parse.Query('AccountStatement');
    q.containedIn('investmentId', investmentIds);
    queries.push(q);
  }
  if (queries.length === 0) return { rows: [], truncated: false };
  const combined = queries.length === 1 ? queries[0] : Parse.Query.or(...queries);
  combined.ascending('createdAt');
  combined.limit(INVESTOR_STMT_SOURCE_LIMIT + 1);
  const fetched = dedupeParseObjectsById(await combined.find({ useMasterKey: true }));
  const truncated = fetched.length > INVESTOR_STMT_SOURCE_LIMIT;
  return {
    rows: truncated ? fetched.slice(0, INVESTOR_STMT_SOURCE_LIMIT) : fetched,
    truncated,
  };
}

async function fetchInvestorEscrowLedgerRows(userKeys, investmentIds) {
  const queries = [];
  if (userKeys?.length) {
    const q = new Parse.Query('AppLedgerEntry');
    q.containedIn('userId', userKeys);
    q.containedIn('transactionType', ESCROW_TX_TYPES);
    queries.push(q);
  }
  if (investmentIds?.length) {
    const q = new Parse.Query('AppLedgerEntry');
    q.containedIn('referenceId', investmentIds);
    q.containedIn('referenceType', INVESTMENT_REF_TYPES);
    q.equalTo('transactionType', 'investmentEscrow');
    queries.push(q);
  }
  if (queries.length === 0) return { rows: [], truncated: false };
  const combined = queries.length === 1 ? queries[0] : Parse.Query.or(...queries);
  combined.ascending('createdAt');
  combined.limit(INVESTOR_ESCROW_SOURCE_LIMIT + 1);
  const fetched = dedupeParseObjectsById(await combined.find({ useMasterKey: true }));
  const truncated = fetched.length > INVESTOR_ESCROW_SOURCE_LIMIT;
  return {
    rows: truncated ? fetched.slice(0, INVESTOR_ESCROW_SOURCE_LIMIT) : fetched,
    truncated,
  };
}

/** AVA-Leg: Debit = weniger verfügbar → negatives signed amount (wie AccountStatement). */
function signedAmountFromAvaLedgerRow(row) {
  const raw = Number(row.get('amount')) || 0;
  const side = row.get('side');
  const signed = side === 'credit' ? raw : -raw;
  return parseFloat(signed.toFixed(2));
}

/**
 * AccountStatement `residual_return` und AVA-Haben aus `reserveCapitalTradeSplit`
 * (splitPart available) sind dieselbe Kundenbewegung — nur einmal in der Timeline.
 */
function buildResidualReturnDedupKeys(stmtEntries) {
  const keys = new Set();
  for (const e of stmtEntries) {
    if (String(e.get('entryType') || '') !== 'residual_return') continue;
    const invId = String(e.get('investmentId') || '').trim();
    const tradeId = String(e.get('tradeId') || '').trim();
    const amt = round2(Math.abs(Number(e.get('amount') || 0)));
    if (!invId || amt <= 0) continue;
    keys.add(`${invId}|${tradeId}|${amt}`);
    keys.add(`${invId}|${amt}`);
  }
  return keys;
}

function isDuplicateAvaResidualLedgerRow(row, residualKeys) {
  if (!residualKeys || residualKeys.size === 0) return false;
  if (row.get('account') !== 'CLT-LIAB-AVA' || row.get('side') !== 'credit') return false;

  const meta = row.get('metadata') || {};
  const leg = String(meta.leg || '').trim();
  const residualLegs = new Set([
    'reserveCapitalTradeSplit',
    'deployResidualToAvailable',
    'tradingResidualReturn',
  ]);
  if (!residualLegs.has(leg)) return false;
  if (leg === 'reserveCapitalTradeSplit' && meta.splitPart !== 'available') return false;

  const refType = String(row.get('referenceType') || '');
  const invId = refType === 'Investment' ? String(row.get('referenceId') || '').trim() : '';
  const tradeId = String(meta.tradeId || row.get('tradeId') || '').trim();
  const amt = round2(Number(row.get('amount') || 0));
  if (!invId || amt <= 0) return false;

  return residualKeys.has(`${invId}|${tradeId}|${amt}`) || residualKeys.has(`${invId}|${amt}`);
}

function syntheticEntryTypeFromLedgerRow(row) {
  const tt = String(row.get('transactionType') || '');
  const meta = row.get('metadata') || {};
  if (tt === 'appServiceCharge') {
    return 'app_service_charge';
  }
  if (tt === 'investmentEscrow') {
    const leg = String(meta.leg || 'unknown').trim();
    return `investment_escrow_${leg}`;
  }
  return tt || 'app_ledger';
}

async function fetchInvestorAvaCashLedgerRows(userKeys, investmentIds = []) {
  const { rows: allEscrow } = await fetchInvestorEscrowLedgerRows(userKeys, investmentIds);
  return allEscrow.filter((row) => normalizeClientLiabilityAccount(row.get('account')) === CLT_LIAB_AVA);
}

/**
 * SSOT: AccountStatement + AVA-Escrow-Zeilen für Investor (Admin getUserDetails + App getAccountStatement).
 */
async function loadInvestorAccountStatementSourceData(user) {
  const userKeys = collectLedgerUserIdCandidates(user);
  const investmentIds = await listInvestorInvestmentIds(user);
  const stmtResult = await fetchAccountStatementRowsForInvestor({ userKeys, investmentIds });
  let avaRows = [];
  let escrowTruncated = false;
  if (userKeys.length > 0 || investmentIds.length > 0) {
    const escrowResult = await fetchInvestorEscrowLedgerRows(userKeys, investmentIds);
    escrowTruncated = escrowResult.truncated;
    avaRows = escrowResult.rows.filter(
      (row) => normalizeClientLiabilityAccount(row.get('account')) === CLT_LIAB_AVA,
    );
  }
  return {
    userKeys,
    investmentIds,
    stmtEntries: stmtResult.rows,
    avaRows,
    sourceTruncated: stmtResult.truncated || escrowTruncated,
  };
}

function summarizeClientFundsFromEscrowRows(escrowRows, initialBalance) {
  const available = netClientLiabilityBalance(escrowRows, CLT_LIAB_AVA);
  const reserved = netClientLiabilityBalance(escrowRows, CLT_LIAB_RSV);
  const poolTrade = netClientLiabilityBalance(escrowRows, CLT_LIAB_PTR);
  const totalClientFunds = round2(available + reserved + poolTrade);
  return {
    initialBalance: round2(initialBalance),
    available,
    reserved,
    poolTrade,
    totalClientFunds,
    /** Abweichung Wallet vs. Teil-Verbindlichkeiten (wenn Wallet nicht mitgeführt). */
    walletReconcileHint: totalClientFunds,
  };
}

/**
 * @param {{ kind: 'stmt'|'ledger', at: Date, tie: string, amount: number, stmt?: Parse.Object, ledger?: Parse.Object }} row
 * @returns {boolean}
 */
function includeLedgerRowInCustomerMergedTimeline(row) {
  if (row.kind !== 'ledger') return true;
  const meta = row.ledger.get('metadata') || {};
  const leg = String(meta.leg || '').trim();
  return !INTERNAL_TRADE_SETTLEMENT_RELEASE_LEGS.has(leg);
}

/**
 * Investments, für die bereits eine Parse-`investment_activate`-Zeile existiert: dort ist die
 * frühere AVA-`reserve`-Buchung in der kombinierten Saldenrechnung nicht nochmals zu führen
 * (sonst −Reserve und −Activate doppelt).
 */
function investmentIdsWithActivateStmt(stmtEntries) {
  const ids = new Set();
  for (const e of stmtEntries) {
    if (String(e.get('entryType') || '') !== 'investment_activate') continue;
    const id = String(e.get('investmentId') || '').trim();
    if (id) ids.add(id);
  }
  return ids;
}

/**
 * Admin **Ledger (GoB)**: alle `AccountStatement`-Zeilen (inkl. `investment_activate`) plus
 * ausgewählte AVA-`AppLedgerEntry`-Zeilen, die **kein** eigenes `AccountStatement` haben:
 * - `leg=reserve` für Investments **ohne** `investment_activate` (noch reserviert)
 * - `transactionType=appServiceCharge` (App-Servicegebühr brutto auf AVA; Rechnung/Trigger, kein Parse-Kontoauszug)
 * Trade-Settlement-Release-Legs wie in der Kundensicht ausgeblendet (Duplikat von `investment_return`).
 * Für **Admin Ledger (GoB)** können `stmtEntries` vorab mit `expandTraderLedgerStmtEntries` (Trade-Order-Gebührenaufspaltung) angereichert werden — gleiche Logik wie Trader-Details. Wenn Collection-Bill-Metadaten vorliegen, ersetzt `applyInvestorGoBCollectionBillFeeGranularity` aggregierte `trading_fees` desselben Trades durch **Einzelzeilen** laut Beleg: Kaufgebühren am `investment_activate`, Verkaufsgebühren nach letzter `residual_return` (Fallback `investment_return` / `trade_sell`).
 */
function buildInvestorLedgerGoBTimeline({ stmtEntries, avaRows, initialBalance }) {
  const skipReserveForInv = investmentIdsWithActivateStmt(stmtEntries);
  const residualDedupKeys = buildResidualReturnDedupKeys(stmtEntries);
  const combined = [];
  for (const e of stmtEntries) {
    combined.push({
      kind: 'stmt',
      at: e.get('createdAt') || new Date(0),
      tie: e.id,
      amount: parseFloat(Number(e.get('amount') || 0).toFixed(2)),
      stmt: e,
    });
  }
  for (const r of avaRows) {
    if (normalizeClientLiabilityAccount(r.get('account')) !== CLT_LIAB_AVA) continue;
    const tt = String(r.get('transactionType') || '');
    if (tt === 'appServiceCharge') {
      combined.push({
        kind: 'ledger',
        at: r.get('createdAt') || new Date(0),
        tie: r.id,
        amount: signedAmountFromAvaLedgerRow(r),
        ledger: r,
      });
      continue;
    }
    if (tt !== 'investmentEscrow') continue;
    const meta = r.get('metadata') || {};
    const leg = String(meta.leg || '').trim();
    if (leg !== 'reserve') continue;
    if (isDuplicateAvaResidualLedgerRow(r, residualDedupKeys)) continue;
    const refType = String(r.get('referenceType') || '');
    const invId = refType === 'Investment' ? String(r.get('referenceId') || '').trim() : '';
    if (!invId || skipReserveForInv.has(invId)) continue;
    combined.push({
      kind: 'ledger',
      at: r.get('createdAt') || new Date(0),
      tie: r.id,
      amount: signedAmountFromAvaLedgerRow(r),
      ledger: r,
    });
  }
  combined.sort((a, b) => {
    const ta = a.at instanceof Date ? a.at.getTime() : 0;
    const tb = b.at instanceof Date ? b.at.getTime() : 0;
    if (ta !== tb) return ta - tb;
    return String(a.tie).localeCompare(String(b.tie));
  });
  const timelineRows = combined.filter(includeLedgerRowInCustomerMergedTimeline);
  let running = initialBalance;
  return timelineRows.map((row) => {
    const balanceBefore = parseFloat(running.toFixed(2));
    running += row.amount;
    const balanceAfter = parseFloat(running.toFixed(2));
    return {
      ...row,
      balanceBefore,
      balanceAfter,
    };
  });
}

function dateMs(at) {
  if (!at || !(at instanceof Date)) return 0;
  const t = at.getTime();
  return Number.isFinite(t) ? t : 0;
}

function stmtInvId(row) {
  if (row.kind !== 'stmt') return '';
  return String(row.stmt.get('investmentId') || '').trim();
}

function stmtTradeId(row) {
  if (row.kind !== 'stmt') return '';
  return String(row.stmt.get('tradeId') || '').trim();
}

function stmtEntryType(row) {
  if (row.kind !== 'stmt') return '';
  return String(row.stmt.get('entryType') || '').trim();
}

function matchesInvAndTrade(row, invId, tradeId) {
  if (stmtInvId(row) !== invId) return false;
  const tid = stmtTradeId(row);
  if (!tradeId) return true;
  if (!tid) return true;
  return tid === tradeId;
}

function findFirstInvestmentActivateIndex(rows, invId) {
  for (let i = 0; i < rows.length; i += 1) {
    const row = rows[i];
    if (row.kind !== 'stmt') continue;
    if (stmtEntryType(row) !== 'investment_activate') continue;
    if (stmtInvId(row) !== invId) continue;
    return i;
  }
  return -1;
}

/** Verkaufsgebühren-Zeitpunkt: letzte `residual_return`, sonst letzte `investment_return`, sonst letzte `trade_sell`. */
function findLastStmtIndexByType(rows, entryType, invId, tradeId) {
  let last = -1;
  for (let i = 0; i < rows.length; i += 1) {
    const row = rows[i];
    if (row.kind !== 'stmt') continue;
    if (stmtEntryType(row) !== entryType) continue;
    if (!matchesInvAndTrade(row, invId, tradeId)) continue;
    last = i;
  }
  return last;
}

function findSellFeeAnchorIndex(rows, invId, tradeId) {
  const r = findLastStmtIndexByType(rows, 'residual_return', invId, tradeId);
  if (r >= 0) return r;
  const ret = findLastStmtIndexByType(rows, 'investment_return', invId, tradeId);
  if (ret >= 0) return ret;
  return findLastStmtIndexByType(rows, 'trade_sell', invId, tradeId);
}

function feeComponentLabel(side, key) {
  const part = key === 'orderFee' ? 'Ordergebühr'
    : key === 'exchangeFee' ? 'Börsenplatzgebühr'
      : key === 'foreignCosts' ? 'Fremdkostenpauschale'
        : 'Gebühr';
  return side === 'buy' ? `${part} (Kauf)` : `${part} (Verkauf)`;
}

function syntheticTradingFeeStmtRow({
  objectId,
  createdAt,
  amount,
  tradeId,
  tradeNumber,
  investmentId,
  description,
  referenceDocumentId,
  referenceDocumentNumber,
}) {
  return {
    id: objectId,
    get: (key) => {
      const map = {
        entryType: 'trading_fees',
        amount,
        createdAt,
        tradeId,
        tradeNumber: tradeNumber ?? null,
        investmentId,
        description,
        referenceDocumentId: referenceDocumentId || null,
        referenceDocumentNumber: referenceDocumentNumber || null,
        source: 'ledger_goB_collection_bill_fees',
      };
      return map[key];
    },
  };
}

function recomputeInvestorLedgerBalances(timelineRows, initialBalance) {
  let running = initialBalance;
  return timelineRows.map((row) => {
    const balanceBefore = parseFloat(running.toFixed(2));
    running += row.amount;
    const balanceAfter = parseFloat(running.toFixed(2));
    return {
      ...row,
      balanceBefore,
      balanceAfter,
    };
  });
}

/**
 * Admin Ledger (GoB): Handelsgebühren laut Collection-Bill **einzeln** buchen — Kaufkomponenten
 * unmittelbar nach `investment_activate`, Verkaufskomponenten nach `residual_return` (fallback
 * `investment_return` / `trade_sell`). Aggregierte `trading_fees` desselben `tradeId` werden entfernt.
 *
 * @param {Array} timeline — Ausgabe von `buildInvestorLedgerGoBTimeline`
 * @param {Array<{ investmentId?: string|null, tradeId?: string|null, documentId: string, documentNumber?: string|null, feeComponents: Array<{ side: string, key: string, amount: number }> }>} bills
 */
function applyInvestorGoBCollectionBillFeeGranularity(timeline, bills, initialBalance) {
  if (!timeline || timeline.length === 0 || !bills || bills.length === 0) {
    return timeline;
  }

  const syntheticRows = [];
  const tradesToStrip = new Set();

  for (const bill of bills) {
    const tradeId = String(bill.tradeId || '').trim();
    const invId = String(bill.investmentId || '').trim();
    if (!tradeId || !invId) continue;

    const components = bill.feeComponents || [];
    const buyParts = components.filter((f) => f.side === 'buy' && round2(Number(f.amount) || 0) > 0);
    const sellParts = components.filter((f) => f.side === 'sell' && round2(Number(f.amount) || 0) > 0);
    if (buyParts.length === 0 && sellParts.length === 0) continue;

    const activateIdx = findFirstInvestmentActivateIndex(timeline, invId);
    const sellAnchorIdx = findSellFeeAnchorIndex(timeline, invId, tradeId);
    if (activateIdx < 0 || sellAnchorIdx < 0) continue;

    const beleg = bill.documentNumber || bill.documentId;
    const activateMs = dateMs(timeline[activateIdx].at);
    const sellAnchorRawMs = dateMs(timeline[sellAnchorIdx].at);
    const lastBuySlotMs = activateMs + buyParts.length;
    const sellBaseMs = Math.max(sellAnchorRawMs, lastBuySlotMs);

    tradesToStrip.add(tradeId);

    let seq = 0;
    for (const f of buyParts) {
      const amt = round2(Number(f.amount) || 0);
      if (amt <= 0) continue;
      const ms = activateMs + (++seq);
      syntheticRows.push({
        kind: 'stmt',
        at: new Date(ms),
        tie: `goB-cb:${bill.documentId}:buy:${f.key}:${ms}`,
        amount: -amt,
        stmt: syntheticTradingFeeStmtRow({
          objectId: `goB-cb:${bill.documentId}:buy:${f.key}:${ms}`,
          createdAt: new Date(ms),
          amount: -amt,
          tradeId,
          tradeNumber: bill.tradeNumber,
          investmentId: invId,
          description: `Handelsgebühren Kauf: ${feeComponentLabel('buy', f.key)} (laut Beleg ${beleg})`,
          referenceDocumentId: bill.documentId,
          referenceDocumentNumber: bill.documentNumber || null,
        }),
      });
    }

    seq = 0;
    for (const f of sellParts) {
      const amt = round2(Number(f.amount) || 0);
      if (amt <= 0) continue;
      const ms = sellBaseMs + (++seq);
      syntheticRows.push({
        kind: 'stmt',
        at: new Date(ms),
        tie: `goB-cb:${bill.documentId}:sell:${f.key}:${ms}`,
        amount: -amt,
        stmt: syntheticTradingFeeStmtRow({
          objectId: `goB-cb:${bill.documentId}:sell:${f.key}:${ms}`,
          createdAt: new Date(ms),
          amount: -amt,
          tradeId,
          tradeNumber: bill.tradeNumber,
          investmentId: invId,
          description: `Handelsgebühren Verkauf: ${feeComponentLabel('sell', f.key)} (laut Beleg ${beleg})`,
          referenceDocumentId: bill.documentId,
          referenceDocumentNumber: bill.documentNumber || null,
        }),
      });
    }
  }

  if (tradesToStrip.size === 0) return timeline;

  const filtered = timeline.filter((row) => {
    if (row.kind !== 'stmt') return true;
    if (stmtEntryType(row) !== 'trading_fees') return true;
    const tid = stmtTradeId(row);
    if (!tid || !tradesToStrip.has(tid)) return true;
    return false;
  });

  const merged = [...filtered, ...syntheticRows];
  merged.sort((a, b) => {
    const ta = dateMs(a.at);
    const tb = dateMs(b.at);
    if (ta !== tb) return ta - tb;
    return String(a.tie).localeCompare(String(b.tie));
  });

  return recomputeInvestorLedgerBalances(merged, initialBalance);
}

/**
 * Chronologische Zeitleiste: Parse AccountStatement + Investor-AVA-AppLedger.
 * @param {{ stmtEntries: Parse.Object[], avaRows: Parse.Object[], initialBalance: number, includeInternalTradeSettlementLegs?: boolean }} p — optional `includeInternalTradeSettlementLegs: true` keeps AVA `tradeSettlementPoolRelease` / `tradeSettlementProfitRelease` (normally hidden; they duplicate `investment_return`).
 * @returns {Array<{ kind: 'stmt'|'ledger', at: Date, tie: string, amount: number, balanceAfter: number, stmt?: Parse.Object, ledger?: Parse.Object }>}
 */
function buildInvestorMergedTimeline({
  stmtEntries,
  avaRows,
  initialBalance,
  includeInternalTradeSettlementLegs = false,
}) {
  const residualDedupKeys = buildResidualReturnDedupKeys(stmtEntries);
  const combined = [];
  for (const e of stmtEntries) {
    // Internal RSV→TRD move; visible on AVA sub-ledger as investment_escrow_deploy.
    if (String(e.get('entryType') || '') === 'investment_activate') {
      continue;
    }
    combined.push({
      kind: 'stmt',
      at: e.get('createdAt') || new Date(0),
      tie: e.id,
      amount: parseFloat(Number(e.get('amount') || 0).toFixed(2)),
      stmt: e,
    });
  }
  for (const r of avaRows) {
    if (isDuplicateAvaResidualLedgerRow(r, residualDedupKeys)) {
      continue;
    }
    combined.push({
      kind: 'ledger',
      at: r.get('createdAt') || new Date(0),
      tie: r.id,
      amount: signedAmountFromAvaLedgerRow(r),
      ledger: r,
    });
  }
  combined.sort((a, b) => {
    const ta = a.at instanceof Date ? a.at.getTime() : 0;
    const tb = b.at instanceof Date ? b.at.getTime() : 0;
    if (ta !== tb) return ta - tb;
    return String(a.tie).localeCompare(String(b.tie));
  });
  const timelineRows = includeInternalTradeSettlementLegs
    ? combined
    : combined.filter(includeLedgerRowInCustomerMergedTimeline);
  let running = initialBalance;
  return timelineRows.map((row) => {
    const balanceBefore = parseFloat(running.toFixed(2));
    running += row.amount;
    const balanceAfter = parseFloat(running.toFixed(2));
    return {
      ...row,
      balanceBefore,
      balanceAfter,
    };
  });
}

function timelineRowMatchesEntryType(row, entryType) {
  if (!entryType) return true;
  if (row.kind === 'stmt') {
    return String(row.stmt.get('entryType') || '') === entryType;
  }
  return syntheticEntryTypeFromLedgerRow(row.ledger) === entryType;
}

function iso(d) {
  if (!d || !(d instanceof Date)) return new Date(0).toISOString();
  return d.toISOString();
}

function buildStmtApiRow(e, userId, balanceBefore, balanceAfter) {
  const j = e.toJSON();
  j.userId = userId;
  j.balanceBefore = round2(balanceBefore);
  j.balanceAfter = round2(balanceAfter);
  if (j.createdAt && typeof j.createdAt === 'object' && j.createdAt.__type === 'Date') {
    j.createdAt = new Date(j.createdAt.iso).toISOString();
  }
  return j;
}

function buildLedgerSyntheticApiRow(r, userId, balanceBefore, balanceAfter) {
  const meta = r.get('metadata') || {};
  const refType = String(r.get('referenceType') || '');
  const investmentId = refType === 'Investment' ? r.get('referenceId') : null;
  const entryType = syntheticEntryTypeFromLedgerRow(r);
  const created = r.get('createdAt');
  const amt = signedAmountFromAvaLedgerRow(r);
  const investmentNumber = String(meta.investmentNumber || '').trim() || null;
  return {
    objectId: `app-ledger:${r.id}`,
    userId,
    entryType,
    amount: amt,
    balanceBefore: round2(balanceBefore),
    balanceAfter: round2(balanceAfter),
    tradeId: r.get('tradeId') || null,
    tradeNumber: r.get('tradeNumber') ?? null,
    investmentId,
    investmentNumber,
    businessReference: investmentNumber || meta.businessReference || null,
    description: r.get('description') || entryType,
    source: 'app_subledger',
    referenceDocumentId: meta.referenceDocumentId || null,
    referenceDocumentNumber: meta.referenceDocumentNumber || null,
    createdAt: iso(created),
  };
}

/**
 * JSON-Zeilen für App/API (ISO-Datum), aufsteigend sortiert (älteste zuerst), mit Pagination.
 */
function mergedTimelineToApiRows(user, timeline, opts) {
  const { entryType, limit, skip } = opts;
  const filtered = entryType
    ? timeline.filter((row) => timelineRowMatchesEntryType(row, entryType))
    : timeline;
  const asc = [...filtered].sort((a, b) => {
    const ta = a.at instanceof Date ? a.at.getTime() : 0;
    const tb = b.at instanceof Date ? b.at.getTime() : 0;
    if (ta !== tb) return ta - tb;
    return String(a.tie).localeCompare(String(b.tie));
  });
  const page = asc.slice(skip, skip + limit);
  const canonicalUserId = user.get('stableId') || user.id;
  const rows = page.map((row) => (row.kind === 'stmt'
    ? buildStmtApiRow(row.stmt, canonicalUserId, row.balanceBefore, row.balanceAfter)
    : buildLedgerSyntheticApiRow(row.ledger, canonicalUserId, row.balanceBefore, row.balanceAfter)));
  return { rows, total: filtered.length };
}

/** @deprecated Use mergedTimelineToApiRows (ascending). Kept for older imports. */
function mergedTimelineToDescendingApiRows(user, timeline, opts) {
  return mergedTimelineToApiRows(user, timeline, opts);
}

module.exports = {
  signedAmountFromAvaLedgerRow,
  syntheticEntryTypeFromLedgerRow,
  buildResidualReturnDedupKeys,
  isDuplicateAvaResidualLedgerRow,
  listInvestorInvestmentIds,
  loadInvestorAccountStatementSourceData,
  fetchAccountStatementRowsForInvestor,
  fetchInvestorEscrowLedgerRows,
  fetchInvestorAvaCashLedgerRows,
  summarizeClientFundsFromEscrowRows,
  buildInvestorMergedTimeline,
  buildInvestorLedgerGoBTimeline,
  applyInvestorGoBCollectionBillFeeGranularity,
  mergedTimelineToApiRows,
  mergedTimelineToDescendingApiRows,
  timelineRowMatchesEntryType,
};
