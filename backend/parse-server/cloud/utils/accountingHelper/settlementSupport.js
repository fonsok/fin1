'use strict';

const { round2 } = require('./shared');

async function createCommissionRecord(traderId, investment, trade, participation, amount) {
  const Commission = Parse.Object.extend('Commission');
  const commission = new Commission();

  const lastComm = await new Parse.Query('Commission')
    .startsWith('commissionNumber', `COM-${new Date().getFullYear()}-`)
    .descending('commissionNumber')
    .first({ useMasterKey: true });

  let seq = 1;
  if (lastComm) {
    const parts = lastComm.get('commissionNumber').split('-');
    seq = parseInt(parts[2], 10) + 1;
  }

  commission.set('commissionNumber', `COM-${new Date().getFullYear()}-${seq.toString().padStart(7, '0')}`);
  commission.set('traderId', traderId);
  commission.set('investorId', investment.get('investorId'));
  commission.set('investmentId', investment.id);
  commission.set('tradeId', trade.id);
  commission.set('participationId', participation.id);
  commission.set('investorGrossProfit', participation.get('profitShare'));
  commission.set('commissionRate', participation.get('commissionRate'));
  commission.set('commissionAmount', amount);
  commission.set('status', 'pending');

  await commission.save(null, { useMasterKey: true });
  console.log(`  📄 Commission ${commission.get('commissionNumber')}: €${round2(amount)} for trade #${trade.get('tradeNumber')}`);
}

async function createNotification(userId, type, category, title, message) {
  const Notification = Parse.Object.extend('Notification');
  const notif = new Notification();
  notif.set('userId', userId);
  notif.set('type', type);
  notif.set('category', category);
  notif.set('title', title);
  notif.set('message', message);
  notif.set('isRead', false);
  notif.set('channels', ['in_app', 'push']);
  await notif.save(null, { useMasterKey: true });
}

function formatCurrency(amount) {
  return new Intl.NumberFormat('de-DE', { style: 'currency', currency: 'EUR' }).format(amount);
}

module.exports = {
  createCommissionRecord,
  createNotification,
  formatCurrency,
};
