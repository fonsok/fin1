'use strict';

const { handleCompleteCompanyKybStep } = require('./userCompanyKybCompleteStep');
const { handleGetCompanyKybProgress } = require('./userCompanyKybGetProgress');
const { handleSaveCompanyKybProgress } = require('./userCompanyKybSaveProgress');

function registerUserCompanyKybCloudFunctions() {
  Parse.Cloud.define('completeCompanyKybStep', handleCompleteCompanyKybStep);
  Parse.Cloud.define('getCompanyKybProgress', handleGetCompanyKybProgress);
  Parse.Cloud.define('saveCompanyKybProgress', handleSaveCompanyKybProgress);
}

module.exports = {
  registerUserCompanyKybCloudFunctions,
};
