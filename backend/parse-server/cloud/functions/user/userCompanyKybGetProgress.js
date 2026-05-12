'use strict';

const { assertCompanyKybEligible } = require('./userCompanyKybHelpers');

async function handleGetCompanyKybProgress(request) {
  const user = request.user;
  if (!user) throw new Parse.Error(Parse.Error.INVALID_SESSION_TOKEN, 'Login required');

  assertCompanyKybEligible(user);

  const auditQuery = new Parse.Query('CompanyKybAudit');
  auditQuery.equalTo('userId', user.id);
  auditQuery.select('step');
  auditQuery.ascending('completedAt');
  const auditEntries = await auditQuery.find({ useMasterKey: true });

  const completedSteps = [...new Set(auditEntries.map((e) => e.get('step')))];

  const progressQuery = new Parse.Query('CompanyKybProgress');
  progressQuery.equalTo('userId', user.id);
  progressQuery.ascending('updatedAt');
  const allProgress = await progressQuery.find({ useMasterKey: true });

  let mergedData = {};
  for (const p of allProgress) {
    const stepData = p.get('data');
    if (stepData && typeof stepData === 'object') {
      Object.assign(mergedData, stepData);
    }
  }

  return {
    currentStep: user.get('companyKybStep') || null,
    completedSteps,
    companyKybCompleted: user.get('companyKybCompleted') || false,
    companyKybStatus: user.get('companyKybStatus') || null,
    savedData: Object.keys(mergedData).length > 0 ? mergedData : null,
  };
}

module.exports = {
  handleGetCompanyKybProgress,
};
