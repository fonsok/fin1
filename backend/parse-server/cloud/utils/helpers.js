// ============================================================================
// FIN1 Parse Cloud Code
// utils/helpers.js - Helper Functions
// ============================================================================

'use strict';

// ============================================================================
// SEQUENTIAL NUMBER GENERATION
// ============================================================================

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
  const pattern = `${prefix}-${year}-`;

  const ParseClass = Parse.Object.extend(className);
  const query = new Parse.Query(ParseClass);
  query.startsWith(fieldName, pattern);
  query.descending(fieldName);
  query.limit(1);

  const results = await query.find({ useMasterKey: true });

  let sequence = 1;
  if (results.length > 0) {
    const lastNumber = results[0].get(fieldName);
    const lastSequence = parseInt(lastNumber.split('-')[2], 10);
    sequence = lastSequence + 1;
  }

  return `${prefix}-${year}-${sequence.toString().padStart(7, '0')}`;
}

/**
 * Generate customer ID
 * Format: INV-YYYY-NNNNN or TRD-YYYY-NNNNN
 *
 * @param {string} role - User role ('investor' or 'trader')
 * @returns {Promise<string>} Generated customer ID
 */
async function generateCustomerId(role) {
  const prefixMap = {
    'investor': 'INV',
    'trader': 'TRD',
    'admin': 'ADM',
    'customer_service': 'CSR'
  };

  const prefix = prefixMap[role] || 'USR';
  const year = new Date().getFullYear();
  const pattern = `${prefix}-${year}-`;

  const query = new Parse.Query(Parse.User);
  query.startsWith('customerId', pattern);
  query.descending('customerId');
  query.limit(1);

  const results = await query.find({ useMasterKey: true });

  let sequence = 1;
  if (results.length > 0) {
    const lastId = results[0].get('customerId');
    const lastSequence = parseInt(lastId.split('-')[2], 10);
    sequence = lastSequence + 1;
  }

  return `${prefix}-${year}-${sequence.toString().padStart(5, '0')}`;
}

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
 * @param {number} rate - Service charge rate (default: 0.015 = 1.5%)
 * @param {number} vatRate - VAT rate (default: 0.19 = 19%)
 * @returns {object} Service charge breakdown
 */
function calculateServiceCharge(amount, rate = 0.015, vatRate = 0.19) {
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
  generateCustomerId,
  formatCurrency,
  formatDate,
  isValidEmail,
  isValidIBAN,
  calculateOrderFees,
  calculateServiceCharge,
  calculateRiskClass
};
