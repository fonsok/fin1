'use strict';

const { collectLedgerUserIdCandidates } = require('../../tradingIdentity');
const {
  loadInvestorAccountStatementSourceData,
  fetchInvestorEscrowLedgerRows,
  summarizeClientFundsFromEscrowRows,
  buildInvestorMergedTimeline,
  buildInvestorLedgerGoBTimeline,
  applyInvestorGoBCollectionBillFeeGranularity,
} = require('../../../utils/investorAccountStatementMerge');
const {
  loadTraderAccountStatementSourceData,
  buildTraderCustomerTimelineForUser,
} = require('../../../utils/traderAccountStatementPresentation');
const { summarizeInvestorOutcomeHighlights } = require('../usersDetailStatementOutcomeSummary');
const {
  expandTraderLedgerStmtEntries,
  loadTradesByIds,
} = require('../traderLedgerStatementExpansion');
const { loadConfig } = require('../../../utils/configHelper/index.js');
const { buildWalletControlsForUser } = require('./walletPermissions');
const { summarizeTimelineAmounts } = require('./timelineTotals');
const {
  mapInvestorTimelineToAdminEntries,
  mapTraderTimelineToAdminEntries,
} = require('./timelineMappers');
const { buildLedgerAccountStatementFromStmtEntries } = require('./ledgerStatement');
const { loadInvestorCollectionBillSummariesForAdmin } = require('./collectionBillSummaries');

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

  const { walletControls, userWalletActionModeOverride } = buildWalletControlsForUser(user, liveConfig);

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
};
