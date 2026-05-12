'use strict';

const { registerDevResetTradingDataFunctions } = require('./devHelpers/resetTradingData');
const { registerTradesDebugFunctions } = require('./devHelpers/tradesDebug');
const { registerSchemaInitFunctions } = require('./devHelpers/schemaInit');
const { registerEnsureInvestmentSchemaParseFields } = require('./devHelpers/ensureParseSchemaFields');
const { registerMigrateLegacyCustomerIdFunctions } = require('./devHelpers/migrateLegacyCustomerId');
const { registerCleanupDuplicateInvestmentSplitsFunctions } = require('./devHelpers/cleanupDuplicateInvestmentSplits');

registerDevResetTradingDataFunctions();
registerTradesDebugFunctions();
registerEnsureInvestmentSchemaParseFields();
registerSchemaInitFunctions();
registerMigrateLegacyCustomerIdFunctions();
registerCleanupDuplicateInvestmentSplitsFunctions();

console.log('Admin dev helpers loaded');
