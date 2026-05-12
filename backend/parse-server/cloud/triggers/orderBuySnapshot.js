'use strict';

/**
 * Embedded buyOrder on Trade — used by settleAndDistribute / trade_buy Belege
 * (fees from totalAmount). New trades from this trigger only had buyAmount before.
 */
function buildBuyOrderSnapshotFromOrder(order) {
  const qty = Number(order.get('executedQuantity') || order.get('quantity') || 0);
  const price = Number(order.get('price') || 0);
  const gross = Number(order.get('grossAmount') || 0);
  const totalAmount = Number(order.get('totalAmount') || 0) || (qty > 0 && price > 0 ? qty * price : gross);
  const sym = order.get('symbol') || order.get('wkn') || '';
  return {
    objectId: order.id,
    quantity: qty,
    price,
    totalAmount: totalAmount > 0 ? totalAmount : gross,
    symbol: sym,
    wkn: order.get('wkn') || sym,
  };
}

module.exports = {
  buildBuyOrderSnapshotFromOrder,
};
