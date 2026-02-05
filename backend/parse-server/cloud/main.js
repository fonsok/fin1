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

// Triggers
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
  const Config = Parse.Object.extend('Config');
  const query = new Parse.Query(Config);

  const environment = request.params.environment || 'production';
  query.equalTo('environment', environment);

  const config = await query.first({ useMasterKey: true });

  if (!config) {
    // Return defaults
    return {
      financial: {
        orderFeeRate: 0.005,
        orderFeeMin: 5.0,
        orderFeeMax: 50.0,
        traderCommissionRate: 0.05,
        platformServiceCharge: 0.015,
        minimumCashReserve: 12.0
      },
      features: {
        priceAlertsEnabled: true,
        darkModeEnabled: false,
        biometricAuthEnabled: true
      },
      limits: {
        minDeposit: 10.0,
        maxDeposit: 100000.0,
        minInvestment: 100.0,
        dailyTransactionLimit: 10000.0
      },
      display: {
        showCommissionBreakdownInCreditNote: true
      }
    };
  }

  // Filter sensitive data for non-admin users
  const configData = config.toJSON();
  if (!request.master) {
    delete configData.security;
  }

  // Ensure display defaults for backward compatibility
  if (!configData.display) {
    configData.display = { showCommissionBreakdownInCreditNote: true };
  } else if (typeof configData.display.showCommissionBreakdownInCreditNote !== 'boolean') {
    configData.display.showCommissionBreakdownInCreditNote = true;
  }

  return configData;
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
  if (!display || typeof display.showCommissionBreakdownInCreditNote !== 'boolean') {
    throw new Parse.Error(
      Parse.Error.INVALID_VALUE,
      'Params must include display.showCommissionBreakdownInCreditNote (boolean)'
    );
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
  config.set('display', {
    ...existingDisplay,
    showCommissionBreakdownInCreditNote: display.showCommissionBreakdownInCreditNote
  });
  await config.save(null, { useMasterKey: true });

  const configData = config.toJSON();
  return {
    display: configData.display || { showCommissionBreakdownInCreditNote: true }
  };
});

// ============================================================================
// LOGGING
// ============================================================================

console.log('===========================================');
console.log('Cloud Code Loaded');
console.log('Version: 1.0.0');
console.log('Timestamp:', new Date().toISOString());
console.log('===========================================');
