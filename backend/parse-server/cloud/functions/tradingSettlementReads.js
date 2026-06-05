'use strict';

const { getUserStableId, getTradeIdsForInvestorStableId, collectLedgerUserIdCandidates } = require('./tradingIdentity');
const { buildUserInvoiceOrQueryBranches } = require('./tradingInvoiceQuery');
const { loadConfig } = require('../utils/configHelper/index.js');
const {
  loadInvestorAccountStatementSourceData,
  buildInvestorMergedTimeline,
  mergedTimelineToApiRows,
  mergedTimelineToDescendingApiRows,
} = require('../utils/investorAccountStatementMerge');
const {
  loadTraderAccountStatementSourceData,
  buildTraderCustomerTimelineForUser,
  traderCustomerTimelineToApiRows,
} = require('../utils/traderAccountStatementPresentation');
const { getMirrorTradeForPairedTraderLeg } = require('../utils/pairedTradeMirrorSync');
const { isMirrorPoolTradeLeg } = require('../services/poolMirrorActivation/poolActivationPolicy');

async function handleGetTradeSettlement(request) {
  const user = request.user;
  if (!user) throw new Parse.Error(Parse.Error.INVALID_SESSION_TOKEN, 'Login required');

  const { tradeId } = request.params;
  if (!tradeId) throw new Parse.Error(Parse.Error.INVALID_VALUE, 'tradeId required');

  const trade = await new Parse.Query('Trade').get(tradeId, { useMasterKey: true });
  if (!trade) throw new Parse.Error(Parse.Error.OBJECT_NOT_FOUND, 'Trade not found');

  const stableId = getUserStableId(user);
  const userKeys = collectLedgerUserIdCandidates(user);
  const isTradersOwnTrade = trade.get('traderId') === stableId;

  let isInvestorInTrade = false;
  if (!isTradersOwnTrade) {
    const investorInvestments = userKeys.length === 0
      ? []
      : await new Parse.Query('Investment')
        .containedIn('investorId', userKeys)
        .find({ useMasterKey: true });
    const investmentIds = investorInvestments.map(i => i.id);

    if (investmentIds.length > 0) {
      const participationCount = await new Parse.Query('PoolTradeParticipation')
        .equalTo('tradeId', tradeId)
        .containedIn('investmentId', investmentIds)
        .count({ useMasterKey: true });
      isInvestorInTrade = participationCount > 0;
    }
  }

  if (!isTradersOwnTrade && !isInvestorInTrade && !request.master) {
    throw new Parse.Error(Parse.Error.OPERATION_FORBIDDEN, 'Access denied');
  }

  const accountEntries = await new Parse.Query('AccountStatement')
    .equalTo('tradeId', tradeId)
    .equalTo('source', 'backend')
    .find({ useMasterKey: true });

  const documents = await new Parse.Query('Document')
    .equalTo('tradeId', tradeId)
    .equalTo('source', 'backend')
    .find({ useMasterKey: true });

  let mirrorTrade = null;
  let poolParticipationCount = 0;
  if (isTradersOwnTrade && !isMirrorPoolTradeLeg(trade)) {
    mirrorTrade = await getMirrorTradeForPairedTraderLeg(trade);
    if (mirrorTrade?.id) {
      poolParticipationCount = await new Parse.Query('PoolTradeParticipation')
        .equalTo('tradeId', mirrorTrade.id)
        .count({ useMasterKey: true });
    }
  } else if (isMirrorPoolTradeLeg(trade)) {
    poolParticipationCount = await new Parse.Query('PoolTradeParticipation')
      .equalTo('tradeId', tradeId)
      .count({ useMasterKey: true });
  }

  let settlementDocuments = documents;
  if (mirrorTrade?.id && mirrorTrade.id !== tradeId) {
    const mirrorDocs = await new Parse.Query('Document')
      .equalTo('tradeId', mirrorTrade.id)
      .equalTo('source', 'backend')
      .find({ useMasterKey: true });
    const seen = new Set(documents.map((d) => d.id));
    settlementDocuments = [
      ...documents,
      ...mirrorDocs.filter((d) => !seen.has(d.id)),
    ];
  }

  const commissions = await new Parse.Query('Commission')
    .equalTo('tradeId', tradeId)
    .find({ useMasterKey: true });

  const userEntries = accountEntries
    .filter(e => userKeys.includes(e.get('userId')))
    .map(e => e.toJSON());

  const userDocuments = settlementDocuments
    .filter(d => userKeys.includes(d.get('userId')))
    .map(d => d.toJSON());

  return {
    tradeId,
    tradeNumber: trade.get('tradeNumber'),
    pairExecutionId: trade.get('pairExecutionId') || null,
    mirrorTradeId: mirrorTrade?.id || null,
    poolParticipationCount,
    grossProfit: trade.get('grossProfit') || 0,
    totalFees: trade.get('totalFees') || 0,
    netProfit: trade.get('netProfit') || 0,
    status: trade.get('status'),
    isSettledByBackend: accountEntries.length > 0,
    accountStatementEntries: userEntries,
    documents: userDocuments,
    commissions: commissions
      .filter(c => userKeys.includes(c.get('traderId')) || userKeys.includes(c.get('investorId')))
      .map(c => c.toJSON()),
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
    const liveConfig = await loadConfig(true);
    const initialBalance =
      typeof liveConfig.financial?.initialAccountBalance === 'number'
        ? liveConfig.financial.initialAccountBalance
        : 0.0;

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

  const liveConfig = await loadConfig(true);
  const initialBalance =
    typeof liveConfig.financial?.initialAccountBalance === 'number'
      ? liveConfig.financial.initialAccountBalance
      : 0.0;

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

async function handleGetTradeInvoices(request) {
  const user = request.user;
  if (!user) throw new Parse.Error(Parse.Error.INVALID_SESSION_TOKEN, 'Login required');

  const { tradeId } = request.params || {};
  if (!tradeId) throw new Parse.Error(Parse.Error.INVALID_VALUE, 'tradeId is required');

  const stableId = getUserStableId(user);
  const role = String(user.get('role') || '').toLowerCase();

  const query = new Parse.Query('Invoice');
  query.equalTo('tradeId', tradeId);
  if (role === 'investor') {
    const allowedTradeIds = await getTradeIdsForInvestorStableId(stableId, user.id);
    if (!allowedTradeIds.includes(String(tradeId))) {
      throw new Parse.Error(Parse.Error.OPERATION_FORBIDDEN, 'Kein Zugriff auf diesen Trade.');
    }
    query.containedIn('invoiceType', ['buy_invoice', 'sell_invoice', 'buy', 'sell']);
  } else {
    const ownerKeys = [stableId, user.id].filter((v) => typeof v === 'string' && v.trim().length > 0);
    query.containedIn('userId', [...new Set(ownerKeys)]);
  }
  query.descending('invoiceDate');

  const invoices = await query.find({ useMasterKey: true });

  return {
    invoices: invoices.map(inv => inv.toJSON()),
    count: invoices.length,
  };
}

async function handleGetUserInvoices(request) {
  const user = request.user;
  if (!user) throw new Parse.Error(Parse.Error.INVALID_SESSION_TOKEN, 'Login required');

  const { limit = 50, skip = 0, invoiceType } = request.params || {};
  const stableId = getUserStableId(user);
  const role = String(user.get('role') || '').toLowerCase();

  let tradeIds = [];
  if (role === 'investor') {
    tradeIds = await getTradeIdsForInvestorStableId(stableId, user.id);
  }

  const branchesForFind = buildUserInvoiceOrQueryBranches({
    stableId,
    parseUserId: user.id,
    role,
    invoiceType,
    tradeIds,
  });

  const findQuery = branchesForFind.length === 1
    ? branchesForFind[0]
    : Parse.Query.or(...branchesForFind);
  findQuery.descending('invoiceDate');
  findQuery.limit(limit);
  findQuery.skip(skip);

  const invoices = await findQuery.find({ useMasterKey: true });
  const enrichedInvoices = await enrichServiceChargeInvoicesForDisplay(invoices, user);

  const branchesForCount = buildUserInvoiceOrQueryBranches({
    stableId,
    parseUserId: user.id,
    role,
    invoiceType,
    tradeIds,
  });

  const countQuery = branchesForCount.length === 1
    ? branchesForCount[0]
    : Parse.Query.or(...branchesForCount);
  countQuery.descending('invoiceDate');
  const total = await countQuery.count({ useMasterKey: true });

  return {
    invoices: enrichedInvoices.map((inv) => inv.toJSON()),
    total,
    hasMore: skip + invoices.length < total,
  };
}

function isBusinessCustomerNumber(value) {
  const trimmed = String(value || '').trim();
  return trimmed.startsWith('ANL-') || trimmed.startsWith('TRD-');
}

/**
 * Patches legacy service_charge rows for display (Kundennummer + INV list in metadata).
 */
async function enrichServiceChargeInvoicesForDisplay(invoices, sessionUser) {
  const serviceChargeRows = invoices.filter((inv) => {
    const type = String(inv.get('invoiceType') || '').toLowerCase();
    return type === 'service_charge' || type === 'app_service_charge' || type === 'platform_service_charge';
  });
  if (serviceChargeRows.length === 0) {
    return invoices;
  }

  const sessionCustomerNumber = String(
    sessionUser.get('customerNumber') || sessionUser.get('customerId') || '',
  ).trim();

  const parseIdsNeedingInvNumbers = new Set();
  for (const inv of serviceChargeRows) {
    const metadata = inv.get('metadata') || {};
    const numbers = Array.isArray(metadata.investmentNumbers)
      ? metadata.investmentNumbers.filter(Boolean)
      : [];
    if (numbers.length > 0) continue;
    const ids = inv.get('investmentIds') || [];
    ids.forEach((id) => {
      const trimmed = String(id || '').trim();
      if (trimmed && !trimmed.startsWith('INV-')) parseIdsNeedingInvNumbers.add(trimmed);
    });
  }

  const invNumberByObjectId = new Map();
  if (parseIdsNeedingInvNumbers.size > 0) {
    const Investment = Parse.Object.extend('Investment');
    const q = new Parse.Query(Investment);
    q.containedIn('objectId', [...parseIdsNeedingInvNumbers]);
    q.limit(1000);
    const rows = await q.find({ useMasterKey: true });
    rows.forEach((row) => {
      const num = String(row.get('investmentNumber') || '').trim();
      if (num) invNumberByObjectId.set(row.id, num);
    });
  }

  return invoices.map((inv) => {
    const type = String(inv.get('invoiceType') || '').toLowerCase();
    const isServiceCharge = type === 'service_charge'
      || type === 'app_service_charge'
      || type === 'platform_service_charge';
    if (!isServiceCharge) return inv;

    const storedCustomerId = String(inv.get('customerId') || '').trim();
    if (!isBusinessCustomerNumber(storedCustomerId) && isBusinessCustomerNumber(sessionCustomerNumber)) {
      inv.set('customerId', sessionCustomerNumber);
    }

    const metadata = { ...(inv.get('metadata') || {}) };
    let numbers = Array.isArray(metadata.investmentNumbers)
      ? metadata.investmentNumbers.filter(Boolean)
      : [];
    if (numbers.length === 0) {
      const ids = inv.get('investmentIds') || [];
      numbers = ids
        .map((id) => {
          const trimmed = String(id || '').trim();
          if (trimmed.startsWith('INV-')) return trimmed;
          return invNumberByObjectId.get(trimmed) || '';
        })
        .filter(Boolean);
      if (numbers.length > 0) {
        metadata.investmentNumbers = numbers;
        if (!metadata.investmentNumber) {
          metadata.investmentNumber = numbers[0];
        }
        inv.set('metadata', metadata);
      }
    }

    return inv;
  });
}

module.exports = {
  handleGetTradeSettlement,
  handleGetAccountStatement,
  handleGetTradeInvoices,
  handleGetUserInvoices,
};
