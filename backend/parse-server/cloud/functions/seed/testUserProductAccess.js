'use strict';

const LEGAL_VERSION = '1.0';
const ROLE_AGREEMENT_VERSION = '1.0';

function applyProductAccessFields(user, role, riskClass) {
  const now = new Date();

  user.set('onboardingCompleted', true);
  user.set('kycStatus', 'verified');
  user.set('riskTolerance', riskClass);

  user.set('acceptedTerms', true);
  user.set('acceptedPrivacyPolicy', true);
  user.set('acceptedTermsVersion', LEGAL_VERSION);
  user.set('acceptedPrivacyPolicyVersion', LEGAL_VERSION);
  user.set('acceptedTermsDate', now);
  user.set('acceptedPrivacyPolicyDate', now);

  if (role === 'investor') {
    user.set('acceptedInvestorAgreement', true);
    user.set('acceptedInvestorAgreementVersion', ROLE_AGREEMENT_VERSION);
    user.set('acceptedInvestorAgreementDate', now);
  } else if (role === 'trader') {
    user.set('acceptedTraderAgreement', true);
    user.set('acceptedTraderAgreementVersion', ROLE_AGREEMENT_VERSION);
    user.set('acceptedTraderAgreementDate', now);
  }
}

module.exports = {
  LEGAL_VERSION,
  ROLE_AGREEMENT_VERSION,
  applyProductAccessFields,
};
