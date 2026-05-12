// ============================================================================
// Parse Cloud Code
// utils/helpers.js - Helper Functions
// ============================================================================

'use strict';

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
 * Calculate order fees
 *
 * @param {number} orderAmount - Order amount
 * @param {boolean} isForeign - Is foreign trade
 * @param {object} config - Fee configuration
 * @returns {object} Fee breakdown
 */
function calculateOrderFees(orderAmount, isForeign = false, config = {}) {
  const orderFeeRate = config.orderFeeRate || 0.005;
  const orderFeeMin = config.orderFeeMin || 5.0;
  const orderFeeMax = config.orderFeeMax || 50.0;
  const exchangeFeeRate = config.exchangeFeeRate || 0.001;
  const exchangeFeeMin = config.exchangeFeeMin || 1.0;
  const exchangeFeeMax = config.exchangeFeeMax || 20.0;
  const foreignCosts = config.foreignCosts || 1.50;

  // Order fee
  let orderFee = orderAmount * orderFeeRate;
  orderFee = Math.max(orderFeeMin, Math.min(orderFee, orderFeeMax));

  // Exchange fee
  let exchangeFee = orderAmount * exchangeFeeRate;
  exchangeFee = Math.max(exchangeFeeMin, Math.min(exchangeFee, exchangeFeeMax));

  // Foreign costs
  const foreign = isForeign ? foreignCosts : 0;

  return {
    orderFee: Math.round(orderFee * 100) / 100,
    exchangeFee: Math.round(exchangeFee * 100) / 100,
    foreignCosts: foreign,
    totalFees: Math.round((orderFee + exchangeFee + foreign) * 100) / 100
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
