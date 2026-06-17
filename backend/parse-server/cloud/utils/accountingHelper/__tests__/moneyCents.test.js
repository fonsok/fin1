'use strict';

const legacyRound2 = (n) => Math.round(Number(n) * 100) / 100;

const {
  TOLERANCE_CENTS,
  euroToCents,
  centsToEuro,
  round2Euro,
  addCents,
  subtractCents,
  multiplyEuroByRatio,
  feeFromRatioEuro,
  sumEuroComponents,
  centsEqual,
  withinCentsTolerance,
  assertCentAlignedEuro,
  normalizeEuro,
} = require('../moneyCents');
const { DEFAULT_CONFIG } = require('../../configHelper/defaultConfig');

describe('moneyCents (P3c-0)', () => {
  const D = DEFAULT_CONFIG.financial;

  describe('round2Euro ≡ legacy round2', () => {
    const samples = [
      0, 0.01, 0.1, 0.2, 0.1 + 0.2, 1.005, 1.004, 1.995, -1.995,
      930, 937.5, 988.5, 1600, 2400, 1234.56, 999999.99,
      0.05, 0.15, 7.5, 12.35, 100.005, 0.333, 0.335,
    ];

    test.each(samples)('matches legacy round2 for %p', (value) => {
      expect(round2Euro(value)).toBe(legacyRound2(value));
    });

    test('NaN stays NaN', () => {
      expect(Number.isNaN(round2Euro(Number.NaN))).toBe(true);
    });
  });

  describe('euroToCents / centsToEuro', () => {
    test('round-trip typical settlement amounts', () => {
      expect(centsToEuro(euroToCents(2400))).toBe(2400);
      expect(centsToEuro(euroToCents(988.5))).toBe(988.5);
      expect(euroToCents(1600)).toBe(160000);
    });

    test('euroToCents uses round2Euro normalization (IEEE-safe)', () => {
      expect(euroToCents(1600)).toBe(160000);
      expect(euroToCents(988.5)).toBe(98850);
      expect(euroToCents(legacyRound2(1.005))).toBe(100);
    });

    test('rejects non-finite', () => {
      expect(() => euroToCents(Number.NaN)).toThrow(/non-finite/);
      expect(() => euroToCents(Number.POSITIVE_INFINITY)).toThrow(/non-finite/);
    });
  });

  describe('cent arithmetic', () => {
    test('addCents and subtractCents', () => {
      expect(centsToEuro(addCents(100, 50))).toBe(1.5);
      expect(centsToEuro(subtractCents(200, 75))).toBe(1.25);
    });

    test('multiplyEuroByRatio matches fee-style rounding', () => {
      const gross = 1600;
      const rate = 0.005;
      expect(multiplyEuroByRatio(gross, rate)).toBe(legacyRound2(gross * rate));
    });

    test('feeFromRatioEuro clamps then cent-normalizes', () => {
      expect(feeFromRatioEuro(0, D.orderFeeRate, D.orderFeeMin, D.orderFeeMax)).toBe(D.orderFeeMin);
      expect(assertCentAlignedEuro(feeFromRatioEuro(10000, D.orderFeeRate, D.orderFeeMin, D.orderFeeMax)))
        .toBe(D.orderFeeMax);
    });

    test('sumEuroComponents adds in cent space', () => {
      expect(sumEuroComponents(12.33, 0.5, 2.5)).toBe(15.33);
    });
  });

  describe('tolerance helpers', () => {
    test('TOLERANCE_CENTS matches beleg 2ct', () => {
      expect(TOLERANCE_CENTS).toBe(2);
      expect(withinCentsTolerance(100, 101, 2)).toBe(true);
      expect(withinCentsTolerance(100, 103, 2)).toBe(false);
    });

    test('assertCentAlignedEuro accepts cent-aligned values', () => {
      expect(assertCentAlignedEuro(988.5)).toBe(988.5);
      expect(() => assertCentAlignedEuro(988.501)).toThrow(/cent-aligned/);
    });

    test('isCentAlignedEuro is non-throwing guard', () => {
      const { isCentAlignedEuro } = require('../moneyCents');
      expect(isCentAlignedEuro(100.5)).toBe(true);
      expect(isCentAlignedEuro(100.501)).toBe(false);
      expect(isCentAlignedEuro(Number.NaN)).toBe(false);
    });
  });

  describe('normalizeEuro', () => {
    test('is alias for round2Euro on finite values', () => {
      expect(normalizeEuro(0.1 + 0.2)).toBe(0.3);
    });
  });

  describe('centsEqual', () => {
    test('strict integer equality', () => {
      expect(centsEqual(100, 100)).toBe(true);
      expect(centsEqual(100, 101)).toBe(false);
    });
  });
});
