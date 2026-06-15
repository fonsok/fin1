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
require('./functions/documents');
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
  const { normalizeTaxCollectionMode } = require('./utils/configHelper/taxCollectionMode');
  const liveConfig = await loadConfig(true);

  const financialDefaults = {
    orderFeeRate: 0.005,
    orderFeeMin: 5.0,
    orderFeeMax: 50.0,
    traderCommissionRate: 0.05,
    appCommissionRate: 0.05,
    investorCommissionRateTotal: 0.1,
    appServiceChargeRate: 0.02,
    minimumCashReserve: 20.0,
    initialAccountBalance: 0.0,
  };

  // Merge live Configuration values over defaults
  const financial = {
    ...financialDefaults,
    ...(liveConfig.financial || {}),
    maxTraderPartialSells: Math.min(
      3,
      Math.max(
        0,
        Math.floor(Number(
          liveConfig.financial?.maxTraderPartialSells ?? 3,
        )),
      ),
    ),
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
    display.showCommissionBreakdownInCreditNote = false;
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
  // ADR-007 Phase 2: server is SSOT for service-charge Invoice rows.
  if (liveConfig.display && typeof liveConfig.display.serviceChargeInvoiceFromBackend === 'boolean') {
    display.serviceChargeInvoiceFromBackend = liveConfig.display.serviceChargeInvoiceFromBackend;
  } else if (typeof display.serviceChargeInvoiceFromBackend !== 'boolean') {
    display.serviceChargeInvoiceFromBackend = true;
  }
  if (liveConfig.display && typeof liveConfig.display.serviceChargeLegacyClientFallbackEnabled === 'boolean') {
    display.serviceChargeLegacyClientFallbackEnabled = liveConfig.display.serviceChargeLegacyClientFallbackEnabled;
  } else if (typeof display.serviceChargeLegacyClientFallbackEnabled !== 'boolean') {
    display.serviceChargeLegacyClientFallbackEnabled = false;
  }
  if (liveConfig.display && typeof liveConfig.display.serviceChargeLegacyDisableAllowedFrom === 'string') {
    display.serviceChargeLegacyDisableAllowedFrom = liveConfig.display.serviceChargeLegacyDisableAllowedFrom;
  } else if (typeof display.serviceChargeLegacyDisableAllowedFrom !== 'string') {
    display.serviceChargeLegacyDisableAllowedFrom = '2026-05-15';
  }
  if (liveConfig.display && typeof liveConfig.display.investorMonetaryServerOnly === 'boolean') {
    display.investorMonetaryServerOnly = liveConfig.display.investorMonetaryServerOnly;
  } else if (typeof display.investorMonetaryServerOnly !== 'boolean') {
    display.investorMonetaryServerOnly = true;
  }
  if (liveConfig.display && typeof liveConfig.display.traderMonetaryServerOnly === 'boolean') {
    display.traderMonetaryServerOnly = liveConfig.display.traderMonetaryServerOnly;
  } else if (typeof display.traderMonetaryServerOnly !== 'boolean') {
    display.traderMonetaryServerOnly = true;
  }
  if (liveConfig.display && typeof liveConfig.display.frontendReadonlyMode === 'boolean') {
    display.frontendReadonlyMode = liveConfig.display.frontendReadonlyMode;
  } else if (typeof display.frontendReadonlyMode !== 'boolean') {
    display.frontendReadonlyMode = false;
  }
  if (liveConfig.display && typeof liveConfig.display.settlementGLOutboxEnabled === 'boolean') {
    display.settlementGLOutboxEnabled = liveConfig.display.settlementGLOutboxEnabled;
  } else if (typeof display.settlementGLOutboxEnabled !== 'boolean') {
    display.settlementGLOutboxEnabled = false;
  }
  if (liveConfig.display && typeof liveConfig.display.showInvestorPartialSellRealizations === 'boolean') {
    display.showInvestorPartialSellRealizations = liveConfig.display.showInvestorPartialSellRealizations;
  } else if (typeof display.showInvestorPartialSellRealizations !== 'boolean') {
    display.showInvestorPartialSellRealizations = false;
  }

  const defaultLimits = {
    minDeposit: 10.0,
    maxDeposit: 100000.0,
    minInvestment: 20.0,
    maxInvestment: 100000.0,
    maxPoolMirrorBuyOrderAmount: 0,
    dailyTransactionLimit: 10000.0,
  };

  const taxConfig = liveConfig?.tax || {};
  const tax = {
    taxCollectionMode: normalizeTaxCollectionMode(taxConfig.taxCollectionMode),
    withholdingTaxRate: Number.isFinite(taxConfig.withholdingTaxRate) ? taxConfig.withholdingTaxRate : 0.25,
    solidaritySurchargeRate: Number.isFinite(taxConfig.solidaritySurchargeRate)
      ? taxConfig.solidaritySurchargeRate
      : 0.055,
    vatRate: Number.isFinite(taxConfig.vatRate) ? taxConfig.vatRate : 0.19,
  };

  return {
    financial,
    tax,
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
      showCommissionBreakdownInCreditNote: false,
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
const { FINANCIAL_RECONCILIATION_SKIP_KEYS } = require('./utils/configHelper/reconciliationSkips.js');
const { processDueSettlementRetries } = require('./utils/accountingHelper/retryQueue');
const { processDueSettlementOutbox } = require('./utils/accountingHelper/settlementOutbox');
const { audit } = require('./utils/structuredLogger');

async function reconcileConfigDefaults() {
  try {
    const dbConfig = await loadConfig(true);
    const codeDefaults = DEFAULT_CONFIG.financial;
    const drifts = [];

    for (const [key, codeValue] of Object.entries(codeDefaults)) {
      if (FINANCIAL_RECONCILIATION_SKIP_KEYS.has(key)) continue;
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
// AUTO-ENSURE: versionierte Schema-Migrationen (Investment/Document GoB-Felder,
// Audit-Klasse `SchemaMigration`). Verhindert CLP-`addField` bei Client-Saves.
// ============================================================================

const {
  ensureGoBInvestmentEscrowSchemaFields,
} = require('./functions/admin/devHelpers/ensureParseSchemaFields');

setTimeout(() => {
  ensureGoBInvestmentEscrowSchemaFields()
    .then((result) => {
      if (result && result.ok) {
        console.log('✅ Schema migrations (GoB registry) ok');
      } else {
        console.warn('⚠️  Schema migrations partial:', JSON.stringify(result));
      }
    })
    .catch((err) => console.error('Startup schema migrations failed:', err && err.message ? err.message : err));
}, 6000);

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
      audit.info('settlement.retry.worker.tick', {
        processed: result.processed,
        message: 'SettlementRetryWorker processed job(s)',
      });
    }
  } catch (err) {
    audit.error('settlement.retry.worker.failure', {
      error: err && err.message ? err.message : String(err),
      stack: err && err.stack ? err.stack : undefined,
      message: 'SettlementRetryWorker failed',
    });
  } finally {
    settlementRetryWorkerRunning = false;
  }
}, 60 * 1000);

// ============================================================================
// SETTLEMENT GL OUTBOX WORKER (ADR-017 async AppLedger posting)
// ============================================================================
let settlementGLOutboxWorkerRunning = false;
setInterval(async () => {
  if (settlementGLOutboxWorkerRunning) return;
  settlementGLOutboxWorkerRunning = true;
  try {
    const result = await processDueSettlementOutbox({ limit: 25 });
    if (Number(result?.processed || 0) > 0) {
      audit.info('settlement.outbox.worker.tick', {
        processed: result.processed,
        message: 'SettlementGLOutboxWorker processed row(s)',
      });
    }
  } catch (err) {
    audit.error('settlement.outbox.worker.failure', {
      error: err && err.message ? err.message : String(err),
      stack: err && err.stack ? err.stack : undefined,
      message: 'SettlementGLOutboxWorker failed',
    });
  } finally {
    settlementGLOutboxWorkerRunning = false;
  }
}, 45 * 1000);

// ============================================================================
// SLA AUTO-ESCALATION WORKER (support tickets — aligns with iOS SLAMonitoringService)
// ============================================================================
const { processSlaAutoEscalations, getSlaMonitorIntervalMs } = require('./utils/supportSlaMonitor');
let slaMonitorWorkerRunning = false;
const slaMonitorIntervalMs = getSlaMonitorIntervalMs();
console.log(`🔍 SLAMonitorWorker interval: ${slaMonitorIntervalMs / 1000}s (SLA_MONITOR_ENABLED=${process.env.SLA_MONITOR_ENABLED !== '0' ? 'on' : 'off'})`);

setInterval(async () => {
  if (slaMonitorWorkerRunning) return;
  slaMonitorWorkerRunning = true;
  try {
    const result = await processSlaAutoEscalations({ limit: 150 });
    if (Number(result?.escalated || 0) > 0) {
      console.log(`⚠️ SLAMonitorWorker escalated ${result.escalated} ticket(s)`);
    }
  } catch (err) {
    console.error('❌ SLAMonitorWorker failed:', err && err.message ? err.message : err);
  } finally {
    slaMonitorWorkerRunning = false;
  }
}, slaMonitorIntervalMs);

// ============================================================================
// LOGGING
// ============================================================================

console.log('===========================================');
console.log('Cloud Code Loaded');
console.log('Version: 1.0.0');
console.log('Timestamp:', new Date().toISOString());
console.log('===========================================');
