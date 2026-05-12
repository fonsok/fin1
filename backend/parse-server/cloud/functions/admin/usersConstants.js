'use strict';

const PROTECTED_ADMIN_ROLES = ['admin', 'business_admin', 'security_officer', 'compliance'];
const DEACTIVATING_STATUSES = ['suspended', 'locked', 'inactive', 'disabled'];
const USER_WALLET_ACTION_MODES = new Set(['disabled', 'deposit_only', 'withdrawal_only', 'deposit_and_withdrawal']);

function normalizeWalletActionMode(rawMode) {
  if (typeof rawMode === 'string' && USER_WALLET_ACTION_MODES.has(rawMode)) {
    return rawMode;
  }
  return null;
}

module.exports = {
  PROTECTED_ADMIN_ROLES,
  DEACTIVATING_STATUSES,
  USER_WALLET_ACTION_MODES,
  normalizeWalletActionMode,
};
