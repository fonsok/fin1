'use strict';

const {
  sanitizeObject,
  validateCompanyKybStepData,
  validatePartialCompanyKybData,
} = require('../../utils/validation');

const VALID_STEPS = [
  'legal_entity',
  'registered_address',
  'tax_compliance',
  'beneficial_owners',
  'authorized_representatives',
  'documents',
  'declarations',
  'submission',
];

const SCHEMA_VERSION = 1;
const TERMINAL_STATUSES = ['pending_review', 'approved', 'rejected'];

/**
 * Atomically increments companyKybRevision on the user.
 * Returns the new revision value. Uses Parse increment() which maps
 * to MongoDB $inc – safe against concurrent writers.
 */
function bumpRevision(user) {
  user.increment('companyKybRevision', 1);
}

function assertCompanyKybEligible(user) {
  const accountType = user.get('accountType');
  const role = user.get('role');
  if (accountType !== 'company') {
    throw new Parse.Error(
      Parse.Error.OPERATION_FORBIDDEN,
      'Company KYB is only available for company accounts'
    );
  }
  if (role !== 'investor') {
    throw new Parse.Error(
      Parse.Error.OPERATION_FORBIDDEN,
      'Company KYB is only available for investor accounts'
    );
  }
}

function assertNotTerminal(user) {
  const status = user.get('companyKybStatus');
  if (TERMINAL_STATUSES.includes(status)) {
    throw new Parse.Error(
      Parse.Error.OPERATION_FORBIDDEN,
      `KYB is in terminal status: ${status}`
    );
  }
}

async function getCompletedStepKeys(userId) {
  const query = new Parse.Query('CompanyKybAudit');
  query.equalTo('userId', userId);
  query.select('step');
  const entries = await query.find({ useMasterKey: true });
  return new Set(entries.map((e) => e.get('step')));
}

function buildAuditAnswers(step, data) {
  if (!data) return null;

  switch (step) {
    case 'legal_entity':
      return {
        legalName: data.legalName,
        legalForm: data.legalForm,
        registerType: data.registerType,
        registerNumber: data.registerNumber,
        registerCourt: data.registerCourt,
        incorporationCountry: data.incorporationCountry,
      };
    case 'registered_address':
      return {
        streetAndNumber: data.streetAndNumber,
        postalCode: data.postalCode,
        city: data.city,
        country: data.country,
      };
    case 'tax_compliance':
      return {
        hasVatId: Boolean(data.vatId && String(data.vatId).trim()),
        hasNationalTaxNumber: Boolean(data.nationalTaxNumber && String(data.nationalTaxNumber).trim()),
        noVatIdDeclared: data.noVatIdDeclared,
      };
    case 'beneficial_owners':
      return {
        uboCount: Array.isArray(data.ubos) ? data.ubos.length : 0,
        noUboOver25Percent: data.noUboOver25Percent,
      };
    case 'authorized_representatives':
      return {
        representativeCount: Array.isArray(data.representatives) ? data.representatives.length : 0,
        appAccountHolderIsRepresentative: data.appAccountHolderIsRepresentative,
      };
    case 'documents':
      return {
        documentsAcknowledged: data.documentsAcknowledged,
        manifestCount: Array.isArray(data.documentManifest) ? data.documentManifest.length : 0,
      };
    case 'declarations':
      return {
        isPoliticallyExposed: data.isPoliticallyExposed,
        sanctionsSelfDeclarationAccepted: data.sanctionsSelfDeclarationAccepted,
        accuracyDeclarationAccepted: data.accuracyDeclarationAccepted,
        noTrustThirdPartyDeclarationAccepted: data.noTrustThirdPartyDeclarationAccepted,
      };
    case 'submission':
      return {
        confirmedSummary: data.confirmedSummary,
        companyFourEyesRequestId: data.companyFourEyesRequestId,
      };
    default:
      return null;
  }
}

// ---------------------------------------------------------------------------
// completeCompanyKybStep
// ---------------------------------------------------------------------------
Parse.Cloud.define('completeCompanyKybStep', async (request) => {
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

  // Single DB roundtrip: fetch completed steps for idempotency + step-order checks
  const completedAlready = await getCompletedStepKeys(user.id);

  // Step-order enforcement: submission requires all prior steps completed
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

  // Idempotency: if this exact step is already in the audit trail, return
  // the expected success response without creating a duplicate entry.
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

  // Audit FIRST – compliance-critical, must not be fire-and-forget
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

  // THEN update user fields + atomic revision bump
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
});

// ---------------------------------------------------------------------------
// getCompanyKybProgress – merges savedData across all steps
// ---------------------------------------------------------------------------
Parse.Cloud.define('getCompanyKybProgress', async (request) => {
  const user = request.user;
  if (!user) throw new Parse.Error(Parse.Error.INVALID_SESSION_TOKEN, 'Login required');

  assertCompanyKybEligible(user);

  const auditQuery = new Parse.Query('CompanyKybAudit');
  auditQuery.equalTo('userId', user.id);
  auditQuery.select('step');
  auditQuery.ascending('completedAt');
  const auditEntries = await auditQuery.find({ useMasterKey: true });

  const completedSteps = [...new Set(auditEntries.map((e) => e.get('step')))];

  // Merge savedData across ALL per-step progress entries
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
});

// ---------------------------------------------------------------------------
// saveCompanyKybProgress
// ---------------------------------------------------------------------------
Parse.Cloud.define('saveCompanyKybProgress', async (request) => {
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

  // Optimistic lock on the progress object: if the client sends a
  // lastSavedAt timestamp, reject the save when another writer has
  // updated the record in between.
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
});
