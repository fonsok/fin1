'use strict';

const {
  sanitizeObject,
  validateStepData,
  validatePartialOnboardingData,
} = require('../../utils/validation');

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

Parse.Cloud.define('completeOnboardingStep', async (request) => {
  const user = request.user;
  if (!user) throw new Parse.Error(Parse.Error.INVALID_SESSION_TOKEN, 'Login required');

  const { step } = request.params;
  const data = request.params.data ? sanitizeObject(request.params.data) : null;

  const validSteps = ['personal', 'address', 'tax', 'experience', 'risk', 'consents', 'verification'];
  if (!validSteps.includes(step)) {
    throw new Parse.Error(Parse.Error.INVALID_VALUE, 'Invalid step');
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

Parse.Cloud.define('getOnboardingProgress', async (request) => {
  const user = request.user;
  if (!user) throw new Parse.Error(Parse.Error.INVALID_SESSION_TOKEN, 'Login required');

  const auditQuery = new Parse.Query('OnboardingAudit');
  auditQuery.equalTo('userId', user.id);
  auditQuery.ascending('completedAt');
  const auditEntries = await auditQuery.find({ useMasterKey: true });

  const completedSteps = auditEntries.map(e => e.get('step'));

  const progressQuery = new Parse.Query('OnboardingProgress');
  progressQuery.equalTo('userId', user.id);
  progressQuery.descending('updatedAt');
  const latestProgress = await progressQuery.first({ useMasterKey: true });

  const savedData = latestProgress ? latestProgress.get('data') : null;

  return {
    currentStep: user.get('onboardingStep') || null,
    completedSteps: completedSteps,
    onboardingCompleted: user.get('onboardingCompleted') || false,
    kycStatus: user.get('kycStatus') || null,
    savedData: savedData || null
  };
});

Parse.Cloud.define('saveOnboardingProgress', async (request) => {
  const user = request.user;
  if (!user) throw new Parse.Error(Parse.Error.INVALID_SESSION_TOKEN, 'Login required');

  const { step, partial } = request.params;
  const data = request.params.data ? sanitizeObject(request.params.data) : null;

  if (!step || typeof step !== 'string' || step.length > 50) {
    throw new Parse.Error(Parse.Error.INVALID_VALUE, 'step is required and must be a short string');
  }

  if (data) {
    const partialValidation = validatePartialOnboardingData(step, data);
    if (!partialValidation.valid) {
      throw new Parse.Error(Parse.Error.INVALID_VALUE, `Validation failed: ${partialValidation.message}`);
    }
  }

  const json = data ? JSON.stringify(data) : '';
  if (json.length > 50000) {
    throw new Parse.Error(Parse.Error.INVALID_VALUE, 'Data payload too large');
  }

  user.set('onboardingStep', step);
  await user.save(null, { useMasterKey: true });

  const OnboardingProgress = Parse.Object.extend('OnboardingProgress');
  const progressQuery = new Parse.Query(OnboardingProgress);
  progressQuery.equalTo('userId', user.id);
  progressQuery.equalTo('step', step);
  let progress = await progressQuery.first({ useMasterKey: true });

  if (!progress) {
    progress = new OnboardingProgress();
    progress.set('userId', user.id);
    progress.set('step', step);
  }

  if (data) {
    progress.set('data', data);
  }
  progress.set('isPartial', partial === true);
  progress.set('updatedAt', new Date());

  await progress.save(null, { useMasterKey: true });

  return { success: true, nextStep: null, onboardingCompleted: false };
});
