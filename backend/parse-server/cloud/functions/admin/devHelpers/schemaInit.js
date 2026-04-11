'use strict';

const { requireAdminRole } = require('../../../utils/permissions');

function registerSchemaInitFunctions() {
  Parse.Cloud.define('initializeNewSchemas', async (request) => {
    requireAdminRole(request);
    console.log('🔧 Initializing new schemas...');

    const results = [];

    try {
      const Watchlist = Parse.Object.extend('Watchlist');
      const testWatchlist = new Watchlist();
      testWatchlist.set('userId', 'schema-init');
      testWatchlist.set('symbol', 'INIT');
      testWatchlist.set('addedAt', new Date());
      testWatchlist.set('notes', '');
      testWatchlist.set('alertPriceAbove', 0);
      testWatchlist.set('alertPriceBelow', 0);
      testWatchlist.set('notifyOnChange', false);
      await testWatchlist.save(null, { useMasterKey: true });
      await testWatchlist.destroy({ useMasterKey: true });
      results.push({ class: 'Watchlist', status: 'created' });
    } catch (error) {
      results.push({ class: 'Watchlist', status: 'error', message: error.message });
    }

    try {
      const SavedFilter = Parse.Object.extend('SavedFilter');
      const testFilter = new SavedFilter();
      testFilter.set('userId', 'schema-init');
      testFilter.set('name', 'Init Filter');
      testFilter.set('filterContext', 'securities_search');
      testFilter.set('filterCriteria', {});
      testFilter.set('isDefault', false);
      await testFilter.save(null, { useMasterKey: true });
      await testFilter.destroy({ useMasterKey: true });
      results.push({ class: 'SavedFilter', status: 'created' });
    } catch (error) {
      results.push({ class: 'SavedFilter', status: 'error', message: error.message });
    }

    try {
      const InvestorWatchlist = Parse.Object.extend('InvestorWatchlist');
      const testInvWatchlist = new InvestorWatchlist();
      testInvWatchlist.set('investorId', 'schema-init');
      testInvWatchlist.set('traderId', 'schema-init');
      testInvWatchlist.set('traderName', 'Init Trader');
      testInvWatchlist.set('traderSpecialization', '');
      testInvWatchlist.set('traderRiskClass', 1);
      testInvWatchlist.set('notes', '');
      testInvWatchlist.set('targetInvestmentAmount', 0);
      testInvWatchlist.set('notifyOnNewTrade', false);
      testInvWatchlist.set('notifyOnPerformanceChange', false);
      testInvWatchlist.set('sortOrder', 0);
      testInvWatchlist.set('addedAt', new Date());
      await testInvWatchlist.save(null, { useMasterKey: true });
      await testInvWatchlist.destroy({ useMasterKey: true });
      results.push({ class: 'InvestorWatchlist', status: 'created' });
    } catch (error) {
      results.push({ class: 'InvestorWatchlist', status: 'error', message: error.message });
    }

    try {
      const PushToken = Parse.Object.extend('PushToken');
      const testToken = new PushToken();
      testToken.set('userId', 'schema-init');
      testToken.set('token', 'init-token');
      testToken.set('tokenType', 'apns');
      testToken.set('deviceId', 'init-device');
      testToken.set('isActive', false);
      testToken.set('lastValidatedAt', new Date());
      testToken.set('validationFailures', 0);
      await testToken.save(null, { useMasterKey: true });
      await testToken.destroy({ useMasterKey: true });
      results.push({ class: 'PushToken', status: 'created' });
    } catch (error) {
      results.push({ class: 'PushToken', status: 'error', message: error.message });
    }

    console.log('✅ Schema initialization complete:', results);
    return {
      success: true,
      message: 'Schema initialization complete',
      results,
    };
  });
}

module.exports = { registerSchemaInitFunctions };
