'use strict';

const { registerResponseTemplateFunctions } = require('./templates/responseTemplates');
const { registerEmailTemplateFunctions } = require('./templates/emailTemplates');
const { registerCategoriesAndAnalyticsFunctions } = require('./templates/categoriesAnalytics');
const { registerBackupAndMaintenanceFunctions } = require('./templates/backupAndMaintenance');

registerResponseTemplateFunctions();
registerEmailTemplateFunctions();
registerCategoriesAndAnalyticsFunctions();
registerBackupAndMaintenanceFunctions();

console.log('CSR Templates Cloud Functions loaded');
