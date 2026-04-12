'use strict';

const { calculateOrderFees } = require('../helpers');
const { round2 } = require('./shared');

function computeTotalFees(orderAmount, feeConfig = {}) {
  const fees = calculateOrderFees(orderAmount, false, feeConfig);
  return fees.totalFees;
}

function solveForBuyAmount(investmentCapital, feeConfig, tolerance = 0.01) {
  let low = 0;
  let high = investmentCapital;
  let result = 0;

  for (let i = 0; i < 100; i++) {
    const mid = (low + high) / 2;
    const fees = computeTotalFees(mid, feeConfig);
    const totalCost = mid + fees;

    if (Math.abs(totalCost - investmentCapital) < tolerance) {
      result = mid;
      break;
    }
    if (totalCost < investmentCapital) {
      result = mid;
      low = mid;
    } else {
      high = mid;
    }
  }

  const finalFees = computeTotalFees(result, feeConfig);
  if (result + finalFees > investmentCapital) {
    result *= 0.99;
  }
  return result;
}

function computeInvestorBuyLeg(investmentCapital, buyPrice, feeConfig) {
  const solvedBuyAmount = solveForBuyAmount(investmentCapital, feeConfig);
  let buyQty = Math.floor(solvedBuyAmount / buyPrice);
  let buyAmt = round2(buyQty * buyPrice);
  let buyFees = buyAmt > 0
    ? calculateOrderFees(buyAmt, false, feeConfig)
    : { orderFee: 0, exchangeFee: 0, foreignCosts: 0, totalFees: 0 };
  let totalBuyCost = buyAmt + buyFees.totalFees;
  let residual = round2(investmentCapital - totalBuyCost);

  for (let iter = 0; iter < 100; iter++) {
    const nextQty = buyQty + 1;
    const nextAmt = nextQty * buyPrice;
    const nextFees = calculateOrderFees(nextAmt, false, feeConfig);
    const nextTotalCost = nextAmt + nextFees.totalFees;

    if (nextTotalCost <= investmentCapital) {
      buyQty = nextQty;
      buyAmt = round2(nextAmt);
      buyFees = nextFees;
      totalBuyCost = nextTotalCost;
      residual = round2(investmentCapital - totalBuyCost);
    } else {
      break;
    }
  }

  return {
    quantity: buyQty,
    price: buyPrice,
    amount: buyAmt,
    fees: buyFees,
    residualAmount: Math.max(0, residual),
  };
}

function computeInvestorSellLeg(buyQuantity, sellPrice, sellPercentage, feeConfig) {
  const sellQty = Math.floor(buyQuantity * sellPercentage);
  const sellAmt = round2(sellQty * sellPrice);
  const sellFees = sellAmt > 0
    ? calculateOrderFees(sellAmt, false, feeConfig)
    : { orderFee: 0, exchangeFee: 0, foreignCosts: 0, totalFees: 0 };
  return {
    quantity: sellQty,
    price: sellPrice,
    amount: sellAmt,
    fees: sellFees,
  };
}

module.exports = {
  computeInvestorBuyLeg,
  computeInvestorSellLeg,
};
