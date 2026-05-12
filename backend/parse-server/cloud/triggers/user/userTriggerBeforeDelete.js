'use strict';

async function userBeforeDelete(request) {
  const user = request.object;

  const Investment = Parse.Object.extend('Investment');
  const investmentQuery = new Parse.Query(Investment);
  investmentQuery.equalTo('investorId', user.id);
  investmentQuery.containedIn('status', ['active', 'executing']);
  const activeInvestments = await investmentQuery.count({ useMasterKey: true });

  if (activeInvestments > 0) {
    throw new Parse.Error(Parse.Error.OPERATION_FORBIDDEN,
      'Cannot delete user with active investments');
  }

  if (user.get('role') === 'trader') {
    const Trade = Parse.Object.extend('Trade');
    const tradeQuery = new Parse.Query(Trade);
    tradeQuery.equalTo('traderId', user.id);
    tradeQuery.containedIn('status', ['pending', 'active', 'partial']);
    const activeTrades = await tradeQuery.count({ useMasterKey: true });

    if (activeTrades > 0) {
      throw new Parse.Error(Parse.Error.OPERATION_FORBIDDEN,
        'Cannot delete user with active trades');
    }
  }

  const WalletTransaction = Parse.Object.extend('WalletTransaction');
  const txQuery = new Parse.Query(WalletTransaction);
  txQuery.equalTo('userId', user.id);
  txQuery.containedIn('status', ['pending', 'processing']);
  const pendingTx = await txQuery.count({ useMasterKey: true });

  if (pendingTx > 0) {
    throw new Parse.Error(Parse.Error.OPERATION_FORBIDDEN,
      'Cannot delete user with pending transactions');
  }
}

module.exports = {
  userBeforeDelete,
};
