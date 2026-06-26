'use strict';

const { registerDevResetTradingDataFunctions } = require('./devHelpers/resetTradingData');
const { registerTradesDebugFunctions } = require('./devHelpers/tradesDebug');
const { registerSchemaInitFunctions } = require('./devHelpers/schemaInit');
const { registerEnsureInvestmentSchemaParseFields } = require('./devHelpers/ensureParseSchemaFields');
const { registerMigrateLegacyCustomerIdFunctions } = require('./devHelpers/migrateLegacyCustomerId');
const { registerCleanupDuplicateInvestmentSplitsFunctions } = require('./devHelpers/cleanupDuplicateInvestmentSplits');
const { registerDevCleanupE2EOpenTrades } = require('./devHelpers/cleanupE2EOpenTrades');
const { registerDevCleanupSignupRunUsers } = require('./devHelpers/cleanupSignupRunUsers');
const { registerMigrateOnboardingLegacyPickerDefaultsFunctions } = require('./devHelpers/migrateOnboardingLegacyPickerDefaults');

registerDevResetTradingDataFunctions();
registerTradesDebugFunctions();
registerEnsureInvestmentSchemaParseFields();
registerSchemaInitFunctions();
registerMigrateLegacyCustomerIdFunctions();
registerCleanupDuplicateInvestmentSplitsFunctions();
registerDevCleanupE2EOpenTrades();
registerDevCleanupSignupRunUsers();
registerMigrateOnboardingLegacyPickerDefaultsFunctions();

console.log('Admin dev helpers loaded');
