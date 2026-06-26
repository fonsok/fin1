'use strict';

const {
  resolveUserLegalAcceptanceState,
  resolveUserRoleAgreementState,
  resolveRequiredReConsents,
} = require('../functions/legal/legalConsentUserSync');

function readUserField(user, key) {
  if (user && typeof user.get === 'function') {
    return user.get(key);
  }
  return user?.[key];
}

/**
 * Blocks regulated product actions until onboarding is complete, legal consents
 * (including role agreement for retail), and — for company accounts — KYB approval.
 * Server-side enforcement complements client UI gates.
 */
async function assertProductAccessEligible(user, { language = 'de' } = {}) {
  if (!user?.id) {
    throw new Parse.Error(Parse.Error.INVALID_SESSION_TOKEN, 'Login required');
  }

  if (readUserField(user, 'onboardingCompleted') !== true) {
    throw new Parse.Error(
      Parse.Error.OPERATION_FORBIDDEN,
      'Onboarding must be completed before using this feature.',
    );
  }

  const legal = await resolveUserLegalAcceptanceState(user, { language });
  if (legal.acceptedTerms !== true || legal.acceptedPrivacyPolicy !== true) {
    throw new Parse.Error(
      Parse.Error.OPERATION_FORBIDDEN,
      'Terms of Service and Privacy Policy must be accepted.',
    );
  }

  const roleAgreement = await resolveUserRoleAgreementState(user, { language });
  if (roleAgreement.required && roleAgreement.accepted !== true) {
    const label = roleAgreement.role === 'trader'
      ? 'Trader (Signal Provider) Agreement'
      : 'Investor Agreement';
    throw new Parse.Error(
      Parse.Error.OPERATION_FORBIDDEN,
      `${label} must be accepted before using this feature.`,
    );
  }

  const reConsents = await resolveRequiredReConsents(user, { language });
  const blockingReConsent = reConsents.required.find((item) => item.blocking === true);
  if (blockingReConsent) {
    throw new Parse.Error(
      Parse.Error.OPERATION_FORBIDDEN,
      reConsentRequiredMessage(blockingReConsent),
    );
  }

  assertCompanyKybApproved(user);
}

/**
 * Company investors must have KYB approved before regulated product use.
 * Individual accounts are unaffected.
 */
function assertCompanyKybApproved(user) {
  const accountType = normalizeAccountType(readUserField(user, 'accountType'));
  if (accountType !== 'company') {
    return;
  }

  const status = normalizeString(readUserField(user, 'companyKybStatus'));
  if (status === 'approved') {
    return;
  }

  if (status === 'pending_review') {
    throw new Parse.Error(
      Parse.Error.OPERATION_FORBIDDEN,
      'Company KYB review is pending. Investing is not available until approval.',
    );
  }

  if (status === 'more_info_requested') {
    throw new Parse.Error(
      Parse.Error.OPERATION_FORBIDDEN,
      'Company KYB requires additional information. Complete KYB in the app.',
    );
  }

  if (status === 'rejected') {
    throw new Parse.Error(
      Parse.Error.OPERATION_FORBIDDEN,
      'Company KYB was rejected. Contact support.',
    );
  }

  throw new Parse.Error(
    Parse.Error.OPERATION_FORBIDDEN,
    'Company KYB must be completed and approved before using this feature.',
  );
}

function normalizeAccountType(value) {
  return String(value || 'individual').trim().toLowerCase();
}

function normalizeString(value) {
  if (typeof value !== 'string') return '';
  return value.trim();
}

function reConsentRequiredMessage(item) {
  switch (item.consentType) {
    case 'terms_of_service':
      return `Terms of Service must be re-accepted (version ${item.activeVersion} required).`;
    case 'privacy_policy':
      return `Privacy Policy must be re-accepted (version ${item.activeVersion} required).`;
    case 'trader_agreement':
      return `Trader (Signal Provider) Agreement must be re-accepted (version ${item.activeVersion} required).`;
    case 'investor_agreement':
      return `Investor Agreement must be re-accepted (version ${item.activeVersion} required).`;
    default:
      return 'Legal consent must be re-accepted before using this feature.';
  }
}

module.exports = {
  assertProductAccessEligible,
  assertCompanyKybApproved,
  reConsentRequiredMessage,
};
