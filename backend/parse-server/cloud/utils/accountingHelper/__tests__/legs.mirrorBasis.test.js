'use strict';

// Regression fixture for the SSOT-via-mirror-trade refactor (2026-04-20).
//
// Context: In the live scenario
//   Pool: 5.000 € (mfischer 1.000 € / smüller 4.000 €, 20 % / 80 % ownership).
//   buyPrice 3,01 €, sellPrice 5,00 €, commission rate 11 %.
// the investor Collection Bill showed mirror-trade line items (329 / 1.320 shares,
// gross 636,85 € / 2.559,88 €, commission 70,05 € / 281,59 €) while the DB
// `metadata.grossProfit/commission/netProfit/returnPercentage` stored the
// trader-trade split (387,79 € / 42,66 € / 345,13 € / 34,51 %). The trader's
// AccountStatement therefore disagreed with the Gutschrift PDF (213,28 € vs.
// 351,64 €) and the investor's Return (%) in the app disagreed with the bill.
//
// `deriveMirrorTradeBasis` is the pure helper that turns mirror-trade legs into
// the canonical profit / commission / net profit / return-percentage tuple.
// `settleParticipation` now uses this for `PoolTradeParticipation.profitShare`,
// the Collection Bill `metadata.*`, and the `investment_return` /
// `commission_debit` AccountStatement amounts — so bills, DB and trader
// commission credit are guaranteed to line up.

const { calculateOrderFees } = require('../../helpers');
const {
  computeInvestorBuyLeg,
  computeInvestorSellLeg,
  deriveMirrorTradeBasis,
} = require('../legs');

const COMMISSION_RATE = 0.11;

function round2(n) {
  return Math.round(n * 100) / 100;
}

describe('deriveMirrorTradeBasis — pool mirror-trade SSOT', () => {
  test('mfischer bill fixture (329 shares @ 3,01 €): matches stored metadata values', () => {
    // These are the legs as they appear on the Investor Collection Bill PDF for
    // mfischer (20 % pool share, 1.000 € invested) — the ground truth the app
    // and the DB must now agree with.
    const buyLeg = { amount: 990.29, fees: { totalFees: 7.50 } };
    const sellLeg = { amount: 1645.00, fees: { totalFees: 8.66 } };

    const basis = deriveMirrorTradeBasis(buyLeg, sellLeg, COMMISSION_RATE);

    expect(basis.totalBuyCost).toBeCloseTo(997.79, 2);
    expect(basis.netSellAmount).toBeCloseTo(1636.34, 2);
    expect(basis.grossProfit).toBeCloseTo(638.55, 1);
    expect(basis.commission).toBeCloseTo(round2(basis.grossProfit * COMMISSION_RATE), 2);
    expect(basis.netProfit).toBeCloseTo(round2(basis.grossProfit - basis.commission), 2);
    // ROI2 ≈ (netProfit / totalBuyCost) × 100 ≈ 56.9 %
    expect(basis.returnPercentage).toBeGreaterThan(55);
    expect(basis.returnPercentage).toBeLessThan(58);
  });

  test('smüller bill fixture (1.320 shares @ 3,01 €): 80 % pool share scales proportionally', () => {
    const buyLeg = { amount: 3973.20, fees: { totalFees: 25.34 } };
    const sellLeg = { amount: 6600.00, fees: { totalFees: 34.70 } };

    const basis = deriveMirrorTradeBasis(buyLeg, sellLeg, COMMISSION_RATE);

    expect(basis.totalBuyCost).toBeCloseTo(3998.54, 2);
    expect(basis.grossProfit).toBeGreaterThan(2500);
    expect(basis.commission).toBeCloseTo(round2(basis.grossProfit * COMMISSION_RATE), 2);
    expect(basis.netProfit).toBeCloseTo(round2(basis.grossProfit - basis.commission), 2);

    // Both shares must yield a similar ROI2 (≈ same price & fee structure).
    const mfischer = deriveMirrorTradeBasis(
      { amount: 990.29, fees: { totalFees: 7.50 } },
      { amount: 1645.00, fees: { totalFees: 8.66 } },
      COMMISSION_RATE,
    );
    expect(Math.abs(basis.returnPercentage - mfischer.returnPercentage)).toBeLessThan(1.0);
  });

  test('commission preserved: grossProfit × commissionRate = commission', () => {
    const buyLeg = { amount: 990.29, fees: { totalFees: 7.50 } };
    const sellLeg = { amount: 1645.00, fees: { totalFees: 8.66 } };
    const basis = deriveMirrorTradeBasis(buyLeg, sellLeg, COMMISSION_RATE);

    expect(basis.commission).toBeCloseTo(round2(basis.grossProfit * COMMISSION_RATE), 2);
    expect(basis.netProfit).toBeCloseTo(round2(basis.grossProfit - basis.commission), 2);
  });

  test('loss trade: commission is zero when gross profit ≤ 0', () => {
    const buyLeg = { amount: 1000, fees: { totalFees: 10 } };
    const sellLeg = { amount: 800, fees: { totalFees: 8 } };
    const basis = deriveMirrorTradeBasis(buyLeg, sellLeg, COMMISSION_RATE);

    expect(basis.grossProfit).toBeLessThan(0);
    expect(basis.commission).toBe(0);
    expect(basis.netProfit).toBe(basis.grossProfit);
    expect(basis.returnPercentage).toBeLessThan(0);
  });

  test('returns null when either leg is missing (settlement must then fall back to proportional)', () => {
    const buyLeg = { amount: 100, fees: { totalFees: 1 } };
    expect(deriveMirrorTradeBasis(null, null, COMMISSION_RATE)).toBeNull();
    expect(deriveMirrorTradeBasis(buyLeg, null, COMMISSION_RATE)).toBeNull();
    expect(deriveMirrorTradeBasis(null, { amount: 100, fees: { totalFees: 1 } }, COMMISSION_RATE)).toBeNull();
  });

  test('returnPercentage is null when totalBuyCost is zero', () => {
    const buyLeg = { amount: 0, fees: { totalFees: 0 } };
    const sellLeg = { amount: 50, fees: { totalFees: 1 } };
    const basis = deriveMirrorTradeBasis(buyLeg, sellLeg, COMMISSION_RATE);
    expect(basis.returnPercentage).toBeNull();
  });

  test('handles malformed fee payloads (undefined totalFees) without crashing', () => {
    const buyLeg = { amount: 1000, fees: {} };
    const sellLeg = { amount: 1500, fees: {} };
    const basis = deriveMirrorTradeBasis(buyLeg, sellLeg, COMMISSION_RATE);
    expect(basis.totalBuyCost).toBe(1000);
    expect(basis.netSellAmount).toBe(1500);
    expect(basis.grossProfit).toBe(500);
    expect(basis.commission).toBeCloseTo(55, 2);
  });

  test('Phase A end-to-end: legs.js (with Fremdkostenpauschale) matches iOS buy-leg exactly', () => {
    // After Phase A (see `legs.js` APPLY_FOREIGN_COSTS_PHASE_A) the backend
    // `computeInvestorBuyLeg` must produce the same (329 Stk / € 990,29 /
    // € 7,50 Buy-Fees / € 2,21 Residual) numbers that the iOS
    // `InvestorCollectionBillCalculationService` renders on the PDF today.
    // The sell leg is recomputed fresh and differs by ≤ € 1 from the iOS
    // scaled-from-trader-invoice sell fees — accepted known delta for Phase A.
    const feeConfig = {
      orderFeeRate: 0.005, orderFeeMin: 5, orderFeeMax: 50,
      exchangeFeeRate: 0.001, exchangeFeeMin: 1, exchangeFeeMax: 20,
      foreignCosts: 1.50,
    };
    const buyLeg = computeInvestorBuyLeg(1000, 3.01, feeConfig);
    const sellLeg = computeInvestorSellLeg(buyLeg.quantity, 5.00, 1.0, feeConfig);

    // iOS-conformant mfischer fixture
    expect(buyLeg.quantity).toBe(329);
    expect(buyLeg.amount).toBeCloseTo(990.29, 2);
    expect(buyLeg.fees.totalFees).toBeCloseTo(7.50, 2);
    expect(buyLeg.residualAmount).toBeCloseTo(2.21, 2);

    const basis = deriveMirrorTradeBasis(buyLeg, sellLeg, COMMISSION_RATE);
    expect(basis.totalBuyCost).toBeCloseTo(997.79, 2);
    // Sell-fee side: recomputed on backend, slightly differs from iOS-scaled. The
    // gross/commission/net fall in a predictable range. Assert shape + invariants.
    expect(basis.grossProfit).toBeGreaterThan(630);
    expect(basis.grossProfit).toBeLessThan(640);
    expect(basis.commission).toBeCloseTo(round2(basis.grossProfit * COMMISSION_RATE), 2);
    expect(basis.netProfit).toBeCloseTo(round2(basis.grossProfit - basis.commission), 2);
    expect(basis.returnPercentage).toBeGreaterThan(55);
    expect(basis.returnPercentage).toBeLessThan(58);
  });

  test('Phase A end-to-end: smüller fixture (4.000 € / 80 % pool share)', () => {
    const feeConfig = {
      orderFeeRate: 0.005, orderFeeMin: 5, orderFeeMax: 50,
      exchangeFeeRate: 0.001, exchangeFeeMin: 1, exchangeFeeMax: 20,
      foreignCosts: 1.50,
    };
    const buyLeg = computeInvestorBuyLeg(4000, 3.01, feeConfig);
    const sellLeg = computeInvestorSellLeg(buyLeg.quantity, 5.00, 1.0, feeConfig);

    // iOS-conformant smüller fixture: 1.320 Stk / € 3.973,20 / € 25,34 Fees
    expect(buyLeg.quantity).toBe(1320);
    expect(buyLeg.amount).toBeCloseTo(3973.20, 2);
    expect(buyLeg.fees.totalFees).toBeCloseTo(25.34, 2);
    expect(buyLeg.residualAmount).toBeCloseTo(1.46, 2);

    const basis = deriveMirrorTradeBasis(buyLeg, sellLeg, COMMISSION_RATE);
    expect(basis.totalBuyCost).toBeCloseTo(3998.54, 2);
    expect(basis.grossProfit).toBeGreaterThan(2500);
    expect(basis.grossProfit).toBeLessThan(2570);
    expect(basis.commission).toBeCloseTo(round2(basis.grossProfit * COMMISSION_RATE), 2);
    // ROI2 is per-unit driven (buy 3,01 → sell 5,00 minus fees & commission) so
    // both mfischer (20 %) and smüller (80 %) see the same ROI2 up to rounding.
    expect(basis.returnPercentage).toBeGreaterThan(55);
    expect(basis.returnPercentage).toBeLessThan(58);
  });

  test('residual uses full buy cost (amount + fees), so it remains below one additional share', () => {
    // Real-world style case from live bill discussion:
    // Investment 3.000 €, buy price 2,03 €, fees 0,5 % + 0,1 % + 1,50 €.
    // Residual must be computed against total buy cost (incl. fees), not buy amount only.
    const feeConfig = {
      orderFeeRate: 0.005, orderFeeMin: 5, orderFeeMax: 50,
      exchangeFeeRate: 0.001, exchangeFeeMin: 1, exchangeFeeMax: 20,
      foreignCosts: 1.50,
    };

    const investmentCapital = 3000;
    const buyPrice = 2.03;
    const buyLeg = computeInvestorBuyLeg(investmentCapital, buyPrice, feeConfig);
    const totalBuyCost = round2(buyLeg.amount + buyLeg.fees.totalFees);

    // Capital is consumed by amount + fees, leaving only a small residual.
    expect(totalBuyCost).toBeLessThanOrEqual(investmentCapital);
    expect(buyLeg.residualAmount).toBeCloseTo(round2(investmentCapital - totalBuyCost), 2);
    expect(buyLeg.residualAmount).toBeLessThan(buyPrice);

    // One additional share (including updated fees) must exceed available capital.
    const nextQty = buyLeg.quantity + 1;
    const nextAmt = round2(nextQty * buyPrice);
    const nextSellLegStyleFees = calculateOrderFees(nextAmt, true, feeConfig);
    const nextTotalCost = round2(nextAmt + nextSellLegStyleFees.totalFees);
    expect(nextTotalCost).toBeGreaterThan(investmentCapital);
  });
});
