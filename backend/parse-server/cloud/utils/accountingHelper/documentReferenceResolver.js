'use strict';

/**
 * Canonical resolver for GoB document references used by financial bookings.
 * Always returns the tuple required by booking writers:
 *   - referenceDocumentId
 *   - referenceDocumentNumber
 */
function resolveDocumentReference(document, options = {}) {
  const {
    required = true,
    context = 'unknown',
  } = options;

  if (!document) {
    if (required) {
      throw new Error(`GoB violation blocked: missing document object (context=${context})`);
    }
    return { referenceDocumentId: '', referenceDocumentNumber: '' };
  }

  const referenceDocumentId = String(document.id || '').trim();
  const referenceDocumentNumber = String(
    typeof document.get === 'function'
      ? (document.get('accountingDocumentNumber') || '')
      : (document.accountingDocumentNumber || '')
  ).trim();

  if (required && (!referenceDocumentId || !referenceDocumentNumber)) {
    throw new Error(
      `GoB violation blocked: unresolved document reference (context=${context}, id=${referenceDocumentId || 'n/a'}, number=${referenceDocumentNumber || 'n/a'})`
    );
  }

  return { referenceDocumentId, referenceDocumentNumber };
}

module.exports = {
  resolveDocumentReference,
};
