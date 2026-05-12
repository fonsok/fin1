// ============================================================================
// Parse Cloud Code
// functions/wallet.js - Cash/Konto Functions (legacy file name)
// ============================================================================
//
// Konto-/Cash-Logik für Ein-/Auszahlungen und Saldo-Anzeige. Aktivierung
// über Konfiguration (display.walletFeatureEnabled). Ein zentraler Wrapper
// prüft das Feature-Flag; neue Konto-Funktionen nur noch über defineWallet
// registrieren.
//
// ============================================================================

'use strict';

const { loadConfig } = require('../utils/configHelper/index.js');

const WALLET_DISABLED_MESSAGE = 'Ein-/Auszahlungen sind derzeit deaktiviert. Kontostand und Transaktionshistorie bleiben verfügbar.';
const DEPOSIT_DISABLED_MESSAGE = 'Einzahlungen sind derzeit deaktiviert.';
const WITHDRAWAL_DISABLED_MESSAGE = 'Auszahlungen sind derzeit deaktiviert.';

function resolveWalletActionMode(config) {
  const mode = config?.display?.walletActionModeGlobal || config?.display?.walletActionMode;
  if (typeof mode === 'string') {
    return mode;
  }
  return config?.display?.walletFeatureEnabled === true ? 'deposit_and_withdrawal' : 'disabled';
}

function resolveRoleMode(config, role) {
  if (role === 'investor') {
    return config?.display?.walletActionModeInvestor || 'deposit_and_withdrawal';
  }
  if (role === 'trader') {
    return config?.display?.walletActionModeTrader || 'deposit_and_withdrawal';
  }
  return 'deposit_and_withdrawal';
}

function resolveAccountTypeMode(config, accountTypeRaw) {
  const accountType = String(accountTypeRaw || '').toLowerCase();
  if (accountType === 'company') {
    return config?.display?.walletActionModeCompany || 'deposit_and_withdrawal';
  }
  return config?.display?.walletActionModeIndividual || 'deposit_and_withdrawal';
}

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

async function resolveEffectiveWalletActionMode(config, requestUser) {
  const globalMode = resolveWalletActionMode(config);
  if (!requestUser?.id) return globalMode;
  const user = await new Parse.Query(Parse.User).get(requestUser.id, { useMasterKey: true });
  const roleMode = resolveRoleMode(config, user.get('role'));
  const accountTypeMode = resolveAccountTypeMode(config, user.get('accountType'));
  const userOverride = user.get('walletActionModeOverride');
  const globalPerm = modeToPermissions(globalMode);
  const rolePerm = modeToPermissions(roleMode);
  const accountTypePerm = modeToPermissions(accountTypeMode);
  const userPerm = modeToPermissions(
    typeof userOverride === 'string' && userOverride.length > 0
      ? userOverride
      : 'deposit_and_withdrawal',
  );
  return permissionsToMode({
    deposit: globalPerm.deposit && rolePerm.deposit && accountTypePerm.deposit && userPerm.deposit,
    withdrawal: globalPerm.withdrawal && rolePerm.withdrawal && accountTypePerm.withdrawal && userPerm.withdrawal,
  });
}

/**
 * Registriert eine Cloud Function, die nur ausgeführt wird, wenn das Konto-Feature
 * aktiv ist. Eine zentrale Stelle für die Feature-Prüfung – keine verstreuten Checks.
 */
function defineWalletRead(name, handler) {
  Parse.Cloud.define(name, async (request) => handler(request));
}

function defineWalletAction(name, actionType, handler) {
  Parse.Cloud.define(name, async (request) => {
    const config = await loadConfig();
    const mode = await resolveEffectiveWalletActionMode(config, request.user);
    if (mode === 'disabled') {
      throw new Parse.Error(Parse.Error.OPERATION_FORBIDDEN, WALLET_DISABLED_MESSAGE);
    }
    if (actionType === 'deposit' && mode === 'withdrawal_only') {
      throw new Parse.Error(Parse.Error.OPERATION_FORBIDDEN, DEPOSIT_DISABLED_MESSAGE);
    }
    if (actionType === 'withdrawal' && mode === 'deposit_only') {
      throw new Parse.Error(Parse.Error.OPERATION_FORBIDDEN, WITHDRAWAL_DISABLED_MESSAGE);
    }
    return handler(request);
  });
}

// --- Get wallet balance ---
defineWalletRead('getWalletBalance', async (request) => {
  const user = request.user;
  if (!user) throw new Parse.Error(Parse.Error.INVALID_SESSION_TOKEN, 'Login required');

  const query = new Parse.Query('WalletTransaction');
  query.equalTo('userId', user.id);
  query.equalTo('status', 'completed');
  query.descending('completedAt');
  query.limit(1);

  const lastTx = await query.first({ useMasterKey: true });

  return {
    balance: lastTx ? lastTx.get('balanceAfter') : 0,
    lastTransactionAt: lastTx ? lastTx.get('completedAt') : null
  };
});

// --- Get transaction history ---
defineWalletRead('getTransactionHistory', async (request) => {
  const user = request.user;
  if (!user) throw new Parse.Error(Parse.Error.INVALID_SESSION_TOKEN, 'Login required');

  const { limit = 50, skip = 0, type } = request.params;

  const query = new Parse.Query('WalletTransaction');
  query.equalTo('userId', user.id);
  query.descending('transactionDate');
  query.limit(limit);
  query.skip(skip);

  if (type) query.equalTo('transactionType', type);

  const transactions = await query.find({ useMasterKey: true });
  const total = await query.count({ useMasterKey: true });

  return {
    transactions: transactions.map(t => t.toJSON()),
    total,
    hasMore: skip + transactions.length < total
  };
});

// --- Request deposit (creates pending transaction) ---
defineWalletAction('requestDeposit', 'deposit', async (request) => {
  const user = request.user;
  if (!user) throw new Parse.Error(Parse.Error.INVALID_SESSION_TOKEN, 'Login required');

  const { amount } = request.params;

  if (!amount || amount < 10) {
    throw new Parse.Error(Parse.Error.INVALID_VALUE, 'Minimum deposit is €10');
  }
  if (amount > 100000) {
    throw new Parse.Error(Parse.Error.INVALID_VALUE, 'Maximum deposit is €100,000');
  }

  const WalletTransaction = Parse.Object.extend('WalletTransaction');
  const tx = new WalletTransaction();
  tx.set('userId', user.id);
  tx.set('transactionType', 'deposit');
  tx.set('amount', amount);
  tx.set('status', 'pending');
  tx.set('description', 'Einzahlung');

  await tx.save(null, { useMasterKey: true });

  return {
    transactionId: tx.id,
    transactionNumber: tx.get('transactionNumber'),
    status: 'pending'
  };
});

// --- Request withdrawal ---
defineWalletAction('requestWithdrawal', 'withdrawal', async (request) => {
  const user = request.user;
  if (!user) throw new Parse.Error(Parse.Error.INVALID_SESSION_TOKEN, 'Login required');

  const { amount, iban } = request.params;

  if (!amount || amount < 10) {
    throw new Parse.Error(Parse.Error.INVALID_VALUE, 'Minimum withdrawal is €10');
  }

  // Check balance
  const balanceResult = await Parse.Cloud.run('getWalletBalance', {}, { sessionToken: request.user.getSessionToken() });
  if (balanceResult.balance < amount) {
    throw new Parse.Error(Parse.Error.OPERATION_FORBIDDEN, 'Insufficient balance');
  }

  const WalletTransaction = Parse.Object.extend('WalletTransaction');
  const tx = new WalletTransaction();
  tx.set('userId', user.id);
  tx.set('transactionType', 'withdrawal');
  tx.set('amount', -amount);
  tx.set('status', 'pending');
  tx.set('description', 'Auszahlung');
  tx.set('metadata', { targetIban: iban });

  await tx.save(null, { useMasterKey: true });

  return {
    transactionId: tx.id,
    transactionNumber: tx.get('transactionNumber'),
    status: 'pending'
  };
});
