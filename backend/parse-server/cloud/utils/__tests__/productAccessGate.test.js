'use strict';

jest.mock('../../functions/legal/legalConsentUserSync', () => ({
  resolveUserLegalAcceptanceState: jest.fn(),
  resolveUserRoleAgreementState: jest.fn(),
}));

describe('productAccessGate', () => {
  let mod;
  let resolveUserLegalAcceptanceState;
  let resolveUserRoleAgreementState;

  beforeEach(() => {
    global.Parse = {
      Error: class ParseError extends Error {
        constructor(code, message) {
          super(message);
          this.code = code;
        }

        static get INVALID_SESSION_TOKEN() {
          return 209;
        }

        static get OPERATION_FORBIDDEN() {
          return 119;
        }
      },
    };

    jest.resetModules();
    ({ resolveUserLegalAcceptanceState, resolveUserRoleAgreementState } = require('../../functions/legal/legalConsentUserSync'));
    resolveUserRoleAgreementState.mockResolvedValue({
      required: false,
      accepted: true,
      version: null,
    });
    mod = require('../productAccessGate');
  });

  function makeUser(overrides = {}) {
    return {
      id: 'user-1',
      get(key) {
        return overrides[key];
      },
    };
  }

  test('throws when user is missing', async () => {
    await expect(mod.assertProductAccessEligible(null)).rejects.toMatchObject({
      code: Parse.Error.INVALID_SESSION_TOKEN,
    });
  });

  test('throws when onboarding is incomplete', async () => {
    await expect(
      mod.assertProductAccessEligible(makeUser({ onboardingCompleted: false })),
    ).rejects.toMatchObject({
      code: Parse.Error.OPERATION_FORBIDDEN,
      message: 'Onboarding must be completed before using this feature.',
    });
  });

  test('throws when legal consents are incomplete', async () => {
    resolveUserLegalAcceptanceState.mockResolvedValue({
      acceptedTerms: true,
      acceptedPrivacyPolicy: false,
    });

    await expect(
      mod.assertProductAccessEligible(makeUser({ onboardingCompleted: true })),
    ).rejects.toMatchObject({
      code: Parse.Error.OPERATION_FORBIDDEN,
      message: 'Terms of Service and Privacy Policy must be accepted.',
    });
  });

  test('throws when role agreement is missing for retail user', async () => {
    resolveUserLegalAcceptanceState.mockResolvedValue({
      acceptedTerms: true,
      acceptedPrivacyPolicy: true,
    });
    resolveUserRoleAgreementState.mockResolvedValue({
      required: true,
      role: 'trader',
      accepted: false,
      version: '1.0',
    });

    await expect(
      mod.assertProductAccessEligible(makeUser({ onboardingCompleted: true, role: 'trader' })),
    ).rejects.toMatchObject({
      code: Parse.Error.OPERATION_FORBIDDEN,
      message: 'Trader (Signal Provider) Agreement must be accepted before using this feature.',
    });
  });

  test('passes when onboarding and legal consents are complete', async () => {
    resolveUserLegalAcceptanceState.mockResolvedValue({
      acceptedTerms: true,
      acceptedPrivacyPolicy: true,
    });

    await expect(
      mod.assertProductAccessEligible(makeUser({ onboardingCompleted: true })),
    ).resolves.toBeUndefined();
  });

  test('throws when company KYB is pending review', async () => {
    resolveUserLegalAcceptanceState.mockResolvedValue({
      acceptedTerms: true,
      acceptedPrivacyPolicy: true,
    });

    await expect(
      mod.assertProductAccessEligible(makeUser({
        onboardingCompleted: true,
        accountType: 'company',
        companyKybStatus: 'pending_review',
      })),
    ).rejects.toMatchObject({
      code: Parse.Error.OPERATION_FORBIDDEN,
      message: 'Company KYB review is pending. Investing is not available until approval.',
    });
  });

  test('throws when company KYB requires more information', async () => {
    resolveUserLegalAcceptanceState.mockResolvedValue({
      acceptedTerms: true,
      acceptedPrivacyPolicy: true,
    });

    await expect(
      mod.assertProductAccessEligible(makeUser({
        onboardingCompleted: true,
        accountType: 'company',
        companyKybStatus: 'more_info_requested',
      })),
    ).rejects.toMatchObject({
      code: Parse.Error.OPERATION_FORBIDDEN,
      message: 'Company KYB requires additional information. Complete KYB in the app.',
    });
  });

  test('passes when company KYB is approved', async () => {
    resolveUserLegalAcceptanceState.mockResolvedValue({
      acceptedTerms: true,
      acceptedPrivacyPolicy: true,
    });

    await expect(
      mod.assertProductAccessEligible(makeUser({
        onboardingCompleted: true,
        accountType: 'company',
        companyKybStatus: 'approved',
      })),
    ).resolves.toBeUndefined();
  });

  test('assertCompanyKybApproved ignores individual accounts', () => {
    expect(() => mod.assertCompanyKybApproved(makeUser({
      accountType: 'individual',
      companyKybStatus: 'draft',
    }))).not.toThrow();
  });
});
