'use strict';

const { loadConfig } = require('../../../utils/configHelper/index.js');
const { normalizeWalletActionMode } = require('../usersConstants');

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

function buildWalletControlsForUser(user, liveConfig) {
  const role = String(user.get('role') || '').toLowerCase();
  const isInvestor = role === 'investor';
  const isTrader = role === 'trader';

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

  return {
    walletControls: {
      globalMode: globalWalletMode,
      roleMode: roleWalletMode,
      accountTypeMode: accountTypeWalletMode,
      userOverrideMode: userWalletActionModeOverride,
      effectiveMode: effectiveWalletMode,
    },
    userWalletActionModeOverride,
  };
}

module.exports = {
  modeToPermissions,
  permissionsToMode,
  buildWalletControlsForUser,
};
