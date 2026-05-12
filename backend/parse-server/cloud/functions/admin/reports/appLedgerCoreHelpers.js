'use strict';

const { looksLikeParseObjectId } = require('./appLedgerParseIds');
const {
  LEDGER_ENTRY_SORT_FIELDS,
  LEGACY_TRANSACTION_TYPE_APP_SERVICE_CHARGE_OLD,
  TRANSACTION_TYPE_APP_SERVICE_CHARGE,
} = require('./appLedgerConstants');

function deriveBusinessReferenceFromMetadata(metadata) {
  const businessReference = String(metadata?.businessReference || '').trim();
  if (businessReference) return businessReference;
  const tradeNumber = String(metadata?.tradeNumber || '').trim();
  if (tradeNumber) return `TRD-${tradeNumber}`;
  const investmentNumber = String(metadata?.investmentNumber || '').trim();
  if (investmentNumber) return investmentNumber;
  return '';
}

async function resolveInvestmentBusinessReferences(entries) {
  const candidateIds = new Set();
  for (const entry of entries) {
    const metadata = entry.metadata || {};
    const metadataInvestmentId = String(metadata.investmentId || '').trim();
    const referenceType = String(entry.referenceType || '').trim().toLowerCase();
    const referenceId = String(entry.referenceId || '').trim();
    if (looksLikeParseObjectId(metadataInvestmentId)) candidateIds.add(metadataInvestmentId);
    if ((referenceType === 'investment' || entry.transactionType === 'investmentEscrow')
        && looksLikeParseObjectId(referenceId)) {
      candidateIds.add(referenceId);
    }
  }
  if (candidateIds.size === 0) return new Map();

  const ids = [...candidateIds];
  const investmentMap = new Map();
  const chunkSize = 100;
  for (let offset = 0; offset < ids.length; offset += chunkSize) {
    const chunk = ids.slice(offset, offset + chunkSize);
    const q = new Parse.Query('Investment');
    q.containedIn('objectId', chunk);
    q.limit(chunk.length);
    // eslint-disable-next-line no-await-in-loop
    const investments = await q.find({ useMasterKey: true });
    for (const investment of investments) {
      const investmentNumber = String(investment.get('investmentNumber') || '').trim();
      if (investmentNumber) investmentMap.set(investment.id, investmentNumber);
    }
  }
  return investmentMap;
}

async function resolveCanonicalUserIds(entries) {
  const rawIds = [...new Set(entries.map((entry) => String(entry.userId || '').trim()).filter(Boolean))];
  const stableIds = rawIds.filter((id) => !looksLikeParseObjectId(id));
  if (stableIds.length === 0) return new Map();

  const stableMap = new Map();
  const emailCandidates = [];
  for (const stableId of stableIds) {
    if (stableId.startsWith('user:')) {
      emailCandidates.push(stableId.slice(5));
      continue;
    }
    if (stableId.includes('@')) {
      emailCandidates.push(stableId);
      continue;
    }
  }

  if (emailCandidates.length > 0) {
    const emailQuery = new Parse.Query(Parse.User);
    emailQuery.containedIn('email', [...new Set(emailCandidates)]);
    const byEmail = await emailQuery.find({ useMasterKey: true });
    for (const user of byEmail) {
      const email = String(user.get('email') || '').trim().toLowerCase();
      if (!email) continue;
      stableMap.set(email, user.id);
      stableMap.set(`user:${email}`, user.id);
    }
  }

  if (stableIds.some((id) => id.startsWith('user:'))) {
    const stableQuery = new Parse.Query(Parse.User);
    stableQuery.containedIn('stableId', stableIds.filter((id) => id.startsWith('user:')));
    const byStableId = await stableQuery.find({ useMasterKey: true });
    for (const user of byStableId) {
      const stableId = String(user.get('stableId') || '').trim();
      if (stableId) stableMap.set(stableId, user.id);
    }
  }

  return stableMap;
}

async function resolveUserDisplayData(entries) {
  const userIds = [...new Set(entries.map((entry) => String(entry.userId || '').trim()).filter(looksLikeParseObjectId))];
  if (userIds.length === 0) return new Map();

  const userQuery = new Parse.Query(Parse.User);
  userQuery.containedIn('objectId', userIds);
  userQuery.limit(Math.max(100, userIds.length));
  const users = await userQuery.find({ useMasterKey: true });

  const displayMap = new Map();
  for (const user of users) {
    const firstName = String(user.get('firstName') || '').trim();
    const lastName = String(user.get('lastName') || '').trim();
    const fullName = `${firstName} ${lastName}`.trim();
    displayMap.set(user.id, {
      customerNumber: String(user.get('customerNumber') || '').trim(),
      username: String(user.get('username') || '').trim(),
      name: fullName,
    });
  }
  return displayMap;
}

function sortPlainLedgerEntries(entries, sortBy, sortOrder) {
  const field = LEDGER_ENTRY_SORT_FIELDS.includes(sortBy) ? sortBy : 'createdAt';
  const desc = String(sortOrder || '').toLowerCase() !== 'asc';
  const mul = desc ? -1 : 1;
  const tie = (a, b) => String(a.id).localeCompare(String(b.id));
  entries.sort((a, b) => {
    let va = a[field];
    let vb = b[field];
    if (field === 'createdAt') {
      va = new Date(va).getTime();
      vb = new Date(vb).getTime();
    } else if (field === 'amount') {
      va = Number(va) || 0;
      vb = Number(vb) || 0;
    } else {
      va = va == null ? '' : String(va);
      vb = vb == null ? '' : String(vb);
      const c = String(va).localeCompare(String(vb));
      if (c !== 0) return mul * c;
      return tie(a, b);
    }
    if (va < vb) return -1 * mul;
    if (va > vb) return 1 * mul;
    return tie(a, b);
  });
}

async function aggregateTotalsAndCount({
  account,
  userId,
  transactionType,
  dateFrom,
  dateTo,
}) {
  const normalizedUserId = String(userId || '').trim();
  const userIsExactObjectId = looksLikeParseObjectId(normalizedUserId);

  const match = {};
  if (account) match.account = account;
  if (userIsExactObjectId) match.userId = normalizedUserId;
  if (transactionType) {
    if (transactionType === TRANSACTION_TYPE_APP_SERVICE_CHARGE) {
      match.transactionType = { $in: [TRANSACTION_TYPE_APP_SERVICE_CHARGE, LEGACY_TRANSACTION_TYPE_APP_SERVICE_CHARGE_OLD] };
    } else {
      match.transactionType = transactionType;
    }
  }
  if (dateFrom || dateTo) {
    match.createdAt = {};
    if (dateFrom) match.createdAt.$gte = { __type: 'Date', iso: new Date(dateFrom).toISOString() };
    if (dateTo) match.createdAt.$lte = { __type: 'Date', iso: new Date(dateTo).toISOString() };
  }

  const countQuery = new Parse.Query('AppLedgerEntry');
  if (account) countQuery.equalTo('account', account);
  if (userIsExactObjectId) countQuery.equalTo('userId', normalizedUserId);
  if (transactionType) {
    if (transactionType === TRANSACTION_TYPE_APP_SERVICE_CHARGE) {
      countQuery.containedIn('transactionType', [TRANSACTION_TYPE_APP_SERVICE_CHARGE, LEGACY_TRANSACTION_TYPE_APP_SERVICE_CHARGE_OLD]);
    } else {
      countQuery.equalTo('transactionType', transactionType);
    }
  }
  if (dateFrom) countQuery.greaterThanOrEqualTo('createdAt', new Date(dateFrom));
  if (dateTo) countQuery.lessThanOrEqualTo('createdAt', new Date(dateTo));

  const [totalCount, grouped] = await Promise.all([
    countQuery.count({ useMasterKey: true }),
    (new Parse.Query('AppLedgerEntry')).aggregate([
      { match },
      {
        group: {
          objectId: {
            account: '$account',
            side: '$side',
          },
          totalAmount: { $sum: '$amount' },
        },
      },
    ], { useMasterKey: true }),
  ]);

  const totals = {};
  for (const row of grouped || []) {
    const accountCode = row?.objectId?.account;
    const side = row?.objectId?.side;
    const totalAmount = Number(row?.totalAmount || 0);
    if (!accountCode || !side) continue;
    if (!totals[accountCode]) totals[accountCode] = { credit: 0, debit: 0, net: 0 };
    if (side === 'credit') {
      totals[accountCode].credit += totalAmount;
      totals[accountCode].net += totalAmount;
    } else {
      totals[accountCode].debit += totalAmount;
      totals[accountCode].net -= totalAmount;
    }
  }
  for (const key of Object.keys(totals)) {
    totals[key].credit = Math.round(totals[key].credit * 100) / 100;
    totals[key].debit = Math.round(totals[key].debit * 100) / 100;
    totals[key].net = Math.round(totals[key].net * 100) / 100;
  }

  return { totals, totalCount };
}

module.exports = {
  deriveBusinessReferenceFromMetadata,
  resolveInvestmentBusinessReferences,
  resolveCanonicalUserIds,
  resolveUserDisplayData,
  sortPlainLedgerEntries,
  aggregateTotalsAndCount,
};
