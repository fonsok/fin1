'use strict';

const { loadConfig } = require('../../utils/configHelper/index.js');
const { normalizeWalletActionMode } = require('./usersConstants');

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

async function loadAccountStatementAndWalletControls(user, formatDate) {
  const userStableId = `user:${user.get('email')}`;
  const stmtQuery = new Parse.Query('AccountStatement');
  stmtQuery.equalTo('userId', userStableId);
  stmtQuery.ascending('createdAt');
  stmtQuery.limit(100);
  const stmtEntries = await stmtQuery.find({ useMasterKey: true });

  const liveConfig = await loadConfig(true);
  const globalWalletMode =
    normalizeWalletActionMode(liveConfig.display?.walletActionModeGlobal || liveConfig.display?.walletActionMode) || 'disabled';
  const roleWalletMode =
    user.get('role') === 'investor'
      ? (normalizeWalletActionMode(liveConfig.display?.walletActionModeInvestor) || 'deposit_and_withdrawal')
      : user.get('role') === 'trader'
        ? (normalizeWalletActionMode(liveConfig.display?.walletActionModeTrader) || 'deposit_and_withdrawal')
        : 'deposit_and_withdrawal';
  const accountTypeWalletMode =
    String(user.get('accountType') || '').toLowerCase() === 'company'
      ? (normalizeWalletActionMode(liveConfig.display?.walletActionModeCompany) || 'deposit_and_withdrawal')
      : (normalizeWalletActionMode(liveConfig.display?.walletActionModeIndividual) || 'deposit_and_withdrawal');
  const userWalletActionModeOverride = normalizeWalletActionMode(user.get('walletActionModeOverride'));
  const initialBalance =
    typeof liveConfig.financial?.initialAccountBalance === 'number'
      ? liveConfig.financial.initialAccountBalance
      : 0.0;

  let runningBalance = initialBalance;
  const accountStatementEntries = stmtEntries.map(e => {
    const amount = e.get('amount') || 0;
    runningBalance += amount;
    return {
      objectId: e.id,
      entryType: e.get('entryType'),
      amount,
      balanceAfter: parseFloat(runningBalance.toFixed(2)),
      tradeId: e.get('tradeId'),
      tradeNumber: e.get('tradeNumber'),
      investmentId: e.get('investmentId'),
      description: e.get('description'),
      referenceDocumentId: e.get('referenceDocumentId') || null,
      source: e.get('source'),
      createdAt: formatDate(e.get('createdAt')),
    };
  });

  const totalCredits = stmtEntries.reduce((s, e) => {
    const a = e.get('amount') || 0;
    return a > 0 ? s + a : s;
  }, 0);
  const totalDebits = stmtEntries.reduce((s, e) => {
    const a = e.get('amount') || 0;
    return a < 0 ? s + Math.abs(a) : s;
  }, 0);

  const accountStatement = {
    initialBalance,
    closingBalance: parseFloat(runningBalance.toFixed(2)),
    totalCredits: parseFloat(totalCredits.toFixed(2)),
    totalDebits: parseFloat(totalDebits.toFixed(2)),
    netChange: parseFloat((totalCredits - totalDebits).toFixed(2)),
    entries: accountStatementEntries,
  };

  const globalPermissions = modeToPermissions(globalWalletMode);
  const rolePermissions = modeToPermissions(roleWalletMode);
  const accountTypePermissions = modeToPermissions(accountTypeWalletMode);
  const userPermissions = modeToPermissions(userWalletActionModeOverride || 'deposit_and_withdrawal');
  const effectiveWalletMode = permissionsToMode({
    deposit: globalPermissions.deposit && rolePermissions.deposit && accountTypePermissions.deposit && userPermissions.deposit,
    withdrawal: globalPermissions.withdrawal && rolePermissions.withdrawal && accountTypePermissions.withdrawal && userPermissions.withdrawal,
  });

  const walletControls = {
    globalMode: globalWalletMode,
    roleMode: roleWalletMode,
    accountTypeMode: accountTypeWalletMode,
    userOverrideMode: userWalletActionModeOverride,
    effectiveMode: effectiveWalletMode,
  };

  return {
    accountStatement,
    walletControls,
    userWalletActionModeOverride,
  };
}

module.exports = {
  loadAccountStatementAndWalletControls,
};
