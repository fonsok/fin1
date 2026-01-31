// ============================================================================
// FIN1 Parse Cloud Code
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
      }
    };
  }

  // Filter sensitive data for non-admin users
  const configData = config.toJSON();
  if (!request.master) {
    delete configData.security;
  }

  return configData;
});

// ============================================================================
// LOGGING
// ============================================================================

console.log('===========================================');
console.log('FIN1 Cloud Code Loaded');
console.log('Version: 1.0.0');
console.log('Timestamp:', new Date().toISOString());
console.log('===========================================');
