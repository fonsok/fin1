'use strict';

const { registerSeedFAQCategoryFunctions } = require('./faq/categories');
const { registerSeedFAQFunctions } = require('./faq/faqs');
const { registerFAQOrchestrationFunctions } = require('./faq/orchestration');

registerSeedFAQCategoryFunctions();
registerSeedFAQFunctions();
registerFAQOrchestrationFunctions();

console.log('FAQ seed cloud functions loaded');
