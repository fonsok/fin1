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
require('./triggers/invoice');
require('./triggers/wallet');
require('./triggers/notification');
require('./triggers/support');
require('./triggers/legal');
require('./triggers/faq');

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
require('./functions/landing');
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
  const { loadConfig } = require('./utils/configHelper/index.js');
  const liveConfig = await loadConfig(true);

  const financialDefaults = {
    orderFeeRate: 0.005,
    orderFeeMin: 5.0,
    orderFeeMax: 50.0,
    traderCommissionRate: 0.10,
    appServiceChargeRate: 0.02,
    minimumCashReserve: 20.0,
    initialAccountBalance: 0.0,
  };

  // Merge live Configuration values over defaults
  const financial = {
    ...financialDefaults,
    ...(liveConfig.financial || {}),
  };
  {
    const n = Number(financial.initialAccountBalance);
    financial.initialAccountBalance = Number.isFinite(n) ? n : financialDefaults.initialAccountBalance;
  }

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
  if (liveConfig.display && typeof liveConfig.display.showDocumentReferenceLinksInAccountStatement === 'boolean') {
    display.showDocumentReferenceLinksInAccountStatement = liveConfig.display.showDocumentReferenceLinksInAccountStatement;
  } else if (typeof display.showDocumentReferenceLinksInAccountStatement !== 'boolean') {
    display.showDocumentReferenceLinksInAccountStatement = true;
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
  const walletGlobal = liveConfig.display?.walletActionModeGlobal || liveConfig.display?.walletActionMode;
  display.walletActionModeGlobal =
    typeof walletGlobal === 'string'
      ? walletGlobal
      : (display.walletFeatureEnabled ? 'deposit_and_withdrawal' : 'disabled');
  display.walletActionModeInvestor =
    typeof liveConfig.display?.walletActionModeInvestor === 'string'
      ? liveConfig.display.walletActionModeInvestor
      : 'deposit_and_withdrawal';
  display.walletActionModeTrader =
    typeof liveConfig.display?.walletActionModeTrader === 'string'
      ? liveConfig.display.walletActionModeTrader
      : 'deposit_and_withdrawal';
  display.walletActionModeIndividual =
    typeof liveConfig.display?.walletActionModeIndividual === 'string'
      ? liveConfig.display.walletActionModeIndividual
      : 'deposit_and_withdrawal';
  display.walletActionModeCompany =
    typeof liveConfig.display?.walletActionModeCompany === 'string'
      ? liveConfig.display.walletActionModeCompany
      : 'deposit_and_withdrawal';
  // Legacy alias.
  display.walletActionMode = display.walletActionModeGlobal;
  // ADR-007 Phase 2 rollout flag: server is the source of truth. Default false so
  // legacy clients keep writing the Invoice locally until the admin flips the flag.
  if (liveConfig.display && typeof liveConfig.display.serviceChargeInvoiceFromBackend === 'boolean') {
    display.serviceChargeInvoiceFromBackend = liveConfig.display.serviceChargeInvoiceFromBackend;
  } else if (typeof display.serviceChargeInvoiceFromBackend !== 'boolean') {
    display.serviceChargeInvoiceFromBackend = false;
  }
  if (liveConfig.display && typeof liveConfig.display.serviceChargeLegacyClientFallbackEnabled === 'boolean') {
    display.serviceChargeLegacyClientFallbackEnabled = liveConfig.display.serviceChargeLegacyClientFallbackEnabled;
  } else if (typeof display.serviceChargeLegacyClientFallbackEnabled !== 'boolean') {
    display.serviceChargeLegacyClientFallbackEnabled = true;
  }
  if (liveConfig.display && typeof liveConfig.display.serviceChargeLegacyDisableAllowedFrom === 'string') {
    display.serviceChargeLegacyDisableAllowedFrom = liveConfig.display.serviceChargeLegacyDisableAllowedFrom;
  } else if (typeof display.serviceChargeLegacyDisableAllowedFrom !== 'string') {
    display.serviceChargeLegacyDisableAllowedFrom = '2026-05-15';
  }

  const defaultLimits = {
    minDeposit: 10.0,
    maxDeposit: 100000.0,
    minInvestment: 20.0,
    maxInvestment: 100000.0,
    dailyTransactionLimit: 10000.0,
  };

  return {
    financial,
    features: configData.features || {
      priceAlertsEnabled: true,
      darkModeEnabled: false,
      biometricAuthEnabled: true,
    },
    limits: { ...defaultLimits, ...(configData.limits || {}) },
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
  if (
    !display ||
    (
      typeof display.showCommissionBreakdownInCreditNote !== 'boolean' &&
      typeof display.showDocumentReferenceLinksInAccountStatement !== 'boolean' &&
      typeof display.maximumRiskExposurePercent !== 'number'
    )
  ) {
    throw new Parse.Error(
      Parse.Error.INVALID_VALUE,
      'Params must include display.showCommissionBreakdownInCreditNote (boolean) and/or display.showDocumentReferenceLinksInAccountStatement (boolean) and/or display.maximumRiskExposurePercent (number 0–100)'
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
  if (typeof display.showDocumentReferenceLinksInAccountStatement === 'boolean') {
    mergedDisplay.showDocumentReferenceLinksInAccountStatement = display.showDocumentReferenceLinksInAccountStatement;
  }
  if (typeof display.maximumRiskExposurePercent === 'number') {
    mergedDisplay.maximumRiskExposurePercent = display.maximumRiskExposurePercent;
  }
  config.set('display', mergedDisplay);
  await config.save(null, { useMasterKey: true });

  const configData = config.toJSON();
  return {
    display: configData.display || {
      showCommissionBreakdownInCreditNote: true,
      showDocumentReferenceLinksInAccountStatement: true,
      maximumRiskExposurePercent: 2.0
    }
  };
});

// ============================================================================
// CONFIG RECONCILIATION (GoB: Nachvollziehbarkeit)
// Detects when code-level defaults differ from DB values and logs discrepancies.
// Runs automatically on server start and can be triggered manually.
// ============================================================================

const { DEFAULT_CONFIG, loadConfig } = require('./utils/configHelper/index.js');
const { processDueSettlementRetries } = require('./utils/accountingHelper/retryQueue');

async function reconcileConfigDefaults() {
  try {
    const dbConfig = await loadConfig(true);
    const codeDefaults = DEFAULT_CONFIG.financial;
    const drifts = [];

    // `initialAccountBalance`: code default is cold-start 0 €; DB almost always carries the
    // admin/seed value (e.g. DEV 10_000 €). Runtime always uses DB via loadConfig — not a defect.
    const skipFinancialReconcileKeys = new Set(['initialAccountBalance']);

    for (const [key, codeValue] of Object.entries(codeDefaults)) {
      if (skipFinancialReconcileKeys.has(key)) continue;
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
// SETTLEMENT RETRY WORKER (fail-closed recovery loop)
// ============================================================================
let settlementRetryWorkerRunning = false;
setInterval(async () => {
  if (settlementRetryWorkerRunning) return;
  settlementRetryWorkerRunning = true;
  try {
    const result = await processDueSettlementRetries({ limit: 20 });
    if (Number(result?.processed || 0) > 0) {
      console.log(`🔁 SettlementRetryWorker processed ${result.processed} job(s)`);
    }
  } catch (err) {
    console.error('❌ SettlementRetryWorker failed:', err && err.message ? err.message : err);
  } finally {
    settlementRetryWorkerRunning = false;
  }
}, 60 * 1000);

// ============================================================================
// LOGGING
// ============================================================================

console.log('===========================================');
console.log('Cloud Code Loaded');
console.log('Version: 1.0.0');
console.log('Timestamp:', new Date().toISOString());
console.log('===========================================');
