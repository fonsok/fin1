'use strict';

const { round2 } = require('./shared');

async function bookAccountStatementEntry({
  userId,
  entryType,
  amount,
  tradeId,
  tradeNumber,
  investmentId,
  description,
  referenceDocumentId,
}) {
  const AccountStatement = Parse.Object.extend('AccountStatement');

  const lastEntry = await new Parse.Query('AccountStatement')
    .equalTo('userId', userId)
    .descending('createdAt')
    .first({ useMasterKey: true });

  const balanceBefore = lastEntry ? (lastEntry.get('balanceAfter') || 0) : 0;
  const balanceAfter = balanceBefore + amount;

  const entry = new AccountStatement();
  entry.set('userId', userId);
  entry.set('entryType', entryType);
  entry.set('amount', amount);
  entry.set('balanceBefore', round2(balanceBefore));
  entry.set('balanceAfter', round2(balanceAfter));
  entry.set('tradeId', tradeId);
  entry.set('tradeNumber', tradeNumber);
  if (investmentId) entry.set('investmentId', investmentId);
  entry.set('description', description);
  if (referenceDocumentId) entry.set('referenceDocumentId', referenceDocumentId);
  entry.set('source', 'backend');

  await entry.save(null, { useMasterKey: true });
  return entry;
}

module.exports = {
  bookAccountStatementEntry,
};
