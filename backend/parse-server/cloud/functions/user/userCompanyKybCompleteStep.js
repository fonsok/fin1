'use strict';

const {
  sanitizeObject,
  validateCompanyKybStepData,
} = require('../../utils/validation');

const { VALID_STEPS, SCHEMA_VERSION } = require('./userCompanyKybConstants');
const {
  bumpRevision,
  assertCompanyKybEligible,
  assertNotTerminal,
  getCompletedStepKeys,
  buildAuditAnswers,
} = require('./userCompanyKybHelpers');

async function handleCompleteCompanyKybStep(request) {
  const user = request.user;
  if (!user) throw new Parse.Error(Parse.Error.INVALID_SESSION_TOKEN, 'Login required');

  assertCompanyKybEligible(user);
  assertNotTerminal(user);

  const { step } = request.params;
  const data = request.params.data ? sanitizeObject(request.params.data) : null;

  if (!step || typeof step !== 'string' || !VALID_STEPS.includes(step)) {
    throw new Parse.Error(Parse.Error.INVALID_VALUE, 'Invalid step');
  }

  if (!data || typeof data !== 'object') {
    throw new Parse.Error(Parse.Error.INVALID_VALUE, 'data object is required');
  }

  const validation = validateCompanyKybStepData(step, data);
  if (!validation.valid) {
    throw new Parse.Error(Parse.Error.INVALID_VALUE, `Validation failed: ${validation.message}`);
  }

  const completedAlready = await getCompletedStepKeys(user.id);

  if (step === 'submission') {
    const requiredPrior = VALID_STEPS.slice(0, -1);
    const missing = requiredPrior.filter((s) => !completedAlready.has(s));
    if (missing.length > 0) {
      throw new Parse.Error(
        Parse.Error.OPERATION_FORBIDDEN,
        `Cannot submit: incomplete steps: ${missing.join(', ')}`
      );
    }
  }

  if (completedAlready.has(step)) {
    const nextIndex = VALID_STEPS.indexOf(step) + 1;
    const nextStep = nextIndex < VALID_STEPS.length ? VALID_STEPS[nextIndex] : null;
    return {
      success: true,
      nextStep,
      companyKybCompleted: user.get('companyKybCompleted') || false,
      companyKybStatus: user.get('companyKybStatus') || null,
    };
  }

  const CompanyKybAudit = Parse.Object.extend('CompanyKybAudit');
  const audit = new CompanyKybAudit();
  audit.set('userId', user.id);
  audit.set('step', step);
  audit.set('completedAt', new Date());
  audit.set('schemaVersion', SCHEMA_VERSION);
  audit.set('fullData', data);

  const answers = buildAuditAnswers(step, data);
  if (answers) {
    audit.set('answers', answers);
  }

  await audit.save(null, { useMasterKey: true });

  user.set('companyKybStep', step);

  if (!user.get('companyKybStatus')) {
    user.set('companyKybStatus', 'draft');
  }

  if (step === 'submission') {
    user.set('companyKybCompleted', true);
    user.set('companyKybStatus', 'pending_review');
    user.set('companyKybCompletedAt', new Date());
    if (data.companyFourEyesRequestId) {
      user.set('companyFourEyesRequestId', data.companyFourEyesRequestId);
    }
  }

  bumpRevision(user);
  await user.save(null, { useMasterKey: true });

  const nextIndex = VALID_STEPS.indexOf(step) + 1;
  const nextStep = nextIndex < VALID_STEPS.length ? VALID_STEPS[nextIndex] : null;

  return {
    success: true,
    nextStep,
    companyKybCompleted: user.get('companyKybCompleted') || false,
    companyKybStatus: user.get('companyKybStatus') || null,
  };
}

module.exports = {
  handleCompleteCompanyKybStep,
};
