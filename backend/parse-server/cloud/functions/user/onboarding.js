'use strict';

const {
  sanitizeObject,
  validateStepData,
  validatePartialOnboardingData,
} = require('../../utils/validation');
const { sanitizeOnboardingSavedData } = require('../../utils/onboardingLegacyPickerDefaults');
const {
  enforceRiskClass5DerivativesGateOnOnboardingData,
} = require('../../utils/riskClass5DerivativesGate');
const { assertOnboardingProgressRateLimit } = require('../../utils/onboardingProgressRateLimit');

const ONBOARDING_AUDIT_READ_LIMIT = 32;

// Extracts the subset of answers relevant to a given audit step.
// Stored as an immutable JSON snapshot so auditors can see exactly
// what the user answered under which question version.
function buildAuditAnswers(step, data) {
  if (!data) return null;

  switch (step) {
    case 'personal':
      return {
        accountType: data.accountType,
        userRole: data.userRole,
        salutation: data.salutation,
        firstName: data.firstName,
        lastName: data.lastName,
        dateOfBirth: data.dateOfBirth,
        nationality: data.nationality,
        countryOfBirth: data.countryOfBirth,
        placeOfBirth: data.placeOfBirth,
      };

    case 'address':
    case 'tax':
      return {
        streetAndNumber: data.streetAndNumber,
        postalCode: data.postalCode,
        city: data.city,
        country: data.country,
        isNotUSCitizen: data.isNotUSCitizen,
        nationality: data.nationality,
        taxNumber: data.taxNumber,
        additionalResidenceCountry: data.additionalResidenceCountry,
      };

    case 'verification':
      return {
        identificationType: data.identificationType,
      };

    case 'experience':
      return {
        questionnaireVersion: data.questionnaireVersion,
        employmentStatus: data.employmentStatus,
        income: data.income,
        incomeRange: data.incomeRange,
        incomeSources: data.incomeSources,
        cashAndLiquidAssets: data.cashAndLiquidAssets,
        stocksTransactionsCount: data.stocksTransactionsCount,
        stocksInvestmentAmount: data.stocksInvestmentAmount,
        etfsTransactionsCount: data.etfsTransactionsCount,
        etfsInvestmentAmount: data.etfsInvestmentAmount,
        derivativesTransactionsCount: data.derivativesTransactionsCount,
        derivativesInvestmentAmount: data.derivativesInvestmentAmount,
        derivativesHoldingPeriod: data.derivativesHoldingPeriod,
        otherAssets: data.otherAssets,
        leveragedProductsExperience: data.leveragedProductsExperience,
        financialProductsExperience: data.financialProductsExperience,
      };

    case 'risk':
      return {
        questionnaireVersion: data.questionnaireVersion,
        desiredReturn: data.desiredReturn,
        leveragedProductsTotalLossRiskAcknowledged: data.leveragedProductsTotalLossRiskAcknowledged,
        leveragedProductsKnowledgeTestVersion: data.leveragedProductsKnowledgeTestVersion,
        leveragedProductsKnowledgeTestAnswers: data.leveragedProductsKnowledgeTestAnswers,
        leveragedProductsKnowledgeTestPassed: data.leveragedProductsKnowledgeTestPassed,
        calculatedRiskClass: data.calculatedRiskClass,
        finalRiskClass: data.finalRiskClass,
        insiderTradingOptions: data.insiderTradingOptions,
        moneyLaunderingDeclaration: data.moneyLaunderingDeclaration,
        assetType: data.assetType,
      };

    case 'consents':
      return {
        termsVersion: data.termsVersion,
        privacyVersion: data.privacyVersion,
        acceptedTerms: data.acceptedTerms,
        acceptedPrivacyPolicy: data.acceptedPrivacyPolicy,
        acceptedMarketingConsent: data.acceptedMarketingConsent,
      };

    default:
      return null;
  }
}

function syncRiskToleranceFromOnboardingData(user, data) {
  if (!data || data.finalRiskClass == null) return;
  const value = Number(data.finalRiskClass);
  if (!Number.isInteger(value) || value < 1 || value > 7) return;
  user.set('riskTolerance', value);
}

Parse.Cloud.define('completeOnboardingStep', async (request) => {
  const user = request.user;
  if (!user) throw new Parse.Error(Parse.Error.INVALID_SESSION_TOKEN, 'Login required');

  const { step } = request.params;
  let data = request.params.data ? sanitizeObject(request.params.data) : null;

  const validSteps = ['personal', 'address', 'tax', 'experience', 'risk', 'consents', 'verification'];
  if (!validSteps.includes(step)) {
    throw new Parse.Error(Parse.Error.INVALID_VALUE, 'Invalid step');
  }

  if ((step === 'risk' || step === 'verification') && data) {
    data = enforceRiskClass5DerivativesGateOnOnboardingData(data);
  }

  const validation = validateStepData(step, data);
  if (!validation.valid) {
    throw new Parse.Error(Parse.Error.INVALID_VALUE, `Validation failed: ${validation.message}`);
  }

  user.set('onboardingStep', step);

  if (step === 'verification') {
    user.set('onboardingCompleted', true);
    user.set('onboardingCompletedAt', new Date());

    if (data && data.kycApproved) {
      user.set('kycStatus', 'verified');
      user.set('kycVerifiedAt', new Date());
    } else {
      user.set('kycStatus', 'in_progress');
    }
  }

  if (step === 'risk' || step === 'verification') {
    syncRiskToleranceFromOnboardingData(user, data);
  }

  if (step === 'consents' && data) {
    const { persistOnboardingLegalConsents } = require('../legal/legalConsentRecording');
    await persistOnboardingLegalConsents(request, user, data);
    const { persistOnboardingRoleAgreementConsent } = require('../legal/roleAgreementConsent');
    await persistOnboardingRoleAgreementConsent(request, user, data);
  }

  await user.save(null, { useMasterKey: true });

  const OnboardingAudit = Parse.Object.extend('OnboardingAudit');
  const audit = new OnboardingAudit();
  audit.set('userId', user.id);
  audit.set('step', step);
  audit.set('completedAt', new Date());

  if (data) {
    if (data.questionnaireVersion) audit.set('questionnaireVersion', data.questionnaireVersion);
    if (data.termsVersion) audit.set('termsVersion', data.termsVersion);
    if (data.privacyVersion) audit.set('privacyVersion', data.privacyVersion);

    const answers = buildAuditAnswers(step, data);
    if (answers) {
      audit.set('answers', answers);
    }
  }

  audit.save(null, { useMasterKey: true }).catch(err => {
    console.error(`[OnboardingAudit] Failed to save audit for ${user.id}/${step}:`, err.message);
  });

  return {
    success: true,
    nextStep: validSteps[validSteps.indexOf(step) + 1] || null,
    onboardingCompleted: user.get('onboardingCompleted')
  };
});

function assertImmutableOnboardingRole(user, data) {
  if (!data || data.userRole == null) return;
  const requested = String(data.userRole).trim().toLowerCase();
  const current = String(user.get('role') || '').trim().toLowerCase();
  if (!current || !requested || requested === current) return;
  if (requested !== 'investor' && requested !== 'trader') return;
  if (current !== 'investor' && current !== 'trader') return;
  throw new Parse.Error(
    Parse.Error.OPERATION_FORBIDDEN,
    'User role cannot be changed after account creation',
  );
}

Parse.Cloud.define('getOnboardingProgress', async (request) => {
  const user = request.user;
  if (!user) throw new Parse.Error(Parse.Error.INVALID_SESSION_TOKEN, 'Login required');

  const auditQuery = new Parse.Query('OnboardingAudit');
  auditQuery.equalTo('userId', user.id);
  auditQuery.descending('completedAt');
  auditQuery.limit(ONBOARDING_AUDIT_READ_LIMIT);
  const auditEntries = await auditQuery.find({ useMasterKey: true });

  const completedSteps = [...auditEntries]
    .reverse()
    .map((entry) => entry.get('step'));

  const progressQuery = new Parse.Query('OnboardingProgress');
  progressQuery.equalTo('userId', user.id);
  progressQuery.descending('updatedAt');
  const latestProgress = await progressQuery.first({ useMasterKey: true });

  const currentStep = user.get('onboardingStep') || null;
  const progressStep = latestProgress ? latestProgress.get('step') : null;
  let savedData = latestProgress ? latestProgress.get('data') : null;

  if (savedData) {
    const sanitized = sanitizeOnboardingSavedData(savedData, { currentStep, progressStep });
    savedData = sanitized.data;
    if (sanitized.changed && latestProgress) {
      latestProgress.set('data', sanitized.data);
      await latestProgress.save(null, { useMasterKey: true }).catch((err) => {
        console.error(`[OnboardingProgress] legacy picker cleanup failed for ${user.id}:`, err.message);
      });
    }
  }

  return {
    currentStep,
    completedSteps: completedSteps,
    onboardingCompleted: user.get('onboardingCompleted') || false,
    kycStatus: user.get('kycStatus') || null,
    savedData: savedData || null
  };
});

Parse.Cloud.define('saveOnboardingProgress', async (request) => {
  const user = request.user;
  if (!user) throw new Parse.Error(Parse.Error.INVALID_SESSION_TOKEN, 'Login required');

  assertOnboardingProgressRateLimit(user.id);

  const { step, partial } = request.params;
  let data = request.params.data ? sanitizeObject(request.params.data) : null;
  const isPositionOnly = data?._positionOnly === true;

  if (!step || typeof step !== 'string' || step.length > 50) {
    throw new Parse.Error(Parse.Error.INVALID_VALUE, 'step is required and must be a short string');
  }

  if (data && !isPositionOnly) {
    const currentStep = user.get('onboardingStep') || step;
    data = sanitizeOnboardingSavedData(data, {
      currentStep,
      progressStep: step,
    }).data;

    const partialValidation = validatePartialOnboardingData(step, data);
    if (!partialValidation.valid) {
      throw new Parse.Error(Parse.Error.INVALID_VALUE, `Validation failed: ${partialValidation.message}`);
    }
  }

  if (data && !isPositionOnly) {
    assertImmutableOnboardingRole(user, data);
    const json = JSON.stringify(data);
    if (json.length > 50000) {
      throw new Parse.Error(Parse.Error.INVALID_VALUE, 'Data payload too large');
    }
  }

  const previousStep = user.get('onboardingStep');
  if (previousStep !== step) {
    user.set('onboardingStep', step);
    await user.save(null, { useMasterKey: true });
  }

  const OnboardingProgress = Parse.Object.extend('OnboardingProgress');
  const progressQuery = new Parse.Query(OnboardingProgress);
  progressQuery.equalTo('userId', user.id);
  progressQuery.descending('updatedAt');
  let progress = await progressQuery.first({ useMasterKey: true });

  if (!progress) {
    progress = new OnboardingProgress();
    progress.set('userId', user.id);
  }

  progress.set('step', step);
  if (data && !isPositionOnly) {
    progress.set('data', data);
  }
  progress.set('isPartial', partial === true);
  progress.set('updatedAt', new Date());

  await progress.save(null, { useMasterKey: true });

  return { success: true, nextStep: null, onboardingCompleted: false };
});
