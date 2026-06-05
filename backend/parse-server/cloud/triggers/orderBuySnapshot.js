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
  const sym = String(order.get('symbol') || order.get('wkn') || '').trim();
  const traderId = String(order.get('traderId') || '').trim();
  const description = String(order.get('description') || order.get('securityName') || sym).trim();
  const createdAt = order.createdAt instanceof Date ? order.createdAt.toISOString() : new Date().toISOString();
  const updatedAt = order.updatedAt instanceof Date ? order.updatedAt.toISOString() : createdAt;
  const executedAt = order.get('executedAt') instanceof Date
    ? order.get('executedAt').toISOString()
    : createdAt;

  return {
    objectId: order.id,
    id: order.id,
    traderId,
    symbol: sym,
    description: description || sym,
    quantity: qty,
    price,
    totalAmount: totalAmount > 0 ? totalAmount : gross,
    status: String(order.get('status') || 'executed'),
    createdAt,
    updatedAt,
    executedAt,
    wkn: order.get('wkn') || sym,
    optionDirection: order.get('optionDirection') || null,
    underlyingAsset: order.get('underlyingAsset') || null,
    isMirrorPoolOrder: order.get('isMirrorPoolOrder') === true,
    legType: order.get('legType') || null,
  };
}

module.exports = {
  buildBuyOrderSnapshotFromOrder,
};
