'use strict';

const { loadConfig } = require('../../utils/configHelper/index.js');
const { normalizeWalletActionMode } = require('./usersConstants');
const { collectLedgerUserIdCandidates } = require('../tradingIdentity');
const {
  loadInvestorAccountStatementSourceData,
  fetchInvestorEscrowLedgerRows,
  summarizeClientFundsFromEscrowRows,
  buildInvestorMergedTimeline,
  buildInvestorLedgerGoBTimeline,
  applyInvestorGoBCollectionBillFeeGranularity,
  syntheticEntryTypeFromLedgerRow,
  listInvestorInvestmentIds,
} = require('../../utils/investorAccountStatementMerge');
const {
  loadTraderAccountStatementSourceData,
  buildTraderCustomerTimelineForUser,
} = require('../../utils/traderAccountStatementPresentation');
const { summarizeInvestorOutcomeHighlights } = require('./usersDetailStatementOutcomeSummary');
const { round2 } = require('../../utils/accountingHelper/shared');
const {
  expandTraderLedgerStmtEntries,
  loadTradesByIds,
} = require('./traderLedgerStatementExpansion');

function modeToPermissions(mode) {
  switch (mode) {
    case 'deposit_only':
      return { deposit: true, withdrawal: false };
    case 'withdrawal_only':
      return { deposit: false, withdrawal: true };
    case 'deposit_and_withdrawal':
      return { deposit: true, withdrawal: true };
    default:
      return { deposit: false, withdrawal: false };
  }
}

function permissionsToMode(permissions) {
  if (permissions.deposit && permissions.withdrawal) return 'deposit_and_withdrawal';
  if (permissions.deposit) return 'deposit_only';
  if (permissions.withdrawal) return 'withdrawal_only';
  return 'disabled';
}

function summarizeTimelineAmounts(timeline, initialBalance) {
  const totalCredits = timeline.reduce((s, r) => (r.amount > 0 ? s + r.amount : s), 0);
  const totalDebits = timeline.reduce((s, r) => (r.amount < 0 ? s + Math.abs(r.amount) : s), 0);
  const closingBal = timeline.length > 0
    ? timeline[timeline.length - 1].balanceAfter
    : initialBalance;
  return {
    totalCredits: parseFloat(totalCredits.toFixed(2)),
    totalDebits: parseFloat(totalDebits.toFixed(2)),
    closingBalance: parseFloat(closingBal.toFixed(2)),
    netChange: parseFloat((totalCredits - totalDebits).toFixed(2)),
  };
}

function mapInvestorTimelineToAdminEntries(timeline, formatDate) {
  const accountStatementEntries = [];
  for (const row of timeline) {
    const balanceAfter = row.balanceAfter;
    if (row.kind === 'stmt') {
      const e = row.stmt;
      accountStatementEntries.push({
        objectId: e.id,
        entryType: e.get('entryType'),
        amount: row.amount,
        balanceAfter,
        tradeId: e.get('tradeId'),
        tradeNumber: e.get('tradeNumber'),
        investmentId: e.get('investmentId'),
        description: e.get('description'),
        referenceDocumentId: e.get('referenceDocumentId') || null,
        referenceDocumentNumber: e.get('referenceDocumentNumber') || null,
        source: e.get('source'),
        createdAt: formatDate(e.get('createdAt')),
      });
    } else {
      const r = row.ledger;
      const meta = r.get('metadata') || {};
      const refType = String(r.get('referenceType') || '');
      const investmentId = refType === 'Investment' ? r.get('referenceId') : null;
      accountStatementEntries.push({
        objectId: `app-ledger:${r.id}`,
        entryType: syntheticEntryTypeFromLedgerRow(r),
        amount: row.amount,
        balanceAfter,
        tradeId: r.get('tradeId') || null,
        tradeNumber: r.get('tradeNumber') || null,
        investmentId,
        description: r.get('description') || syntheticEntryTypeFromLedgerRow(r),
        referenceDocumentId: meta.referenceDocumentId || null,
        source: 'app_subledger',
        createdAt: formatDate(r.get('createdAt')),
      });
    }
  }
  return accountStatementEntries;
}

/**
 * Admin ledger view: raw `AccountStatement` rows (GoB), incl. `trading_fees` per leg.
 */
function buildLedgerAccountStatementFromStmtEntries(
  stmtEntries,
  initialBalance,
  formatDate,
  sourceTruncated,
) {
  const sorted = [...stmtEntries].sort((a, b) => {
    const ta = (a.get('createdAt') || new Date(0)).getTime();
    const tb = (b.get('createdAt') || new Date(0)).getTime();
    if (ta !== tb) return ta - tb;
    return String(a.id).localeCompare(String(b.id));
  });

  let running = round2(initialBalance);
  const entries = [];
  const timelineForTotals = [];

  for (const e of sorted) {
    const amount = round2(Number(e.get('amount') || 0));
    running = round2(running + amount);
    entries.push({
      objectId: e.id,
      entryType: String(e.get('entryType') || ''),
      amount,
      balanceAfter: running,
      tradeId: e.get('tradeId') || undefined,
      tradeNumber: e.get('tradeNumber') ?? undefined,
      investmentId: e.get('investmentId') || undefined,
      description: e.get('description') || String(e.get('entryType') || ''),
      referenceDocumentId: e.get('referenceDocumentId') || null,
      referenceDocumentNumber: e.get('referenceDocumentNumber') || null,
      source: e.get('source') || 'backend',
      createdAt: formatDate(e.get('createdAt')),
    });
    timelineForTotals.push({ amount, balanceAfter: running });
  }

  const totals = summarizeTimelineAmounts(timelineForTotals, initialBalance);
  return {
    initialBalance,
    closingBalance: totals.closingBalance,
    totalCredits: totals.totalCredits,
    totalDebits: totals.totalDebits,
    netChange: totals.netChange,
    entries,
    sortOrder: 'asc',
    timelineTruncated: Boolean(sourceTruncated),
    presentationMode: 'ledger',
  };
}

function mapTraderTimelineToAdminEntries(timeline, formatDate) {
  return timeline.map((event) => ({
    objectId: String(event.objectId),
    entryType: event.entryType,
    amount: event.amount,
    balanceAfter: event.balanceAfter,
    tradeId: event.tradeId || undefined,
    tradeNumber: event.tradeNumber ?? undefined,
    investmentId: undefined,
    description: event.statementTitle || event.description || event.entryType,
    referenceDocumentId: event.referenceDocumentId || null,
    referenceDocumentNumber: event.referenceDocumentNumber || null,
    source: event.source || 'customer_display',
    createdAt: formatDate(event.at),
  }));
}

function dedupeParseDocumentsById(rows) {
  const seen = new Set();
  return rows.filter((d) => {
    if (!d?.id || seen.has(d.id)) return false;
    seen.add(d.id);
    return true;
  });
}

function investmentIdFromDocument(doc) {
  const raw = doc.get('investmentId');
  if (!raw) return null;
  if (typeof raw === 'object' && raw.id) return String(raw.id);
  return String(raw).trim() || null;
}

function pickCollectionBillFeeComponents(buyFees, sellFees) {
  const out = [];
  for (const [side, fees] of [['buy', buyFees || {}], ['sell', sellFees || {}]]) {
    let anyDetail = false;
    for (const key of ['orderFee', 'exchangeFee', 'foreignCosts']) {
      const amt = round2(Number(fees[key]) || 0);
      if (amt > 0) {
        out.push({ side, key, amount: amt });
        anyDetail = true;
      }
    }
    if (!anyDetail) {
      const tot = round2(Number(fees.totalFees) || 0);
      if (tot > 0) out.push({ side, key: 'totalFees', amount: tot });
    }
  }
  return out;
}

function mapInvestorCollectionBillDocumentToSummary(doc, formatDate) {
  const meta = doc.get('metadata') || {};
  const buyLeg = meta.buyLeg || {};
  const sellLeg = meta.sellLeg || {};
  const buyFees = buyLeg.fees || {};
  const sellFees = sellLeg.fees || {};
  return {
    documentId: doc.id,
    documentNumber: doc.get('accountingDocumentNumber') || null,
    tradeId: doc.get('tradeId') || null,
    tradeNumber: doc.get('tradeNumber') ?? null,
    investmentId: investmentIdFromDocument(doc),
    createdAt: formatDate(doc.get('createdAt')),
    transferAmount: round2(Number(meta.transferAmount) || 0),
    commission: round2(Number(meta.commission) || 0),
    commissionRate: typeof meta.commissionRate === 'number' ? meta.commissionRate : null,
    grossProfit: round2(Number(meta.grossProfit) || 0),
    netProfit: round2(Number(meta.netProfit) || 0),
    totalBuyCost: round2(Number(meta.totalBuyCost) || 0),
    netSellAmount: round2(Number(meta.netSellAmount) || 0),
    buy: {
      quantity: buyLeg.quantity,
      price: buyLeg.price,
      amount: round2(Number(buyLeg.amount) || 0),
      costBasisPerShare:
        typeof buyLeg.costBasisPerShare === 'number' ? buyLeg.costBasisPerShare : null,
    },
    sell: {
      quantity: sellLeg.quantity,
      price: sellLeg.price,
      amount: round2(Number(sellLeg.amount) || 0),
      netSellPricePerShare:
        typeof sellLeg.netSellPricePerShare === 'number' ? sellLeg.netSellPricePerShare : null,
    },
    feeComponents: pickCollectionBillFeeComponents(buyFees, sellFees),
  };
}

async function loadInvestorCollectionBillSummariesForAdmin(user, formatDate) {
  if (String(user.get('role') || '').toLowerCase() !== 'investor') return [];
  const userKeys = collectLedgerUserIdCandidates(user).filter(Boolean);
  const investmentIds = await listInvestorInvestmentIds(user);
  const queries = [];
  if (userKeys.length > 0) {
    const q = new Parse.Query('Document');
    q.equalTo('type', 'investorCollectionBill');
    q.containedIn('userId', userKeys);
    queries.push(q);
  }
  if (investmentIds.length > 0) {
    const q2 = new Parse.Query('Document');
    q2.equalTo('type', 'investorCollectionBill');
    q2.containedIn('investmentId', investmentIds);
    queries.push(q2);
  }
  if (queries.length === 0) return [];
  const combined = queries.length === 1 ? queries[0] : Parse.Query.or(...queries);
  combined.descending('createdAt');
  combined.limit(100);
  const rows = dedupeParseDocumentsById(await combined.find({ useMasterKey: true }));
  return rows.map((doc) => mapInvestorCollectionBillDocumentToSummary(doc, formatDate));
}

async function loadAccountStatementAndWalletControls(user, formatDate) {
  const userKeys = collectLedgerUserIdCandidates(user);
  const role = String(user.get('role') || '').toLowerCase();
  const isInvestor = role === 'investor';
  const isTrader = role === 'trader';
  /** Wie `getAccountStatement`: nur Trader erhalten die Trade-Netto-Timeline; alle anderen → Investor-Merge. */
  const useInvestorAccountStatementMerge = !isTrader;

  const liveConfig = await loadConfig(true);
  const initialBalance =
    typeof liveConfig.financial?.initialAccountBalance === 'number'
      ? liveConfig.financial.initialAccountBalance
      : 0.0;

  let accountStatementEntries = [];
  let timelineForTotals = [];
  let sourceTruncated = false;
  let sortOrder = 'asc';
  let investmentIds = [];
  let stmtEntriesForLedger = [];
  let investorLedgerTimeline = null;
  let investorCollectionBills = [];

  if (isTrader) {
    const source = await loadTraderAccountStatementSourceData(user);
    sourceTruncated = source.sourceTruncated;
    stmtEntriesForLedger = source.stmtEntries;
    const traderTimeline = await buildTraderCustomerTimelineForUser({
      stmtEntries: source.stmtEntries,
      invoices: source.invoices,
      initialBalance,
    });
    accountStatementEntries = mapTraderTimelineToAdminEntries(traderTimeline, formatDate);
    timelineForTotals = traderTimeline;
    sortOrder = 'asc';
  } else if (useInvestorAccountStatementMerge) {
    const source = await loadInvestorAccountStatementSourceData(user);
    sourceTruncated = source.sourceTruncated;
    investmentIds = source.investmentIds;
    stmtEntriesForLedger = source.stmtEntries;

    let investorCollectionBillsEarly = [];
    try {
      investorCollectionBillsEarly = await loadInvestorCollectionBillSummariesForAdmin(user, formatDate);
    } catch (err) {
      console.error('loadInvestorCollectionBillSummariesForAdmin failed:', err && err.message ? err.message : err);
      investorCollectionBillsEarly = [];
    }

    const investorTimeline = buildInvestorMergedTimeline({
      stmtEntries: source.stmtEntries,
      avaRows: source.avaRows,
      initialBalance,
    });
    accountStatementEntries = mapInvestorTimelineToAdminEntries(investorTimeline, formatDate);
    timelineForTotals = investorTimeline;
    sortOrder = 'asc';
    /**
     * Ledger (GoB) für Investor: **kein** `expandTraderLedgerStmtEntries`.
     * Investor-Statements haben keinen `trade_buy`/`trade_sell` (das sind Trader-Events)
     * und keine aggregierte `trading_fees`-Rohzeile. Trader-side `calculateOrderFees`
     * würden nicht zu den **investor-side** CB-Splits passen (Buy/Sell-Betrag des
     * Investors ≠ Trader-Order-Total). Granularität kommt aus `investorCollectionBill`
     * via `applyInvestorGoBCollectionBillFeeGranularity` (SSOT: Beleg `metadata.buyLeg/sellLeg`).
     */
    let ledgerGoB = buildInvestorLedgerGoBTimeline({
      stmtEntries: source.stmtEntries,
      avaRows: source.avaRows,
      initialBalance,
    });
    ledgerGoB = applyInvestorGoBCollectionBillFeeGranularity(ledgerGoB, investorCollectionBillsEarly, initialBalance);
    investorLedgerTimeline = ledgerGoB;
    investorCollectionBills = investorCollectionBillsEarly;
  }

  let clientFundsBreakdown = null;
  if (isInvestor && (userKeys.length > 0 || investmentIds.length > 0)) {
    const { rows: escrowRows } = await fetchInvestorEscrowLedgerRows(userKeys, investmentIds);
    clientFundsBreakdown = summarizeClientFundsFromEscrowRows(escrowRows, initialBalance);
  }

  const totals = summarizeTimelineAmounts(timelineForTotals, initialBalance);

  const accountStatement = {
    initialBalance,
    closingBalance: totals.closingBalance,
    totalCredits: totals.totalCredits,
    totalDebits: totals.totalDebits,
    netChange: totals.netChange,
    entries: accountStatementEntries,
    sortOrder,
    timelineTruncated: sourceTruncated,
    presentationMode: 'customer',
  };

  let ledgerStmtEntries = stmtEntriesForLedger;
  if (isTrader && stmtEntriesForLedger.length > 0) {
    const tradeIds = [...new Set(
      stmtEntriesForLedger
        .map((row) => String(row.get('tradeId') || '').trim())
        .filter(Boolean),
    )];
    const tradesById = await loadTradesByIds(tradeIds);
    ledgerStmtEntries = expandTraderLedgerStmtEntries(stmtEntriesForLedger, tradesById);
  }

  let accountStatementLedger = null;
  if (isTrader && ledgerStmtEntries.length > 0) {
    accountStatementLedger = buildLedgerAccountStatementFromStmtEntries(
      ledgerStmtEntries,
      initialBalance,
      formatDate,
      sourceTruncated,
    );
  } else if (investorLedgerTimeline && investorLedgerTimeline.length > 0) {
    const ledgerEntries = mapInvestorTimelineToAdminEntries(investorLedgerTimeline, formatDate);
    const ledgerTotals = summarizeTimelineAmounts(investorLedgerTimeline, initialBalance);
    accountStatementLedger = {
      initialBalance,
      closingBalance: ledgerTotals.closingBalance,
      totalCredits: ledgerTotals.totalCredits,
      totalDebits: ledgerTotals.totalDebits,
      netChange: ledgerTotals.netChange,
      entries: ledgerEntries,
      sortOrder: 'asc',
      timelineTruncated: sourceTruncated,
      presentationMode: 'ledger',
    };
  }

  const investorOutcomeHighlights =
    isInvestor && accountStatementEntries.length > 0
      ? summarizeInvestorOutcomeHighlights(accountStatementEntries)
      : null;

  const globalWalletMode =
    normalizeWalletActionMode(liveConfig.display?.walletActionModeGlobal || liveConfig.display?.walletActionMode) || 'disabled';
  const roleWalletMode =
    isInvestor
      ? (normalizeWalletActionMode(liveConfig.display?.walletActionModeInvestor) || 'deposit_and_withdrawal')
      : isTrader
        ? (normalizeWalletActionMode(liveConfig.display?.walletActionModeTrader) || 'deposit_and_withdrawal')
        : 'deposit_and_withdrawal';
  const accountTypeWalletMode =
    String(user.get('accountType') || '').toLowerCase() === 'company'
      ? (normalizeWalletActionMode(liveConfig.display?.walletActionModeCompany) || 'deposit_and_withdrawal')
      : (normalizeWalletActionMode(liveConfig.display?.walletActionModeIndividual) || 'deposit_and_withdrawal');
  const userWalletActionModeOverride = normalizeWalletActionMode(user.get('walletActionModeOverride'));

  const globalPermissions = modeToPermissions(globalWalletMode);
  const rolePermissions = modeToPermissions(roleWalletMode);
  const accountTypePermissions = modeToPermissions(accountTypeWalletMode);
  const userPermissions = modeToPermissions(userWalletActionModeOverride || 'deposit_and_withdrawal');
  const effectiveWalletMode = permissionsToMode({
    deposit: globalPermissions.deposit && rolePermissions.deposit && accountTypePermissions.deposit && userPermissions.deposit,
    withdrawal: globalPermissions.withdrawal && rolePermissions.withdrawal && accountTypePermissions.withdrawal && userPermissions.withdrawal,
  });

  const walletControls = {
    globalMode: globalWalletMode,
    roleMode: roleWalletMode,
    accountTypeMode: accountTypeWalletMode,
    userOverrideMode: userWalletActionModeOverride,
    effectiveMode: effectiveWalletMode,
  };

  return {
    accountStatement,
    accountStatementLedger,
    clientFundsBreakdown,
    investorOutcomeHighlights,
    walletControls,
    userWalletActionModeOverride,
    investorCollectionBills,
  };
}

module.exports = {
  loadAccountStatementAndWalletControls,
  buildLedgerAccountStatementFromStmtEntries,
  mapTraderTimelineToAdminEntries,
  mapInvestorTimelineToAdminEntries,
  mapInvestorCollectionBillDocumentToSummary,
};
