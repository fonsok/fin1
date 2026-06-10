'use strict';

describe('legalConsentRecording', () => {
  let mod;
  let termsRows;
  let consentRows;
  let savedConsents;
  let savedUsers;

  class FakeParseObject {
    constructor(className, data = {}) {
      this.className = className;
      this._data = { ...data };
      this.id = data.objectId || `${className}-${savedConsents.length + 1}`;
      this.createdAt = new Date('2026-06-01T00:00:00.000Z');
    }

    get(key) {
      return this._data[key];
    }

    set(key, value) {
      this._data[key] = value;
    }

    async save() {
      if (this.className === 'LegalConsent') {
        savedConsents.push({ id: this.id, data: { ...this._data } });
      }
      if (this.className === '_User') {
        savedUsers.push({ id: this.id, data: { ...this._data } });
      }
      return this;
    }
  }

  class FakeQuery {
    constructor(className) {
      this.className = className;
      this.filters = {};
      this.sortField = null;
      this.limitN = 100;
    }

    equalTo(field, value) {
      this.filters[field] = value;
      return this;
    }

    descending(field) {
      this.sortField = field;
      return this;
    }

    limit(n) {
      this.limitN = n;
      return this;
    }

    rowsForClass() {
      if (this.className === 'TermsContent') return termsRows;
      if (this.className === 'LegalConsent') return consentRows;
      return [];
    }

    async first() {
      const rows = this.rowsForClass().filter((row) => (
        Object.entries(this.filters).every(([k, v]) => row[k] === v)
      ));
      if (!rows.length) return null;
      if (this.sortField) {
        rows.sort((a, b) => {
          const av = a[this.sortField];
          const bv = b[this.sortField];
          return bv > av ? 1 : bv < av ? -1 : 0;
        });
      }
      return new FakeParseObject(this.className, rows[0]);
    }
  }

  beforeEach(() => {
    jest.resetModules();
    termsRows = [
      {
        objectId: 'terms-de',
        documentType: 'terms',
        language: 'de',
        isActive: true,
        version: '1.0.2',
        documentHash: 'hash-terms',
        effectiveDate: new Date('2026-01-01'),
      },
      {
        objectId: 'privacy-de',
        documentType: 'privacy',
        language: 'de',
        isActive: true,
        version: '1.0.2',
        documentHash: 'hash-privacy',
        effectiveDate: new Date('2026-01-01'),
      },
    ];
    consentRows = [];
    savedConsents = [];
    savedUsers = [];

    global.Parse = {
      Query: FakeQuery,
      Object: {
        extend: (className) => class extends FakeParseObject {
          constructor(data = {}) {
            super(className, data);
          }
        },
      },
      Error: class ParseError extends Error {
        constructor(code, message) {
          super(message);
          this.code = code;
        }
      },
    };
    global.Parse.Error.INVALID_VALUE = 142;
    global.Parse.Error.OBJECT_NOT_FOUND = 101;

    // eslint-disable-next-line global-require
    mod = require('../legalConsentRecording');
  });

  test('persistOnboardingLegalConsents writes two LegalConsent rows and syncs user', async () => {
    const user = new FakeParseObject('_User', { objectId: 'user-1' });
    const request = { headers: { 'user-agent': 'FIN1Tests', 'x-forwarded-for': '127.0.0.1' } };

    const result = await mod.persistOnboardingLegalConsents(request, user, {
      acceptedTerms: true,
      acceptedPrivacyPolicy: true,
      acceptedMarketingConsent: true,
      country: 'Germany',
      deviceInstallId: 'install-abc',
      platform: 'ios',
      appVersion: '1.0.0',
      buildNumber: '42',
      termsVersion: '1.0',
      privacyVersion: '1.0',
    });

    expect(result.recorded).toHaveLength(2);
    expect(savedConsents).toHaveLength(2);
    expect(savedConsents.map((row) => row.data.consentType).sort()).toEqual([
      'privacy_policy',
      'terms_of_service',
    ]);
    expect(savedConsents.every((row) => row.data.version === '1.0.2')).toBe(true);
    expect(savedConsents.every((row) => row.data.source === 'onboarding')).toBe(true);
    expect(user.get('acceptedTermsVersion')).toBe('1.0.2');
    expect(user.get('acceptedPrivacyPolicyVersion')).toBe('1.0.2');
    expect(user.get('acceptedMarketingConsent')).toBe(true);
  });

  test('recordLegalConsentEntry is idempotent for same user/type/version', async () => {
    consentRows.push({
      objectId: 'existing-1',
      userId: 'user-1',
      consentType: 'terms_of_service',
      version: '1.0.2',
      accepted: true,
      acceptedAt: new Date('2026-05-01'),
    });

    const user = new FakeParseObject('_User', { objectId: 'user-1' });
    const first = await mod.recordLegalConsentEntry({
      user,
      consentType: 'terms_of_service',
      version: '1.0.2',
      deviceInstallId: 'install-abc',
    });
    const second = await mod.recordLegalConsentEntry({
      user,
      consentType: 'terms_of_service',
      version: '1.0.2',
      deviceInstallId: 'install-abc',
    });

    expect(first.skipped).toBe(true);
    expect(second.skipped).toBe(true);
    expect(savedConsents).toHaveLength(0);
  });
});
