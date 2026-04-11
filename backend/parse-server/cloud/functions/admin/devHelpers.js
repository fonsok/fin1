'use strict';

const { registerDevResetTradingDataFunctions } = require('./devHelpers/resetTradingData');
const { registerTradesDebugFunctions } = require('./devHelpers/tradesDebug');
const { registerSchemaInitFunctions } = require('./devHelpers/schemaInit');
const { registerMigrateLegacyCustomerIdFunctions } = require('./devHelpers/migrateLegacyCustomerId');

registerDevResetTradingDataFunctions();
registerTradesDebugFunctions();
registerSchemaInitFunctions();
registerMigrateLegacyCustomerIdFunctions();

console.log('Admin dev helpers loaded');
