'use strict';

const { looksLikeParseObjectId } = require('./appLedgerParseIds');

const TRADER_DOCUMENT_TYPES = new Set([
  'traderCollectionBill',
  'trade_execution_document',
  'traderCreditNote',
]);

const INVESTOR_DOCUMENT_TYPES = new Set([
  'investorCollectionBill',
  'investor_collection_bill',
  'investmentReservationEigenbeleg',
]);

/**
 * Rolle des Document-Inhabers (`userId`) für Admin-Belegdarstellung.
 * @returns {'trader'|'investor'|'other'}
 */
function documentPartyRole(type, doc) {
  const t = String(type || '').trim();
  if (TRADER_DOCUMENT_TYPES.has(t)) return 'trader';
  if (INVESTOR_DOCUMENT_TYPES.has(t)) return 'investor';
  if (t === 'monthlyAccountStatement') {
    const role = String(doc?.get?.('statementRole') || '').trim().toLowerCase();
    if (role === 'trader' || role === 'investor') return role;
  }
  return 'other';
}

function partyRoleLabel(role) {
  if (role === 'trader') return 'Trader';
  if (role === 'investor') return 'Investor';
  return 'Inhaber';
}

function formatPartyValue(userId, displayName) {
  const id = String(userId || '').trim();
  const name = String(displayName || '').trim();
  if (!id) return '—';
  return name ? `${name} · ${id}` : id;
}

function pickDisplayName(userFields) {
  if (!userFields) return null;
  const fullName = String(userFields.name || '').trim();
  if (fullName) return fullName;
  const username = String(userFields.username || '').trim();
  if (username) return username;
  const customerNumber = String(userFields.customerNumber || '').trim();
  if (customerNumber) return customerNumber;
  return null;
}

async function resolveDocumentOwnerDisplayMap(userIds) {
  const ids = [...new Set(
    userIds.map((id) => String(id || '').trim()).filter(looksLikeParseObjectId),
  )];
  if (ids.length === 0) return new Map();

  const userQuery = new Parse.Query(Parse.User);
  userQuery.containedIn('objectId', ids);
  userQuery.limit(Math.min(100, Math.max(ids.length, 1)));
  const users = await userQuery.find({ useMasterKey: true });

  const displayMap = new Map();
  for (const user of users) {
    const firstName = String(user.get('firstName') || '').trim();
    const lastName = String(user.get('lastName') || '').trim();
    displayMap.set(user.id, {
      name: `${firstName} ${lastName}`.trim(),
      username: String(user.get('username') || '').trim(),
      customerNumber: String(user.get('customerNumber') || '').trim(),
    });
  }
  return displayMap;
}

function attachPartyFieldsToRow(row, doc, displayMap) {
  const role = documentPartyRole(row.type, doc);
  const partyUserId = String(row.userId || doc.get('userId') || '').trim();
  const userFields = displayMap.get(partyUserId);
  const partyDisplayName = pickDisplayName(userFields);

  const enriched = {
    ...row,
    partyRole: role,
    partyUserId: partyUserId || null,
    partyDisplayName,
    partyLabel: partyRoleLabel(role),
  };

  if (role === 'trader') {
    enriched.traderId = partyUserId || null;
    enriched.traderName = partyDisplayName;
  }

  return enriched;
}

/**
 * Batch-Anreicherung für searchDocuments / Einzelabruf (nur Anzeige, kein SSOT).
 */
async function enrichDocumentsWithPartyFields(projectedRows, docs) {
  const userIds = docs.map((doc) => String(doc.get('userId') || '').trim());
  const displayMap = await resolveDocumentOwnerDisplayMap(userIds);
  return projectedRows.map((row, index) => attachPartyFieldsToRow(row, docs[index], displayMap));
}

module.exports = {
  documentPartyRole,
  partyRoleLabel,
  formatPartyValue,
  resolveDocumentOwnerDisplayMap,
  attachPartyFieldsToRow,
  enrichDocumentsWithPartyFields,
  TRADER_DOCUMENT_TYPES,
  INVESTOR_DOCUMENT_TYPES,
};
