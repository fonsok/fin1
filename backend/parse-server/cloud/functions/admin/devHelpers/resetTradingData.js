'use strict';

const { requireAdminRole } = require('../../../utils/permissions');
const { handleDevResetTradingTestData } = require('./resetTradingDataHandler');

function registerDevResetTradingDataFunctions() {
  Parse.Cloud.define('devResetTradingTestData', async (request) => {
    requireAdminRole(request);
    return handleDevResetTradingTestData(request);
  });
}

module.exports = { registerDevResetTradingDataFunctions };
