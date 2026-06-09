'use strict';

const { DEFAULT_CONFIG } = require('../configHelper/defaultConfig');

function pickFeeValue(feeConfig, key) {
  const D = DEFAULT_CONFIG.financial || {};
  const v = feeConfig && Object.prototype.hasOwnProperty.call(feeConfig, key)
    ? feeConfig[key]
    : undefined;
  return (v === null || v === undefined) ? D[key] : v;
}

function mongoRound2(expr) {
  return { $divide: [{ $round: [{ $multiply: [expr, 100] }, 0] }, 100] };
}

function mongoClamp(expr, min, max) {
  return { $min: [max, { $max: [min, expr] }] };
}

/** Spiegelt calculateOrderFees (isForeign=true) für Trade-Aggregationen. */
function buildOrderFeesTotalMongoExpr(amountExpr, feeConfig = {}) {
  const orderFee = mongoRound2(
    mongoClamp(
      { $multiply: [amountExpr, pickFeeValue(feeConfig, 'orderFeeRate')] },
      pickFeeValue(feeConfig, 'orderFeeMin'),
      pickFeeValue(feeConfig, 'orderFeeMax'),
    ),
  );
  const exchangeFee = mongoRound2(
    mongoClamp(
      { $multiply: [amountExpr, pickFeeValue(feeConfig, 'exchangeFeeRate')] },
      pickFeeValue(feeConfig, 'exchangeFeeMin'),
      pickFeeValue(feeConfig, 'exchangeFeeMax'),
    ),
  );
  const foreign = pickFeeValue(feeConfig, 'foreignCosts');
  return mongoRound2({ $add: [orderFee, exchangeFee, foreign] });
}

function buildTradeBuyGrossMongoExpr() {
  return { $ifNull: ['$buyOrder.totalAmount', { $ifNull: ['$buyAmount', 0] }] };
}

function buildTradeSellGrossMongoExpr() {
  const fromOrders = {
    $reduce: {
      input: { $ifNull: ['$sellOrders', []] },
      initialValue: 0,
      in: { $add: ['$$value', { $ifNull: ['$$this.totalAmount', 0] }] },
    },
  };
  return {
    $cond: {
      if: { $gt: [{ $size: { $ifNull: ['$sellOrders', []] } }, 0] },
      then: fromOrders,
      else: { $ifNull: ['$sellOrder.totalAmount', { $ifNull: ['$sellAmount', 0] }] },
    },
  };
}

function buildTradeSoldQuantityMongoExpr() {
  const fromField = { $ifNull: ['$soldQuantity', 0] };
  const fromOrders = {
    $reduce: {
      input: { $ifNull: ['$sellOrders', []] },
      initialValue: 0,
      in: { $add: ['$$value', { $ifNull: ['$$this.quantity', 0] }] },
    },
  };
  return {
    $cond: {
      if: { $gt: [fromField, 0] },
      then: fromField,
      else: fromOrders,
    },
  };
}

function buildTradeTotalBuyCostMongoExpr(feeConfig = {}) {
  const gross = buildTradeBuyGrossMongoExpr();
  const fees = buildOrderFeesTotalMongoExpr(gross, feeConfig);
  return mongoRound2({ $add: [gross, fees] });
}

/**
 * Mongo-Pendant zu resolveLegProfitFromMetrics (Einstand-Basis).
 */
function buildTradeLegProfitMongoExpr(feeConfig = {}) {
  const totalBuyCost = buildTradeTotalBuyCostMongoExpr(feeConfig);
  const buyGross = buildTradeBuyGrossMongoExpr();
  const sellGross = buildTradeSellGrossMongoExpr();
  const qty = { $ifNull: ['$quantity', { $ifNull: ['$buyOrder.quantity', 0] }] };
  const soldQty = buildTradeSoldQuantityMongoExpr();
  const displayBasis = mongoRound2({
    $cond: {
      if: { $gt: [qty, 0] },
      then: { $divide: [totalBuyCost, qty] },
      else: 0,
    },
  });
  const sellFees = buildOrderFeesTotalMongoExpr(sellGross, feeConfig);
  const netSell = mongoRound2({ $subtract: [sellGross, sellFees] });
  const soldCost = mongoRound2({ $multiply: [soldQty, displayBasis] });

  return {
    $cond: {
      if: { $and: [{ $gt: [soldQty, 0] }, { $gt: [displayBasis, 0] }] },
      then: mongoRound2({ $subtract: [netSell, soldCost] }),
      else: {
        $cond: {
          if: { $and: [{ $lte: [soldQty, 0] }, { $gt: [totalBuyCost, 0] }] },
          then: mongoRound2({ $multiply: [-1, totalBuyCost] }),
          else: mongoRound2({ $subtract: [sellGross, buyGross] }),
        },
      },
    },
  };
}

function buildTradeLegReturnPercentageMongoExpr(feeConfig = {}) {
  const totalBuyCost = buildTradeTotalBuyCostMongoExpr(feeConfig);
  const profit = buildTradeLegProfitMongoExpr(feeConfig);
  return {
    $cond: {
      if: { $gt: [totalBuyCost, 0] },
      then: {
        $divide: [
          { $round: [{ $multiply: [{ $divide: [profit, totalBuyCost] }, 10000] }, 0] },
          100,
        ],
      },
      else: 0,
    },
  };
}

module.exports = {
  buildOrderFeesTotalMongoExpr,
  buildTradeBuyGrossMongoExpr,
  buildTradeSellGrossMongoExpr,
  buildTradeSoldQuantityMongoExpr,
  buildTradeTotalBuyCostMongoExpr,
  buildTradeLegProfitMongoExpr,
  buildTradeLegReturnPercentageMongoExpr,
};
