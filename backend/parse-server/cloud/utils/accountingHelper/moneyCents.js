'use strict';

/**
 * EUR monetary amounts as integer cents (GoB P3c SSOT).
 * See Documentation/ADR-018-P3c-Monetary-Cent-Integer-Boundaries.md
 */

const TOLERANCE_CENTS = 2;

const MAX_ABS_CENTS = Number.MAX_SAFE_INTEGER;

function legacyRound2Euro(euro) {
  const n = Number(euro);
  if (!Number.isFinite(n)) {
    return Math.round(n * 100) / 100;
  }
  return Math.round(n * 100) / 100;
}

function assertSafeCents(cents, label = 'cents') {
  if (!Number.isSafeInteger(cents)) {
    throw new Error(`moneyCents.${label}: expected safe integer, got ${cents}`);
  }
  if (Math.abs(cents) > MAX_ABS_CENTS) {
    throw new Error(`moneyCents.${label}: magnitude exceeds MAX_SAFE_INTEGER`);
  }
  return cents;
}

/**
 * @param {number|string} euro
 * @returns {number} signed cent integer (half-up via legacy round2Euro)
 */
function euroToCents(euro) {
  const n = Number(euro);
  if (!Number.isFinite(n)) {
    throw new Error(`moneyCents.euroToCents: non-finite value (${euro})`);
  }
  return assertSafeCents(Math.round(legacyRound2Euro(n) * 100));
}

/**
 * @param {number} cents signed safe integer
 * @returns {number} EUR with at most 2 decimal places
 */
function centsToEuro(cents) {
  const c = Number(cents);
  assertSafeCents(c);
  return c / 100;
}

/** Drop-in for legacy `round2` — cent-normalized EUR half-up. */
function round2Euro(euro) {
  return legacyRound2Euro(euro);
}

function fromEuroNumber(euro) {
  return euroToCents(euro);
}

function addCents(a, b) {
  return assertSafeCents(Number(a) + Number(b));
}

function subtractCents(a, b) {
  return assertSafeCents(Number(a) - Number(b));
}

/**
 * One rounding step after ratio multiply (fees, commission rates).
 * @param {number|string} euro
 * @param {number|string} ratio
 */
function multiplyEuroByRatio(euro, ratio) {
  return round2Euro(Number(euro) * Number(ratio));
}

/**
 * Fee line: one ratio round + min/max clamp, cent-normalized EUR (P3c-1b).
 * @param {number|string} grossEuro
 * @param {number|string} rate
 * @param {number|string} minEuro
 * @param {number|string} maxEuro
 */
function feeFromRatioEuro(grossEuro, rate, minEuro, maxEuro) {
  let fee = multiplyEuroByRatio(grossEuro, rate);
  fee = Math.max(Number(minEuro), Math.min(fee, Number(maxEuro)));
  return centsToEuro(euroToCents(fee));
}

/** Sum fee components in cent space; returns cent-aligned EUR. */
function sumEuroComponents(...components) {
  let totalCents = 0;
  for (const component of components) {
    totalCents = addCents(totalCents, euroToCents(component));
  }
  return centsToEuro(totalCents);
}

function centsEqual(a, b) {
  return Number(a) === Number(b);
}

function withinCentsTolerance(centsA, centsB, toleranceCents = TOLERANCE_CENTS) {
  const tol = Math.max(0, Number(toleranceCents) || 0);
  return Math.abs(Number(centsA) - Number(centsB)) <= tol;
}

function assertCentAlignedEuro(euro, context = {}) {
  const n = Number(euro);
  if (!Number.isFinite(n)) {
    throw new Error(`moneyCents.assertCentAlignedEuro: non-finite ${JSON.stringify(context)}`);
  }
  const normalized = legacyRound2Euro(n);
  if (Math.abs(normalized - n) > 1e-9) {
    throw new Error(
      `moneyCents.assertCentAlignedEuro: not cent-aligned ${n} ${JSON.stringify(context)}`,
    );
  }
  return normalized;
}

/** Non-throwing cent-alignment check for ops audits (ADR-018 P3c). */
function isCentAlignedEuro(euro) {
  const n = Number(euro);
  if (!Number.isFinite(n)) return false;
  return Math.abs(legacyRound2Euro(n) - n) <= 1e-9;
}

/** Normalize arbitrary euro input to cent-aligned EUR for Parse persist. */
function normalizeEuro(euro) {
  return round2Euro(euro);
}

module.exports = {
  TOLERANCE_CENTS,
  euroToCents,
  centsToEuro,
  round2Euro,
  fromEuroNumber,
  addCents,
  subtractCents,
  multiplyEuroByRatio,
  feeFromRatioEuro,
  sumEuroComponents,
  centsEqual,
  withinCentsTolerance,
  assertCentAlignedEuro,
  isCentAlignedEuro,
  normalizeEuro,
};
