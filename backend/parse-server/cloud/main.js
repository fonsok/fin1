// ============================================================================
// Parse Cloud Code
// main.js - Entry Point
// ============================================================================
//
// Diese Datei ist der Einstiegspunkt für Parse Cloud Code.
// Sie lädt alle Trigger, Functions und Utilities.
//
// ============================================================================

'use strict';

// ============================================================================
// IMPORTS
// ============================================================================

// Utils
const { generateSequentialNumber, formatCurrency } = require('./utils/helpers');

// Triggers (encryption must load before class-specific triggers)
require('./triggers/encryption');
require('./triggers/user');
require('./triggers/investment');
require('./triggers/trade');
require('./triggers/order');
require('./triggers/wallet');
require('./triggers/notification');
require('./triggers/support');
require('./triggers/legal');

// Functions
require('./functions/wallet');
require('./functions/investment');
require('./functions/trading');
require('./functions/user');
require('./functions/admin');
require('./functions/reports');
require('./functions/legal');
require('./functions/twoFactor');
require('./functions/support');
require('./functions/security');
require('./functions/notifications');
require('./functions/seed');
require('./functions/configuration');
require('./functions/templates');
require('./functions/encryptExistingData');

// ============================================================================
// HEALTH CHECK
// ============================================================================

Parse.Cloud.define('health', async (request) => {
  return {
    status: 'healthy',
    timestamp: new Date().toISOString(),
    version: '1.0.0',
    cloudCode: true
  };
});

// ============================================================================
// CONFIGURATION
// ============================================================================

// Get app configuration
Parse.Cloud.define('getConfig', async (request) => {
  // Load authoritative financial config from Configuration class (managed via Admin Portal / 4-Eyes)
  const { loadConfig } = require('./utils/configHelper');
  const liveConfig = await loadConfig(true);

  const financialDefaults = {
    orderFeeRate: 0.005,
    orderFeeMin: 5.0,
    orderFeeMax: 50.0,
    traderCommissionRate: 0.10,
    platformServiceChargeRate: 0.02,
    minimumCashReserve: 20.0,
    initialAccountBalance: 1.0,
  };

  // Merge live Configuration values over defaults
  const financial = {
    ...financialDefaults,
    ...(liveConfig.financial || {}),
  };

  // Load optional Config collection (features, limits, display overrides)
  const Config = Parse.Object.extend('Config');
  const query = new Parse.Query(Config);
  const environment = request.params.environment || 'production';
  query.equalTo('environment', environment);
  const config = await query.first({ useMasterKey: true });

  const configData = config ? config.toJSON() : {};
  if (!request.master) {
    delete configData.security;
  }

  const display = configData.display || {};
  if (typeof display.showCommissionBreakdownInCreditNote !== 'boolean') {
    display.showCommissionBreakdownInCreditNote = true;
  }
  if (typeof display.maximumRiskExposurePercent !== 'number' || display.maximumRiskExposurePercent < 0 || display.maximumRiskExposurePercent > 100) {
    display.maximumRiskExposurePercent = 2.0;
  }
  // Display flags from Configuration class (admin portal) take precedence
  if (liveConfig.display && typeof liveConfig.display.walletFeatureEnabled === 'boolean') {
    display.walletFeatureEnabled = liveConfig.display.walletFeatureEnabled;
  } else if (typeof display.walletFeatureEnabled !== 'boolean') {
    display.walletFeatureEnabled = false;
  }

  return {
    financial,
    features: configData.features || {
      priceAlertsEnabled: true,
      darkModeEnabled: false,
      biometricAuthEnabled: true,
    },
    limits: configData.limits || {
      minDeposit: 10.0,
      maxDeposit: 100000.0,
      minInvestment: 100.0,
      dailyTransactionLimit: 10000.0,
    },
    display,
  };
});

// Update app configuration (admin only). Persists display and other config in Parse.
Parse.Cloud.define('updateConfig', async (request) => {
  if (!request.user) {
    throw new Parse.Error(Parse.Error.INVALID_SESSION_TOKEN, 'Login required');
  }
  const role = request.user.get('role');
  if (role !== 'admin') {
    throw new Parse.Error(Parse.Error.OPERATION_FORBIDDEN, 'Admin access required');
  }

  const { display } = request.params || {};
  if (!display || (typeof display.showCommissionBreakdownInCreditNote !== 'boolean' && typeof display.maximumRiskExposurePercent !== 'number')) {
    throw new Parse.Error(
      Parse.Error.INVALID_VALUE,
      'Params must include display.showCommissionBreakdownInCreditNote (boolean) and/or display.maximumRiskExposurePercent (number 0–100)'
    );
  }
  if (typeof display.maximumRiskExposurePercent === 'number' && (display.maximumRiskExposurePercent < 0 || display.maximumRiskExposurePercent > 100)) {
    throw new Parse.Error(Parse.Error.INVALID_VALUE, 'display.maximumRiskExposurePercent must be between 0 and 100');
  }

  const environment = request.params.environment || 'production';
  const Config = Parse.Object.extend('Config');
  let query = new Parse.Query(Config);
  query.equalTo('environment', environment);
  let config = await query.first({ useMasterKey: true });

  if (!config) {
    config = new Config();
    config.set('environment', environment);
  }

  const existingDisplay = config.get('display') || {};
  const mergedDisplay = { ...existingDisplay };
  if (typeof display.showCommissionBreakdownInCreditNote === 'boolean') {
    mergedDisplay.showCommissionBreakdownInCreditNote = display.showCommissionBreakdownInCreditNote;
  }
  if (typeof display.maximumRiskExposurePercent === 'number') {
    mergedDisplay.maximumRiskExposurePercent = display.maximumRiskExposurePercent;
  }
  config.set('display', mergedDisplay);
  await config.save(null, { useMasterKey: true });

  const configData = config.toJSON();
  return {
    display: configData.display || { showCommissionBreakdownInCreditNote: true, maximumRiskExposurePercent: 2.0 }
  };
});

// ============================================================================
// CONFIG RECONCILIATION (GoB: Nachvollziehbarkeit)
// Detects when code-level defaults differ from DB values and logs discrepancies.
// Runs automatically on server start and can be triggered manually.
// ============================================================================

const { DEFAULT_CONFIG, loadConfig } = require('./utils/configHelper');

async function reconcileConfigDefaults() {
  try {
    const dbConfig = await loadConfig(true);
    const codeDefaults = DEFAULT_CONFIG.financial;
    const drifts = [];

    for (const [key, codeValue] of Object.entries(codeDefaults)) {
      const dbValue = dbConfig.financial?.[key];
      if (dbValue !== undefined && dbValue !== null && dbValue !== codeValue) {
        drifts.push({ parameter: key, codeDefault: codeValue, dbValue });
      }
    }

    if (drifts.length > 0) {
      const AuditLog = Parse.Object.extend('AuditLog');
      const log = new AuditLog();
      log.set('logType', 'configuration');
      log.set('action', 'config_defaults_reconciliation');
      log.set('resourceType', 'Configuration');
      log.set('resourceId', 'startup_reconciliation');
      log.set('metadata', {
        timestamp: new Date().toISOString(),
        drifts,
        note: 'Code defaults differ from DB values. DB values take precedence at runtime.',
      });
      await log.save(null, { useMasterKey: true });
      console.log(`⚠️  Config reconciliation: ${drifts.length} drift(s) detected and logged.`);
      drifts.forEach(d => console.log(`   ${d.parameter}: code=${d.codeDefault}, db=${d.dbValue}`));
    } else {
      console.log('✅ Config reconciliation: code defaults and DB values are in sync.');
    }
  } catch (err) {
    console.error('Config reconciliation failed (non-fatal):', err.message);
  }
}

Parse.Cloud.define('reconcileConfigDefaults', async (request) => {
  if (!request.master) {
    const role = request.user?.get('role');
    if (!['admin', 'compliance'].includes(role)) {
      throw new Parse.Error(Parse.Error.OPERATION_FORBIDDEN, 'Admin or compliance access required');
    }
  }
  await reconcileConfigDefaults();
  return { success: true, timestamp: new Date().toISOString() };
});

// Run reconciliation after a short delay to let Parse Server fully initialize
setTimeout(() => {
  reconcileConfigDefaults().catch(err =>
    console.error('Startup config reconciliation failed:', err.message)
  );
}, 5000);

// ============================================================================
// LOGGING
// ============================================================================

console.log('===========================================');
console.log('Cloud Code Loaded');
console.log('Version: 1.0.0');
console.log('Timestamp:', new Date().toISOString());
console.log('===========================================');
