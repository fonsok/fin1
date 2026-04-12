'use strict';

/**
 * Business customer number (e.g. ANL-2026-00001) on _User — canonical field: customerNumber.
 * Legacy field customerId on _User is migrated away in beforeSave.
 */
function readCustomerNumber(user) {
  if (!user || typeof user.get !== 'function') return '';
  return user.get('customerNumber') || user.get('customerId') || '';
}

/**
 * Ensure customerNumber is set and legacy customerId on _User is removed.
 */
function normalizeUserCustomerNumber(user) {
  if (!user || typeof user.get !== 'function') return;
  const num = user.get('customerNumber') || user.get('customerId');
  if (num) {
    user.set('customerNumber', num);
  }
  if (user.get('customerId') !== undefined) {
    user.unset('customerId');
  }
}

/** Cloud function params: canonical userId (Parse _User.objectId); customerId accepted as legacy alias. */
function resolveEndUserObjectId(params) {
  if (!params || typeof params !== 'object') return undefined;
  return params.userId || params.customerId;
}

module.exports = {
  readCustomerNumber,
  normalizeUserCustomerNumber,
  resolveEndUserObjectId,
};
