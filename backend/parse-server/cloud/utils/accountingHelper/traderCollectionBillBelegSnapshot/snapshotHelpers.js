'use strict';

const { round2 } = require('../shared');
const { TOLERANCE } = require('./shared');

function formatInstrumentLine(instrument) {
  const parts = [];
  if (instrument.wknOrIsin) parts.push(instrument.wknOrIsin);
  if (instrument.securitiesDirection) parts.push(instrument.securitiesDirection);
  if (instrument.underlyingAsset) parts.push(instrument.underlyingAsset);
  if (instrument.strikePrice) parts.push(`${instrument.strikePrice} Pkt.`);
  if (instrument.issuer) parts.push(instrument.issuer);
  return parts.join(' - ');
}

function orderLikeFromOrder(order, trade, executionType) {
  if (order && typeof order.get === 'function') {
    return {
      executedAt: order.get('executedAt') || order.get('createdAt'),
      createdAt: order.get('createdAt'),
      exchange: order.get('exchange'),
      quantity: order.get('executedQuantity') || order.get('quantity'),
      price: order.get('price'),
      wkn: order.get('wkn'),
      id: order.id,
    };
  }
  const embedded = executionType === 'sell'
    ? (trade.get('sellOrder') || (trade.get('sellOrders') || [])[0] || trade.get('buyOrder') || {})
    : (trade.get('buyOrder') || {});
  return Object.assign({}, embedded, order || {});
}

function assertTotalWithFees(executionType, grossAmount, fees, totalWithFees, context) {
  const expected = executionType === 'buy'
    ? round2(grossAmount + (fees.totalFees || 0))
    : round2(Math.max(0, grossAmount - (fees.totalFees || 0)));
  if (Math.abs(round2(totalWithFees) - expected) > TOLERANCE) {
    throw new Error(
      `Trader collection bill invariant totalWithFees: ${totalWithFees} ≠ ${expected} `
      + JSON.stringify(context),
    );
  }
}

module.exports = {
  formatInstrumentLine,
  orderLikeFromOrder,
  assertTotalWithFees,
};
