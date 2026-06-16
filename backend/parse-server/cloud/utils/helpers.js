// ============================================================================
// Parse Cloud Code
// utils/helpers.js - Helper Functions
// ============================================================================

'use strict';

const {
  feeFromRatioEuro,
  sumEuroComponents,
  centsToEuro,
  euroToCents,
} = require('./accountingHelper/moneyCents');

// ============================================================================
// SEQUENTIAL NUMBER GENERATION (P2: atomar via SequenceCounter + $inc)
// ============================================================================

const SEQUENCE_COUNTER_CLASS = 'SequenceCounter';

/**
 * Letzter numerischer Suffix aus bestehenden Belegen (Legacy-Seed beim ersten Counter-Zeilen-Anlegen).
 * @returns {Promise<number>}
 */
async function readMaxLegacySequence(prefix, className, fieldName) {
  const year = new Date().getFullYear();
  const pattern = `${prefix}-${year}-`;
  const ParseClass = Parse.Object.extend(className);
  const query = new Parse.Query(ParseClass);
  query.startsWith(fieldName, pattern);
  query.descending(fieldName);
  query.limit(1);
  const results = await query.find({ useMasterKey: true });
  if (results.length === 0) return 0;
  const lastNumber = results[0].get(fieldName);
  if (!lastNumber || typeof lastNumber !== 'string') return 0;
  const parts = lastNumber.split('-');
  const lastSequence = parts.length >= 3 ? parseInt(parts[2], 10) : NaN;
  return Number.isNaN(lastSequence) ? 0 : lastSequence;
}

/**
 * @param {string} key — eindeutig pro Sequenz (z. B. Order::orderNumber::ORD::2026)
 * @param {() => Promise<number>} readSeed — einmalig beim Anlegen der Counter-Zeile
 * @returns {Promise<number>} nächster Wert (nach Increment)
 */
async function allocateSequentialCounter(key, readSeed) {
  const Seq = Parse.Object.extend(SEQUENCE_COUNTER_CLASS);
  const q = new Parse.Query(Seq);
  q.equalTo('key', key);
  let row = await q.first({ useMasterKey: true });
  if (!row) {
    const seed = await readSeed();
    row = new Seq();
    row.set('key', key);
    row.set('value', seed);
    try {
      await row.save(null, { useMasterKey: true });
    } catch {
      row = await q.first({ useMasterKey: true });
    }
  }
  if (!row) {
    throw new Parse.Error(Parse.Error.INTERNAL_SERVER_ERROR, 'SequenceCounter konnte nicht angelegt werden.');
  }
  row.increment('value', 1);
  await row.save(null, { useMasterKey: true });
  return row.get('value');
}

/**
 * Generate a sequential number with prefix and year
 * Format: PREFIX-YYYY-NNNNNNN
 *
 * @param {string} prefix - Prefix (e.g., 'INV', 'TRD', 'ORD')
 * @param {string} className - Parse class name to query
 * @param {string} fieldName - Field name containing the number
 * @returns {Promise<string>} Generated number
 */
async function generateSequentialNumber(prefix, className, fieldName) {
  const year = new Date().getFullYear();
  const key = `${className}::${fieldName}::${prefix}::${year}`;
  const v = await allocateSequentialCounter(key, () => readMaxLegacySequence(prefix, className, fieldName));
  return `${prefix}-${year}-${v.toString().padStart(7, '0')}`;
}

/**
 * Atomically allocate support ticket numbers (TKT-YYYY-NNNNN).
 * Uses SequenceCounter — race-safe under concurrent creates.
 */
async function generateTicketNumber() {
  const year = new Date().getFullYear();
  const key = `SupportTicket::ticketNumber::TKT::${year}`;
  const v = await allocateSequentialCounter(
    key,
    () => readMaxLegacySequence('TKT', 'SupportTicket', 'ticketNumber'),
  );
  return `TKT-${year}-${v.toString().padStart(5, '0')}`;
}

/**
 * Investment display number per investor (same format as global INV-YYYY-NNNNNNN,
 * but sequence restarts per `investorId` each calendar year).
 * GoB/UI: friendly reference stays investor-scoped; objectId remains globally unique.
 *
 * @param {string} investorId - Investment.investorId (Parse _User.objectId or legacy `user:email`)
 * @returns {Promise<string>}
 */
async function readMaxLegacyInvestorInvestmentSequence(investorId) {
  const id = String(investorId || '').trim();
  const year = new Date().getFullYear();
  const pattern = `INV-${year}-`;
  const ParseClass = Parse.Object.extend('Investment');
  const query = new Parse.Query(ParseClass);
  query.equalTo('investorId', id);
  query.startsWith('investmentNumber', pattern);
  query.descending('investmentNumber');
  query.limit(1);
  const results = await query.find({ useMasterKey: true });
  if (results.length === 0) return 0;
  const lastNumber = results[0].get('investmentNumber');
  if (!lastNumber || typeof lastNumber !== 'string') return 0;
  const parts = lastNumber.split('-');
  const lastSequence = parts.length >= 3 ? parseInt(parts[2], 10) : NaN;
  return Number.isNaN(lastSequence) ? 0 : lastSequence;
}

async function generateInvestorInvestmentNumber(investorId) {
  const id = String(investorId || '').trim();
  if (!id) {
    return generateSequentialNumber('INV', 'Investment', 'investmentNumber');
  }
  const year = new Date().getFullYear();
  const key = `Investment::investmentNumber::INV::${year}::${id}`;
  const v = await allocateSequentialCounter(key, () => readMaxLegacyInvestorInvestmentSequence(id));
  return `INV-${year}-${v.toString().padStart(7, '0')}`;
}

/**
 * Max numeric sequence for PREFIX-YYYY-* across legacy and canonical _User fields.
 */
async function maxUserCustomerSequence(pattern) {
  let maxSeq = 0;
  for (const field of ['customerNumber', 'customerId']) {
    const query = new Parse.Query(Parse.User);
    query.startsWith(field, pattern);
    query.descending(field);
    query.limit(1);
    const row = await query.first({ useMasterKey: true });
    if (!row) continue;
    const val = row.get(field);
    if (!val || typeof val !== 'string') continue;
    const parts = val.split('-');
    if (parts.length < 3) continue;
    const seq = parseInt(parts[2], 10);
    if (!Number.isNaN(seq) && seq > maxSeq) maxSeq = seq;
  }
  return maxSeq;
}

/**
 * Generate business customer number for _User (canonical field: customerNumber).
 * Format: ANL-YYYY-NNNNN or TRD-YYYY-NNNNN (INV-: per-investor sequence via {@link generateInvestorInvestmentNumber}).
 *
 * @param {string} role - User role ('investor' or 'trader')
 * @returns {Promise<string>}
 */
async function generateCustomerNumber(role) {
  const prefixMap = {
    investor: 'ANL',
    trader: 'TRD',
    admin: 'ADM',
    customer_service: 'CSR',
    business_admin: 'ADM',
    compliance: 'ADM',
  };

  const prefix = prefixMap[role] || 'USR';
  const year = new Date().getFullYear();
  const pattern = `${prefix}-${year}-`;
  const sequence = (await maxUserCustomerSequence(pattern)) + 1;
  return `${prefix}-${year}-${sequence.toString().padStart(5, '0')}`;
}

/** @deprecated Use generateCustomerNumber */
const generateCustomerId = generateCustomerNumber;

// ============================================================================
// FORMATTING
// ============================================================================

/**
 * Format currency amount
 *
 * @param {number} amount - Amount to format
 * @param {string} currency - Currency code (default: EUR)
 * @param {string} locale - Locale (default: de-DE)
 * @returns {string} Formatted amount
 */
function formatCurrency(amount, currency = 'EUR', locale = 'de-DE') {
  return new Intl.NumberFormat(locale, {
    style: 'currency',
    currency: currency
  }).format(amount);
}

/**
 * Format date
 *
 * @param {Date} date - Date to format
 * @param {string} locale - Locale (default: de-DE)
 * @returns {string} Formatted date
 */
function formatDate(date, locale = 'de-DE') {
  return new Intl.DateTimeFormat(locale, {
    year: 'numeric',
    month: '2-digit',
    day: '2-digit'
  }).format(date);
}

// ============================================================================
// VALIDATION
// ============================================================================

/**
 * Validate email format
 *
 * @param {string} email - Email to validate
 * @returns {boolean} Is valid
 */
function isValidEmail(email) {
  const emailRegex = /^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$/;
  return emailRegex.test(email);
}

/**
 * Validate IBAN format (basic check)
 *
 * @param {string} iban - IBAN to validate
 * @returns {boolean} Is valid
 */
function isValidIBAN(iban) {
  const ibanRegex = /^[A-Z]{2}[0-9]{2}[A-Z0-9]{11,30}$/;
  return ibanRegex.test(iban.replace(/\s/g, ''));
}

// ============================================================================
// CALCULATIONS
// ============================================================================

/**
 * Calculate order fees.
 *
 * SSOT für Fee-Defaults ist `utils/configHelper/defaultConfig.js`
 * (`DEFAULT_CONFIG.financial`). Ein `config`-Override-Objekt (z. B. aus
 * `Investment.feeConfigSnapshot` oder `Configuration.financial`) hat Vorrang,
 * fehlende Keys fallen auf die DEFAULT_CONFIG-Werte zurück. Hardcodierte
 * Zweit-Defaults sind verboten — sie haben in der Vergangenheit Drift erzeugt
 * (Residual ≠ Beleg, ADR-008-Vorlauf).
 *
 * @param {number} orderAmount - Order amount
 * @param {boolean} isForeign - Is foreign trade
 * @param {object} config - Optional Fee-Config-Override
 * @returns {{ orderFee: number, exchangeFee: number, foreignCosts: number, totalFees: number }}
 */
function calculateOrderFees(orderAmount, isForeign = false, config = {}) {
  // Lazy require vermeidet zyklische Init zwischen helpers <-> configHelper.
  // eslint-disable-next-line global-require
  const { DEFAULT_CONFIG } = require('./configHelper/defaultConfig');
  const D = DEFAULT_CONFIG.financial || {};
  const pick = (k, fallback) => {
    const v = config && Object.prototype.hasOwnProperty.call(config, k) ? config[k] : undefined;
    return (v === null || v === undefined) ? fallback : v;
  };

  const orderFeeRate = pick('orderFeeRate', D.orderFeeRate);
  const orderFeeMin = pick('orderFeeMin', D.orderFeeMin);
  const orderFeeMax = pick('orderFeeMax', D.orderFeeMax);
  const exchangeFeeRate = pick('exchangeFeeRate', D.exchangeFeeRate);
  const exchangeFeeMin = pick('exchangeFeeMin', D.exchangeFeeMin);
  const exchangeFeeMax = pick('exchangeFeeMax', D.exchangeFeeMax);
  const foreignCosts = pick('foreignCosts', D.foreignCosts);

  const orderFee = feeFromRatioEuro(orderAmount, orderFeeRate, orderFeeMin, orderFeeMax);
  const exchangeFee = feeFromRatioEuro(orderAmount, exchangeFeeRate, exchangeFeeMin, exchangeFeeMax);
  const foreign = isForeign ? centsToEuro(euroToCents(foreignCosts)) : 0;

  return {
    orderFee,
    exchangeFee,
    foreignCosts: foreign,
    totalFees: sumEuroComponents(orderFee, exchangeFee, foreign),
  };
}

/**
 * Calculate service charge (for investments)
 *
 * @param {number} amount - Investment amount
 * @param {number} rate - Service charge rate (default: 0.02 = 2%)
 * @param {number} vatRate - VAT rate (default: 0.19 = 19%)
 * @returns {object} Service charge breakdown
 */
function calculateServiceCharge(amount, rate = 0.02, vatRate = 0.19) {
  const serviceCharge = amount * rate;
  const vat = serviceCharge * vatRate;

  return {
    rate: rate,
    serviceCharge: Math.round(serviceCharge * 100) / 100,
    vat: Math.round(vat * 100) / 100,
    total: Math.round((serviceCharge + vat) * 100) / 100,
    netAmount: Math.round((amount - serviceCharge - vat) * 100) / 100
  };
}

/**
 * Calculate risk class based on scores
 *
 * @param {number} experienceScore - Experience score (0-10)
 * @param {number} knowledgeScore - Knowledge score (0-10)
 * @param {number} frequencyScore - Trading frequency score (0-10)
 * @param {string} desiredReturn - Desired return level
 * @returns {number} Risk class (1-7)
 */
function calculateRiskClass(experienceScore, knowledgeScore, frequencyScore, desiredReturn) {
  const baseScore = (experienceScore + knowledgeScore + frequencyScore) / 3;

  const returnMultiplier = {
    'capital_preservation': 0.5,
    'moderate_growth': 0.75,
    'growth': 1.0,
    'high_growth': 1.25,
    'aggressive': 1.5
  };

  const multiplier = returnMultiplier[desiredReturn] || 1.0;
  const adjustedScore = baseScore * multiplier;

  if (adjustedScore <= 2) return 1;
  if (adjustedScore <= 3) return 2;
  if (adjustedScore <= 4) return 3;
  if (adjustedScore <= 5) return 4;
  if (adjustedScore <= 6) return 5;
  if (adjustedScore <= 8) return 6;
  return 7;
}

// ============================================================================
// EXPORTS
// ============================================================================

module.exports = {
  generateSequentialNumber,
  generateTicketNumber,
  generateInvestorInvestmentNumber,
  generateCustomerNumber,
  generateCustomerId,
  formatCurrency,
  formatDate,
  isValidEmail,
  isValidIBAN,
  calculateOrderFees,
  calculateServiceCharge,
  calculateRiskClass,
  escapeRegExp,
};

function escapeRegExp(str) {
  return str.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
}
