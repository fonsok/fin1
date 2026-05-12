'use strict';

const {
  sanitizeObject,
  validatePartialCompanyKybData,
} = require('../../utils/validation');

const { VALID_STEPS } = require('./userCompanyKybConstants');
const {
  bumpRevision,
  assertCompanyKybEligible,
  assertNotTerminal,
} = require('./userCompanyKybHelpers');

async function handleSaveCompanyKybProgress(request) {
  const user = request.user;
  if (!user) throw new Parse.Error(Parse.Error.INVALID_SESSION_TOKEN, 'Login required');

  assertCompanyKybEligible(user);
  assertNotTerminal(user);

  const { step, partial } = request.params;
  const data = request.params.data ? sanitizeObject(request.params.data) : null;

  if (!step || typeof step !== 'string' || step.length > 50) {
    throw new Parse.Error(Parse.Error.INVALID_VALUE, 'step is required and must be a short string');
  }

  if (!VALID_STEPS.includes(step)) {
    throw new Parse.Error(Parse.Error.INVALID_VALUE, 'Invalid step');
  }

  if (data) {
    const partialValidation = validatePartialCompanyKybData(step, data);
    if (!partialValidation.valid) {
      throw new Parse.Error(Parse.Error.INVALID_VALUE, `Validation failed: ${partialValidation.message}`);
    }
  }

  const json = data ? JSON.stringify(data) : '';
  if (json.length > 50000) {
    throw new Parse.Error(Parse.Error.INVALID_VALUE, 'Data payload too large');
  }

  user.set('companyKybStep', step);

  if (!user.get('companyKybStatus')) {
    user.set('companyKybStatus', 'draft');
  }

  bumpRevision(user);
  await user.save(null, { useMasterKey: true });

  const CompanyKybProgress = Parse.Object.extend('CompanyKybProgress');
  const progressQuery = new Parse.Query(CompanyKybProgress);
  progressQuery.equalTo('userId', user.id);
  progressQuery.equalTo('step', step);
  let progress = await progressQuery.first({ useMasterKey: true });

  if (!progress) {
    progress = new CompanyKybProgress();
    progress.set('userId', user.id);
    progress.set('step', step);
  }

  const clientLastSaved = request.params.lastSavedAt;
  if (clientLastSaved && progress.updatedAt) {
    const clientTs = new Date(clientLastSaved).getTime();
    const serverTs = progress.updatedAt.getTime();
    if (serverTs > clientTs) {
      throw new Parse.Error(
        Parse.Error.OBJECT_NOT_FOUND,
        'Conflict: progress was modified by another session. Please reload and try again.'
      );
    }
  }

  if (data) {
    progress.set('data', data);
  }
  progress.set('isPartial', partial === true);

  await progress.save(null, { useMasterKey: true });

  return {
    success: true,
    nextStep: null,
    companyKybCompleted: user.get('companyKybCompleted') || false,
    companyKybStatus: user.get('companyKybStatus') || null,
  };
}

module.exports = {
  handleSaveCompanyKybProgress,
};
