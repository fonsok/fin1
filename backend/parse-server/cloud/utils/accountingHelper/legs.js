'use strict';

const { calculateOrderFees } = require('../helpers');
const { round2 } = require('./shared');

// Phase A (2026-04-20): Align backend mirror-trade fee calculation with the iOS
// `FeeCalculationService` which currently always applies the Fremdkostenpauschale
// as a flat amount. The second arg to `calculateOrderFees` (`isForeign`) toggles
// that fixed surcharge. Flipping it to `true` here makes backend-legs and
// iOS-PDF numbers match 1:1.
//
// Phase B (TBD, ADR-008 placeholder): the real spec is that foreign costs depend
// on the security's Börsenplatz and order volume. Once we introduce a per-Order
// `feeProfile`/`exchange` field (source of truth for fee calculation), both
// backend `legs.js` and iOS `FeeCalculationService` must read the same profile
// from the Order/Security and compute fees off that, instead of the current
// flat-rate simplification. Until then, keep both sides on the same flat-rate
// assumption to guarantee SSOT parity between stored metadata and bill PDF.
const APPLY_FOREIGN_COSTS_PHASE_A = true;

function computeTotalFees(orderAmount, feeConfig = {}) {
  const fees = calculateOrderFees(orderAmount, APPLY_FOREIGN_COSTS_PHASE_A, feeConfig);
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
    ? calculateOrderFees(buyAmt, APPLY_FOREIGN_COSTS_PHASE_A, feeConfig)
    : { orderFee: 0, exchangeFee: 0, foreignCosts: 0, totalFees: 0 };
  let totalBuyCost = buyAmt + buyFees.totalFees;
  let residual = round2(investmentCapital - totalBuyCost);

  for (let iter = 0; iter < 100; iter++) {
    const nextQty = buyQty + 1;
    const nextAmt = nextQty * buyPrice;
    const nextFees = calculateOrderFees(nextAmt, APPLY_FOREIGN_COSTS_PHASE_A, feeConfig);
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
    ? calculateOrderFees(sellAmt, APPLY_FOREIGN_COSTS_PHASE_A, feeConfig)
    : { orderFee: 0, exchangeFee: 0, foreignCosts: 0, totalFees: 0 };
  return {
    quantity: sellQty,
    price: sellPrice,
    amount: sellAmt,
    fees: sellFees,
  };
}

/**
 * Derive the Investor Collection Bill's Gross Profit / Commission / Net Profit /
 * Return (%) from the mirror-trade legs. Single source of truth for everything
 * the investor sees on the bill — this is why the `metadata.*` fields and the
 * AccountStatement bookings are all computed off the same result. The legacy
 * `ownershipRatio × netTradingProfit` path only remains as a fallback when legs
 * are unavailable (e.g. missing trade prices).
 *
 * @param {object} buyLeg   — `{ amount, fees: { totalFees } }`
 * @param {object} sellLeg  — `{ amount, fees: { totalFees } }`
 * @param {number} commissionRate — e.g. 0.11
 * @returns {{
 *   totalBuyCost: number,
 *   netSellAmount: number,
 *   grossProfit: number,
 *   commission: number,
 *   netProfit: number,
 *   returnPercentage: number|null
 * }|null}
 */
function deriveMirrorTradeBasis(buyLeg, sellLeg, commissionRate) {
  if (!buyLeg || !sellLeg) return null;

  const totalBuyCost = round2(
    (buyLeg.amount || 0) + ((buyLeg.fees && buyLeg.fees.totalFees) || 0),
  );
  const netSellAmount = round2(
    (sellLeg.amount || 0) - ((sellLeg.fees && sellLeg.fees.totalFees) || 0),
  );
  const grossProfit = round2(netSellAmount - totalBuyCost);
  const commission = grossProfit > 0 ? round2(grossProfit * commissionRate) : 0;
  const netProfit = round2(grossProfit - commission);
  const returnPercentage = totalBuyCost > 0
    ? round2((netProfit / totalBuyCost) * 100)
    : null;

  return {
    totalBuyCost,
    netSellAmount,
    grossProfit,
    commission,
    netProfit,
    returnPercentage,
  };
}

module.exports = {
  computeInvestorBuyLeg,
  computeInvestorSellLeg,
  deriveMirrorTradeBasis,
};
