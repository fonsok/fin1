// ============================================================================
// Parse Cloud Code
// utils/configHelper.js - Configuration Helper with Caching
// ============================================================================
//
// Zentrale Konfigurationsverwaltung für Backend-Prozesse.
// Lädt Konfigurationswerte aus der Configuration-Klasse mit Caching.
//
// Best Practice für Finanz-Anwendungen:
// - Kritische Parameter (Commission Rate, etc.) werden zentral verwaltet
// - Caching reduziert Datenbankabfragen
// - Audit-Trail für alle Änderungen
//
// ============================================================================

'use strict';

// ============================================================================
// CACHE CONFIGURATION
// ============================================================================

// Cache TTL in milliseconds (5 minutes)
const CACHE_TTL_MS = 5 * 60 * 1000;

// In-memory cache
let configCache = null;
let cacheTimestamp = 0;

// ============================================================================
// DEFAULT VALUES
// ============================================================================

/**
 * Default configuration values.
 * Used when no configuration exists in the database.
 */
const DEFAULT_CONFIG = {
  financial: {
    // Fee rates
    orderFeeRate: 0.005,        // 0.5%
    orderFeeMin: 5.0,           // €5.00
    orderFeeMax: 50.0,          // €50.00
    exchangeFeeRate: 0.0001,    // 0.01%
    exchangeFeeMin: 0.50,       // €0.50
    exchangeFeeMax: 25.0,       // €25.00
    foreignCosts: 2.50,         // €2.50

    // Commission & Service Charges
    traderCommissionRate: 0.10,       // 10%
    platformServiceChargeRate: 0.02,  // 2%

    // Account settings
    minimumCashReserve: 20.0,         // €20.00
    initialAccountBalance: 1.0,       // €1.00
  },
  limits: {
    minDeposit: 10.0,
    maxDeposit: 100000.0,
    minInvestment: 100.0,
    dailyTransactionLimit: 10000.0,
  },
  display: {
    showCommissionBreakdownInCreditNote: true,
    maximumRiskExposurePercent: 2.0,
    walletFeatureEnabled: false,  // Wallet (crypto) – optional; disable to reduce confusion until needed
  },
};

// ============================================================================
// CRITICAL PARAMETERS (require 4-eyes approval)
// ============================================================================

/**
 * List of parameters that require 4-eyes approval for changes.
 * These are financial parameters with significant business impact.
 */
const CRITICAL_PARAMETERS = [
  'traderCommissionRate',
  'platformServiceChargeRate',
  'initialAccountBalance',
  'orderFeeRate',
  'orderFeeMin',
  'orderFeeMax',
];

/**
 * Check if a parameter is critical (requires 4-eyes approval).
 *
 * @param {string} paramName - Parameter name to check
 * @returns {boolean} True if parameter is critical
 */
function isCriticalParameter(paramName) {
  return CRITICAL_PARAMETERS.includes(paramName);
}

// ============================================================================
// CONFIGURATION LOADING
// ============================================================================

/**
 * Load configuration from database.
 * Uses caching to reduce database queries.
 *
 * @param {boolean} forceRefresh - Force refresh cache
 * @returns {Promise<object>} Configuration object
 */
async function loadConfig(forceRefresh = false) {
  const now = Date.now();

  // Return cached config if valid
  if (!forceRefresh && configCache && (now - cacheTimestamp) < CACHE_TTL_MS) {
    return configCache;
  }

  try {
    const Configuration = Parse.Object.extend('Configuration');
    const query = new Parse.Query(Configuration);
    query.equalTo('isActive', true);
    query.descending('updatedAt');

    const config = await query.first({ useMasterKey: true });

    if (config) {
      // Merge with defaults to ensure all fields exist
      const configData = {
        financial: {
          ...DEFAULT_CONFIG.financial,
          traderCommissionRate: config.get('traderCommissionRate') ?? DEFAULT_CONFIG.financial.traderCommissionRate,
          platformServiceChargeRate: config.get('platformServiceChargeRate') ?? DEFAULT_CONFIG.financial.platformServiceChargeRate,
          minimumCashReserve: config.get('minimumCashReserve') ?? DEFAULT_CONFIG.financial.minimumCashReserve,
          initialAccountBalance: config.get('initialAccountBalance') ?? DEFAULT_CONFIG.financial.initialAccountBalance,
          orderFeeRate: config.get('orderFeeRate') ?? DEFAULT_CONFIG.financial.orderFeeRate,
          orderFeeMin: config.get('orderFeeMin') ?? DEFAULT_CONFIG.financial.orderFeeMin,
          orderFeeMax: config.get('orderFeeMax') ?? DEFAULT_CONFIG.financial.orderFeeMax,
        },
        limits: {
          ...DEFAULT_CONFIG.limits,
          ...(config.get('limits') || {}),
        },
        display: {
          ...DEFAULT_CONFIG.display,
          showCommissionBreakdownInCreditNote: config.get('showCommissionBreakdownInCreditNote') ?? DEFAULT_CONFIG.display.showCommissionBreakdownInCreditNote,
          maximumRiskExposurePercent: config.get('maximumRiskExposurePercent') ?? DEFAULT_CONFIG.display.maximumRiskExposurePercent,
          walletFeatureEnabled: config.get('walletFeatureEnabled') ?? DEFAULT_CONFIG.display.walletFeatureEnabled,
        },
        _id: config.id,
        _updatedAt: config.get('updatedAt'),
        _updatedBy: config.get('updatedBy'),
      };

      configCache = configData;
      cacheTimestamp = now;
      return configData;
    }

    // No config found, return defaults
    configCache = DEFAULT_CONFIG;
    cacheTimestamp = now;
    return DEFAULT_CONFIG;

  } catch (error) {
    console.error('Failed to load configuration:', error);
    // Return cached or defaults on error
    return configCache || DEFAULT_CONFIG;
  }
}

/**
 * Invalidate the configuration cache.
 * Call this after configuration changes.
 */
function invalidateCache() {
  configCache = null;
  cacheTimestamp = 0;
}

// ============================================================================
// CONVENIENCE GETTERS
// ============================================================================

/**
 * Get the trader commission rate.
 *
 * @returns {Promise<number>} Commission rate (0.0 to 1.0)
 */
async function getTraderCommissionRate() {
  const config = await loadConfig();
  return config.financial.traderCommissionRate;
}

/**
 * Get the platform service charge rate.
 *
 * @returns {Promise<number>} Service charge rate (0.0 to 1.0)
 */
async function getPlatformServiceChargeRate() {
  const config = await loadConfig();
  return config.financial.platformServiceChargeRate;
}

/**
 * Get the minimum cash reserve.
 *
 * @returns {Promise<number>} Minimum cash reserve in EUR
 */
async function getMinimumCashReserve() {
  const config = await loadConfig();
  return config.financial.minimumCashReserve;
}

/**
 * Get the initial account balance for new users.
 *
 * @returns {Promise<number>} Initial balance in EUR
 */
async function getInitialAccountBalance() {
  const config = await loadConfig();
  return config.financial.initialAccountBalance;
}

/**
 * Get order fee configuration.
 *
 * @returns {Promise<object>} Order fee config {rate, min, max}
 */
async function getOrderFeeConfig() {
  const config = await loadConfig();
  return {
    rate: config.financial.orderFeeRate,
    min: config.financial.orderFeeMin,
    max: config.financial.orderFeeMax,
  };
}

/**
 * Get all financial configuration.
 *
 * @returns {Promise<object>} Financial configuration object
 */
async function getFinancialConfig() {
  const config = await loadConfig();
  return config.financial;
}

// ============================================================================
// CONFIGURATION VALIDATION
// ============================================================================

/**
 * Validate a configuration value.
 *
 * @param {string} paramName - Parameter name
 * @param {*} value - Value to validate
 * @returns {object} { valid: boolean, error?: string }
 */
function validateConfigValue(paramName, value) {
  const validations = {
    traderCommissionRate: {
      type: 'number',
      min: 0.0,
      max: 1.0,
      errorMsg: 'Trader commission rate must be between 0.0 (0%) and 1.0 (100%)',
    },
    platformServiceChargeRate: {
      type: 'number',
      min: 0.0,
      max: 0.1,
      errorMsg: 'Platform service charge rate must be between 0.0 (0%) and 0.1 (10%)',
    },
    minimumCashReserve: {
      type: 'number',
      min: 0.01,
      max: 1000.0,
      errorMsg: 'Minimum cash reserve must be between €0.01 and €1,000.00',
    },
    initialAccountBalance: {
      type: 'number',
      min: 0.01,
      max: 1000000.0,
      errorMsg: 'Initial account balance must be between €0.01 and €1,000,000.00',
    },
    orderFeeRate: {
      type: 'number',
      min: 0.0,
      max: 0.1,
      errorMsg: 'Order fee rate must be between 0.0 (0%) and 0.1 (10%)',
    },
    orderFeeMin: {
      type: 'number',
      min: 0.0,
      max: 100.0,
      errorMsg: 'Order fee minimum must be between €0.00 and €100.00',
    },
    orderFeeMax: {
      type: 'number',
      min: 1.0,
      max: 500.0,
      errorMsg: 'Order fee maximum must be between €1.00 and €500.00',
    },
    maximumRiskExposurePercent: {
      type: 'number',
      min: 0,
      max: 100,
      errorMsg: 'Maximum risk exposure percent must be between 0 and 100',
    },
    walletFeatureEnabled: {
      type: 'boolean',
      errorMsg: 'Wallet feature enabled must be true or false',
    },
  };

  const validation = validations[paramName];
  if (!validation) {
    return { valid: true }; // Unknown parameter, allow
  }

  if (validation.type === 'boolean') {
    const boolVal = value === true || value === false || value === 1 || value === 0;
    return boolVal ? { valid: true } : { valid: false, error: validation.errorMsg };
  }

  if (typeof value !== validation.type) {
    return { valid: false, error: `${paramName} must be a ${validation.type}` };
  }

  if (validation.min !== undefined && (value < validation.min || value > validation.max)) {
    return { valid: false, error: validation.errorMsg };
  }

  return { valid: true };
}

// ============================================================================
// EXPORTS
// ============================================================================

module.exports = {
  // Cache management
  loadConfig,
  invalidateCache,

  // Getters
  getTraderCommissionRate,
  getPlatformServiceChargeRate,
  getMinimumCashReserve,
  getInitialAccountBalance,
  getOrderFeeConfig,
  getFinancialConfig,

  // Validation
  validateConfigValue,
  isCriticalParameter,

  // Constants
  DEFAULT_CONFIG,
  CRITICAL_PARAMETERS,
  CACHE_TTL_MS,
};
