'use strict';

const { looksLikeParseObjectId } = require('./appLedgerParseIds');
const {
  deriveBusinessReferenceFromMetadata,
  resolveInvestmentBusinessReferences,
  resolveCanonicalUserIds,
  resolveUserDisplayData,
} = require('./appLedgerCoreHelpers');

async function enrichLedgerRowsForReporting(entries) {
  const investmentBusinessRefMap = await resolveInvestmentBusinessReferences(entries);
  const canonicalUserIds = await resolveCanonicalUserIds(entries);
  const normalizedEntries = entries.map((entry) => {
    const originalUserId = String(entry.userId || '').trim();
    const normalizedLookupKey = originalUserId.toLowerCase();
    const canonicalUserId = canonicalUserIds.get(originalUserId)
      || canonicalUserIds.get(normalizedLookupKey)
      || originalUserId;
    const metadata = entry.metadata || {};
    const referenceType = String(entry.referenceType || '').trim().toLowerCase();
    const referenceId = String(entry.referenceId || '').trim();
    const metadataInvestmentId = String(metadata.investmentId || '').trim();
    const investmentLookupId = looksLikeParseObjectId(metadataInvestmentId)
      ? metadataInvestmentId
      : ((referenceType === 'investment' || entry.transactionType === 'investmentEscrow') && looksLikeParseObjectId(referenceId)
        ? referenceId
        : '');
    const businessReference = deriveBusinessReferenceFromMetadata(metadata)
      || (investmentLookupId ? String(investmentBusinessRefMap.get(investmentLookupId) || '').trim() : '');
    const nextMetadata = {
      ...metadata,
      businessReference: businessReference || '',
    };
    if (canonicalUserId !== originalUserId) {
      return {
        ...entry,
        userId: canonicalUserId,
        metadata: {
          ...nextMetadata,
          userIdRaw: originalUserId,
        },
      };
    }
    return {
      ...entry,
      metadata: nextMetadata,
    };
  });

  const userDisplayMap = await resolveUserDisplayData(normalizedEntries);
  return normalizedEntries.map((entry) => {
    const display = userDisplayMap.get(String(entry.userId || '').trim());
    if (!display) return entry;
    return {
      ...entry,
      metadata: {
        ...(entry.metadata || {}),
        userCustomerNumber: display.customerNumber,
        userUsername: display.username,
        userDisplayName: display.name,
      },
    };
  });
}

module.exports = {
  enrichLedgerRowsForReporting,
};
