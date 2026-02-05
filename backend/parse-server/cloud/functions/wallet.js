// ============================================================================
// Parse Cloud Code
// functions/wallet.js - Wallet Functions
// ============================================================================

'use strict';

// Get wallet balance
Parse.Cloud.define('getWalletBalance', async (request) => {
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

// Get transaction history
Parse.Cloud.define('getTransactionHistory', async (request) => {
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

// Request deposit (creates pending transaction)
Parse.Cloud.define('requestDeposit', async (request) => {
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

// Request withdrawal
Parse.Cloud.define('requestWithdrawal', async (request) => {
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
