'use strict';

const { loadConfig } = require('../../utils/configHelper/index.js');
const {
  loadInvestorAccountStatementSourceData,
  buildInvestorMergedTimeline,
  mergedTimelineToApiRows,
} = require('../../utils/investorAccountStatementMerge');
const {
  loadTraderAccountStatementSourceData,
  buildTraderCustomerTimelineForUser,
  traderCustomerTimelineToApiRows,
} = require('../../utils/traderAccountStatementPresentation');

async function loadInitialAccountBalance() {
  const liveConfig = await loadConfig(true);
  return typeof liveConfig.financial?.initialAccountBalance === 'number'
    ? liveConfig.financial.initialAccountBalance
    : 0.0;
}

async function buildInvestorAccountStatementResponse(user, { limit, skip, entryType }) {
  const initialBalance = await loadInitialAccountBalance();
  const { stmtEntries, avaRows, sourceTruncated } = await loadInvestorAccountStatementSourceData(user);
  const timeline = buildInvestorMergedTimeline({ stmtEntries, avaRows, initialBalance });
  const { rows, total } = mergedTimelineToApiRows(user, timeline, {
    entryType: entryType || null,
    limit,
    skip,
  });

  const investmentIdsFromRows = [...new Set(
    rows
      .map((row) => String(row.investmentId || '').trim())
      .filter((id) => /^[A-Za-z0-9]{10}$/.test(id)),
  )];
  const investmentNumberById = new Map();
  if (investmentIdsFromRows.length > 0) {
    const invQuery = new Parse.Query('Investment');
    invQuery.containedIn('objectId', investmentIdsFromRows);
    invQuery.limit(investmentIdsFromRows.length);
    const investments = await invQuery.find({ useMasterKey: true });
    for (const investment of investments) {
      const investmentNumber = String(investment.get('investmentNumber') || '').trim();
      if (investmentNumber) investmentNumberById.set(investment.id, investmentNumber);
    }
  }

  const entries = rows.map((row) => {
    const investmentId = String(row.investmentId || '').trim();
    const investmentNumber = String(row.investmentNumber || '').trim()
      || String(investmentNumberById.get(investmentId) || '').trim();
    if (investmentNumber) {
      row.investmentNumber = investmentNumber;
      row.businessReference = investmentNumber;
    }
    return row;
  });

  return {
    entries,
    total,
    hasMore: skip + entries.length < total,
    sortOrder: 'asc',
    timelineTruncated: Boolean(sourceTruncated),
  };
}

async function buildTraderAccountStatementResponse(user, { limit, skip, entryType }) {
  const initialBalance = await loadInitialAccountBalance();
  const { stmtEntries, invoices, sourceTruncated } = await loadTraderAccountStatementSourceData(user);
  const timeline = await buildTraderCustomerTimelineForUser({
    stmtEntries,
    invoices,
    initialBalance,
  });
  const { rows, total, hasMore } = traderCustomerTimelineToApiRows(user, timeline, {
    entryType: entryType || null,
    limit,
    skip,
  });

  return {
    entries: rows,
    total,
    hasMore,
    sortOrder: 'asc',
    timelineTruncated: sourceTruncated,
  };
}

async function handleGetAccountStatement(request) {
  const user = request.user;
  if (!user) throw new Parse.Error(Parse.Error.INVALID_SESSION_TOKEN, 'Login required');

  const { limit = 50, skip = 0, entryType } = request.params || {};
  const role = String(user.get('role') || '').toLowerCase();

  /**
   * Nur echte Trader erhalten die Trade-/Rechnungs-Netto-Timeline.
   * Alle anderen Rollen (investor, admin, leeres role, …) nutzen dieselbe Investor-Merge-Logik
   * wie `loadAccountStatementAndWalletControls` / iOS — sonst landet z. B. ein Investor mit
   * abweichend gesetztem `role` im Trader-Zweig und sieht fälschlich „Rohbuch“-artige Zeilen.
   */
  const useTraderCustomerPresentation = role === 'trader';

  if (!useTraderCustomerPresentation) {
    return buildInvestorAccountStatementResponse(user, { limit, skip, entryType });
  }

  return buildTraderAccountStatementResponse(user, { limit, skip, entryType });
}

module.exports = {
  handleGetAccountStatement,
};
