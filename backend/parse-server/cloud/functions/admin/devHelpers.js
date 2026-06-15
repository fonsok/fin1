'use strict';

const { registerDevResetTradingDataFunctions } = require('./devHelpers/resetTradingData');
const { registerTradesDebugFunctions } = require('./devHelpers/tradesDebug');
const { registerSchemaInitFunctions } = require('./devHelpers/schemaInit');
const { registerEnsureInvestmentSchemaParseFields } = require('./devHelpers/ensureParseSchemaFields');
const { registerMigrateLegacyCustomerIdFunctions } = require('./devHelpers/migrateLegacyCustomerId');
const { registerCleanupDuplicateInvestmentSplitsFunctions } = require('./devHelpers/cleanupDuplicateInvestmentSplits');
const { registerDevCleanupE2EOpenTrades } = require('./devHelpers/cleanupE2EOpenTrades');

registerDevResetTradingDataFunctions();
registerTradesDebugFunctions();
registerEnsureInvestmentSchemaParseFields();
registerSchemaInitFunctions();
registerMigrateLegacyCustomerIdFunctions();
registerCleanupDuplicateInvestmentSplitsFunctions();
registerDevCleanupE2EOpenTrades();

console.log('Admin dev helpers loaded');
