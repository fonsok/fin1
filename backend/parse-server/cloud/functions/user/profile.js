'use strict';

const { sanitizeObject, validateProfileUpdate } = require('../../utils/validation');
const { readCustomerNumber } = require('../../utils/userIdentity');
const {
  resolveUserLegalAcceptanceState,
  resolveUserRoleAgreementState,
  persistResolvedLegalAcceptanceIfNeeded,
  persistResolvedRoleAgreementIfNeeded,
} = require('../legal/legalConsentUserSync');

async function resolveEffectiveRiskTolerance(user) {
  const stored = user.get('riskTolerance');
  if (Number.isInteger(stored) && stored >= 1 && stored <= 7) {
    return stored;
  }

  const progressQuery = new Parse.Query('OnboardingProgress');
  progressQuery.equalTo('userId', user.id);
  progressQuery.descending('updatedAt');
  const latestProgress = await progressQuery.first({ useMasterKey: true });
  const finalRiskClass = latestProgress?.get('data')?.finalRiskClass;

  if (Number.isInteger(finalRiskClass) && finalRiskClass >= 1 && finalRiskClass <= 7) {
    if (stored !== finalRiskClass) {
      user.set('riskTolerance', finalRiskClass);
      await user.save(null, { useMasterKey: true });
    }
    return finalRiskClass;
  }

  // Legacy seed data stored pre-onboarding tolerance (8–10) in riskTolerance.
  // iOS treats riskTolerance as RiskClass 1–7; map high legacy values to tradable classes.
  if (Number.isInteger(stored) && stored > 7) {
    const mapped = stored >= 9 ? 7 : 6;
    user.set('riskTolerance', mapped);
    await user.save(null, { useMasterKey: true });
    return mapped;
  }

  return Number.isInteger(stored) ? stored : null;
}

// ============================================================================
// USER PROFILE
// ============================================================================

Parse.Cloud.define('getUserProfile', async (request) => {
  const user = request.user;
  if (!user) throw new Parse.Error(Parse.Error.INVALID_SESSION_TOKEN, 'Login required');

  const profileQuery = new Parse.Query('UserProfile');
  profileQuery.equalTo('userId', user.id);
  const profile = await profileQuery.first({ useMasterKey: true });

  const addressQuery = new Parse.Query('UserAddress');
  addressQuery.equalTo('userId', user.id);
  addressQuery.equalTo('isPrimary', true);
  const address = await addressQuery.first({ useMasterKey: true });

  const riskQuery = new Parse.Query('UserRiskAssessment');
  riskQuery.equalTo('userId', user.id);
  riskQuery.descending('validFrom');
  const risk = await riskQuery.first({ useMasterKey: true });

  return {
    user: {
      id: user.id,
      customerNumber: readCustomerNumber(user),
      email: user.get('email'),
      role: user.get('role'),
      status: user.get('status'),
      kycStatus: user.get('kycStatus'),
      onboardingCompleted: user.get('onboardingCompleted')
    },
    profile: profile ? profile.toJSON() : null,
    address: address ? address.toJSON() : null,
    riskAssessment: risk ? risk.toJSON() : null
  };
});

Parse.Cloud.define('getUserMe', async (request) => {
  const user = request.user;
  if (!user) throw new Parse.Error(Parse.Error.INVALID_SESSION_TOKEN, 'Login required');

  const legal = await resolveUserLegalAcceptanceState(user, { language: 'de' });
  await persistResolvedLegalAcceptanceIfNeeded(user, legal);
  const roleAgreement = await resolveUserRoleAgreementState(user, { language: 'de' });
  await persistResolvedRoleAgreementIfNeeded(user, roleAgreement);
  const riskTolerance = await resolveEffectiveRiskTolerance(user);

  // Single round-trip for app refresh / post-login: KYB + identity + legal acceptance SSOT.
  return {
    id: user.id,
    customerNumber: readCustomerNumber(user),
    email: user.get('email') || null,
    role: user.get('role') || null,
    kycStatus: user.get('kycStatus') || null,
    accountType: user.get('accountType') || 'individual',
    companyKybCompleted: user.get('companyKybCompleted') || false,
    companyKybStep: user.get('companyKybStep') || null,
    companyKybStatus: user.get('companyKybStatus') || null,
    onboardingCompleted: user.get('onboardingCompleted') || false,
    onboardingStep: user.get('onboardingStep') || null,
    riskTolerance,
    acceptedTerms: legal.acceptedTerms,
    acceptedPrivacyPolicy: legal.acceptedPrivacyPolicy,
    acceptedTermsVersion: legal.acceptedTermsVersion,
    acceptedPrivacyPolicyVersion: legal.acceptedPrivacyPolicyVersion,
    acceptedTermsDate: legal.acceptedTermsDate,
    acceptedPrivacyPolicyDate: legal.acceptedPrivacyPolicyDate,
    acceptedTraderAgreement: roleAgreement.role === 'trader'
      ? roleAgreement.accepted
      : user.get('acceptedTraderAgreement') === true,
    acceptedTraderAgreementVersion: user.get('acceptedTraderAgreementVersion')
      || (roleAgreement.role === 'trader' ? roleAgreement.version : null),
    acceptedTraderAgreementDate: user.get('acceptedTraderAgreementDate')?.toISOString?.() ?? null,
    acceptedInvestorAgreement: roleAgreement.role === 'investor'
      ? roleAgreement.accepted
      : user.get('acceptedInvestorAgreement') === true,
    acceptedInvestorAgreementVersion: user.get('acceptedInvestorAgreementVersion')
      || (roleAgreement.role === 'investor' ? roleAgreement.version : null),
    acceptedInvestorAgreementDate: user.get('acceptedInvestorAgreementDate')?.toISOString?.() ?? null,
    roleAgreementRequired: roleAgreement.required,
    roleAgreementAccepted: roleAgreement.accepted,
    roleAgreementVersion: roleAgreement.version,
  };
});

Parse.Cloud.define('updateProfile', async (request) => {
  const user = request.user;
  if (!user) throw new Parse.Error(Parse.Error.INVALID_SESSION_TOKEN, 'Login required');

  const params = sanitizeObject(request.params);
  const {
    firstName,
    lastName,
    salutation,
    dateOfBirth,
    phoneNumber,
    streetAndNumber,
    postalCode,
    city,
    country,
    state,
    username,
    email,
  } = params;

  const check = validateProfileUpdate(params);
  if (!check.valid) {
    throw new Parse.Error(Parse.Error.INVALID_VALUE, check.message);
  }

  const profileQuery = new Parse.Query('UserProfile');
  profileQuery.equalTo('userId', user.id);
  let profile = await profileQuery.first({ useMasterKey: true });

  if (!profile) {
    const UserProfile = Parse.Object.extend('UserProfile');
    profile = new UserProfile();
    profile.set('userId', user.id);
  }

  if (firstName) profile.set('firstName', firstName);
  if (lastName) profile.set('lastName', lastName);
  if (salutation) profile.set('salutation', salutation);
  if (dateOfBirth) profile.set('dateOfBirth', new Date(dateOfBirth));
  if (phoneNumber) {
    profile.set('mobilePhone', phoneNumber);
    user.set('phone_number', phoneNumber);
    user.set('phoneNumber', phoneNumber);
  }

  if (streetAndNumber) user.set('streetAndNumber', streetAndNumber);
  if (postalCode) user.set('postalCode', postalCode);
  if (city) user.set('city', city);
  if (country) user.set('country', country);
  if (state) user.set('state', state);
  if (username) user.set('username', username);
  if (email) user.set('email', String(email).toLowerCase().trim());

  await profile.save(null, { useMasterKey: true });
  await user.save(null, { useMasterKey: true });

  return { success: true };
});
