'use strict';

function investmentAggPipeline(match) {
  const stages = [];
  if (match && Object.keys(match).length > 0) {
    stages.push({ $match: match });
  }
  stages.push({
    $addFields: {
      effCurrent: { $ifNull: ['$currentValue', '$amount'] },
      rowGross: {
        $subtract: [{ $ifNull: ['$currentValue', '$amount'] }, { $ifNull: ['$amount', 0] }],
      },
    },
  });
  stages.push({
    $group: {
      _id: null,
      totalInvestedAmount: { $sum: { $ifNull: ['$amount', 0] } },
      totalCurrentValue: { $sum: '$effCurrent' },
      totalGrossProfit: { $sum: '$rowGross' },
      positiveGrossSum: {
        $sum: { $cond: [{ $gt: ['$rowGross', 0] }, '$rowGross', 0] },
      },
    },
  });
  return stages;
}

function tradeAggPipeline(match) {
  const stages = [];
  if (match && Object.keys(match).length > 0) {
    stages.push({ $match: match });
  }
  stages.push({
    $addFields: {
      buyAmt: { $ifNull: ['$buyOrder.totalAmount', 0] },
      sellSingle: { $ifNull: ['$sellOrder.totalAmount', 0] },
      sellFromArray: {
        $reduce: {
          input: { $ifNull: ['$sellOrders', []] },
          initialValue: 0,
          in: { $add: ['$$value', { $ifNull: ['$$this.totalAmount', 0] }] },
        },
      },
    },
  });
  stages.push({
    $addFields: {
      sellAmt: {
        $cond: [
          { $gt: [{ $size: { $ifNull: ['$sellOrders', []] } }, 0] },
          '$sellFromArray',
          '$sellSingle',
        ],
      },
    },
  });
  stages.push({
    $addFields: {
      rowProfit: {
        $ifNull: [
          '$calculatedProfit',
          { $ifNull: ['$grossProfit', { $subtract: ['$sellAmt', '$buyAmt'] }] },
        ],
      },
      rowVolume: { $max: ['$buyAmt', '$sellAmt'] },
    },
  });
  stages.push({
    $group: {
      _id: null,
      totalTradeProfit: { $sum: '$rowProfit' },
      totalTradeVolume: { $sum: '$rowVolume' },
    },
  });
  return stages;
}

function firstAggRow(rows) {
  if (!Array.isArray(rows) || rows.length === 0) return {};
  return rows[0] || {};
}

module.exports = {
  investmentAggPipeline,
  tradeAggPipeline,
  firstAggRow,
};
