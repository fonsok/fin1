'use strict';

const {
  recordRoleAgreementConsentEntry,
  resolveRetailRole,
} = require('../roleAgreementConsent');

jest.mock('../roleAgreementEmail', () => ({
  sendRoleAgreementConfirmationEmail: jest.fn().mockResolvedValue(true),
}));

jest.mock('../legalConsentRecording', () => ({
  recordLegalConsentEntry: jest.fn().mockResolvedValue({
    objectId: 'consent123',
    acceptedAt: new Date().toISOString(),
    skipped: false,
  }),
  getActiveDocumentHash: jest.fn().mockResolvedValue('hash-abc'),
}));

const { recordLegalConsentEntry } = require('../legalConsentRecording');
const { syncParseUserRoleAgreementAcceptance } = require('../legalConsentUserSync');

jest.mock('../legalConsentUserSync', () => ({
  syncParseUserRoleAgreementAcceptance: jest.fn().mockResolvedValue({ consentType: 'trader_agreement' }),
  getCurrentActiveLegalVersion: jest.fn(),
}));

describe('roleAgreementConsent', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  test('resolveRetailRole prefers user role', () => {
    const user = { get: (k) => (k === 'role' ? 'trader' : null) };
    expect(resolveRetailRole(user, { userRole: 'investor' })).toBe('trader');
  });

  test('recordRoleAgreementConsentEntry writes audit row and syncs user', async () => {
    const user = {
      id: 'user1',
      get: jest.fn(),
      set: jest.fn(),
      save: jest.fn().mockResolvedValue(undefined),
    };

    const result = await recordRoleAgreementConsentEntry({
      request: { headers: { 'x-forwarded-for': '203.0.113.10' } },
      user,
      role: 'trader',
      version: '1.0',
      deviceInstallId: 'install-1',
      source: 'onboarding',
      sendConfirmationEmail: false,
    });

    expect(recordLegalConsentEntry).toHaveBeenCalledWith(
      expect.objectContaining({
        consentType: 'trader_agreement',
        version: '1.0',
        source: 'onboarding',
      }),
    );
    expect(syncParseUserRoleAgreementAcceptance).toHaveBeenCalled();
    expect(result.consentType).toBe('trader_agreement');
  });
});
