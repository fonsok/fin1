'use strict';

/**
 * GoB: Collection Bill (Beleg) = SSOT for settlement booking amounts.
 * One canonical snapshot per bill; invariants enforced fail-closed before persist.
 */

const { round2, TOLERANCE_CENTS } = require('./shared');
const {
  euroToCents,
  withinCentsTolerance,
} = require('./moneyCents');
const { finalizeInvestorBelegMetadata } = require('./belegMetadataMoney');
const {
  deriveMirrorTradeBasis,
  computeCollectionBillTransferAmount,
} = require('./legs');
const {
  enrichBuyLegWithPriceMetrics,
  enrichSellLegWithPriceMetrics,
} = require('./legPriceMetrics');

const TOLERANCE = TOLERANCE_CENTS / 100;

function assertNear(label, actual, expected, context = {}) {
  if (!Number.isFinite(actual) || !Number.isFinite(expected)) {
    throw new Error(
      `Collection bill invariant "${label}": non-finite actual=${actual} expected=${expected} `
      + JSON.stringify(context),
    );
  }
  if (!withinCentsTolerance(euroToCents(actual), euroToCents(expected), TOLERANCE_CENTS)) {
    throw new Error(
      `Collection bill invariant "${label}": ${round2(actual)} ≠ ${round2(expected)} `
      + JSON.stringify(context),
    );
  }
}

/**
 * Builds canonical metadata + booking amounts from computed legs (single pass).
 * @returns {{
 *   metadata: object,
 *   booking: {
 *     investmentNominal: number,
 *     totalBuyCost: number,
 *     residualAmount: number,
 *     poolTradingAmount: number,
 *     netSellAmount: number,
 *     grossProfit: number,
 *     commission: number,
 *     netProfit: number,
 *     transferAmount: number,
 *   }
 * }}
 */
function buildCollectionBillBelegSnapshot({
  investmentCapital,
  ownershipPercentage,
  commissionRate,
  traderCommissionRate,
  appCommissionRate,
  buyLeg,
  sellLeg,
  taxBreakdown,
  grossProfit,
  commission,
  traderCommission,
  appCommission,
  netProfit,
  returnPercentage,
}) {
  if (!buyLeg || !sellLeg) {
    throw new Error('Collection bill snapshot requires buyLeg and sellLeg (GoB fail-closed)');
  }

  const mirror = deriveMirrorTradeBasis(buyLeg, sellLeg, commissionRate);
  if (!mirror) {
    throw new Error('Collection bill snapshot: deriveMirrorTradeBasis returned null');
  }

  const investmentNominal = round2(investmentCapital);
  const residualAmount = round2(Math.max(0, buyLeg.residualAmount || 0));
  const totalBuyCost = round2(investmentNominal - residualAmount);
  const poolTradingAmount = totalBuyCost;

  const legBuyCost = round2((buyLeg.amount || 0) + ((buyLeg.fees && buyLeg.fees.totalFees) || 0));
  if (!withinCentsTolerance(
    euroToCents(legBuyCost),
    euroToCents(totalBuyCost),
    TOLERANCE_CENTS,
  )) {
    console.warn(
      `⚠️ Collection bill: buyLeg line sum €${legBuyCost} ≠ booked totalBuyCost €${totalBuyCost} `
      + `(nominal €${investmentNominal} − residual €${residualAmount}); Beleg uses booked totals`,
    );
  }

  const bookedGross = round2(grossProfit ?? mirror.grossProfit);
  const bookedComm = round2(commission ?? mirror.commission);
  const bookedNet = round2(netProfit ?? mirror.netProfit);
  const netSellAmount = round2(mirror.netSellAmount);
  const transferAmount = computeCollectionBillTransferAmount({
    netSellAmount,
    commission: bookedComm,
  });

  if (transferAmount == null) {
    throw new Error('Collection bill snapshot: transferAmount could not be derived');
  }

  const context = {
    investmentCapital: investmentNominal,
    residualAmount,
    totalBuyCost,
    netSellAmount,
    transferAmount,
  };

  assertNear('nominal = totalBuyCost + residual', investmentNominal, totalBuyCost + residualAmount, context);
  assertNear('grossProfit', bookedGross, netSellAmount - totalBuyCost, context);
  assertNear('netProfit', bookedNet, bookedGross - bookedComm, context);
  assertNear('transferAmount', transferAmount, netSellAmount - bookedComm, context);

  const normalizedBuyLeg = enrichBuyLegWithPriceMetrics(Object.assign({}, buyLeg, {
    residualAmount,
    bookedTotalBuyCost: totalBuyCost,
  }));
  const normalizedSellLeg = enrichSellLegWithPriceMetrics(sellLeg);

  const metadata = finalizeInvestorBelegMetadata({
    ownershipPercentage: round2(ownershipPercentage),
    investmentNominal,
    grossProfit: bookedGross,
    commission: bookedComm,
    netProfit: bookedNet,
    transferAmount,
    totalBuyCost,
    netSellAmount,
    residualAmount,
    poolTradingAmount,
    returnPercentage,
    commissionRate,
    traderCommissionRateSnapshot: traderCommissionRate ?? null,
    appCommissionRateSnapshot: appCommissionRate ?? null,
    traderCommission: Number.isFinite(traderCommission) ? round2(traderCommission) : null,
    appCommission: Number.isFinite(appCommission) ? round2(appCommission) : null,
    buyLeg: normalizedBuyLeg,
    sellLeg: normalizedSellLeg || null,
    taxBreakdown: taxBreakdown || null,
    belegSchemaVersion: 2,
    generatedAt: new Date().toISOString(),
  }, {
    investmentCapital: investmentNominal,
    ownershipPercentage,
  });

  return {
    metadata,
    booking: {
      investmentNominal,
      totalBuyCost,
      residualAmount,
      poolTradingAmount,
      netSellAmount,
      grossProfit: bookedGross,
      commission: bookedComm,
      netProfit: bookedNet,
      transferAmount,
    },
  };
}

module.exports = {
  buildCollectionBillBelegSnapshot,
  TOLERANCE,
};
