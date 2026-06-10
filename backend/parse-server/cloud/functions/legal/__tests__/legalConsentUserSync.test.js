'use strict';

describe('legalConsentUserSync', () => {
  let mod;
  let termsRows;
  let consentRows;
  let savedUsers;

  class FakeParseObject {
    constructor(className, data = {}) {
      this.className = className;
      this._data = { ...data };
      this.id = data.objectId || `mock-${className}-1`;
    }

    get(key) {
      return this._data[key];
    }

    set(key, value) {
      this._data[key] = value;
    }

    async save() {
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

    async first() {
      const rows = (this.className === 'TermsContent' ? termsRows : consentRows)
        .filter((row) => Object.entries(this.filters).every(([k, v]) => row[k] === v));
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
    termsRows = [];
    consentRows = [];
    savedUsers = [];

    global.Parse = {
      Query: FakeQuery,
    };

    // eslint-disable-next-line global-require
    mod = require('../legalConsentUserSync');
  });

  test('resolveUserLegalAcceptanceState falls back to active TermsContent version', async () => {
    termsRows = [
      {
        objectId: 'terms-de',
        documentType: 'terms',
        language: 'de',
        isActive: true,
        version: '1.0.2',
        effectiveDate: new Date('2026-01-01'),
      },
      {
        objectId: 'privacy-de',
        documentType: 'privacy',
        language: 'de',
        isActive: true,
        version: '1.0.2',
        effectiveDate: new Date('2026-01-01'),
      },
    ];

    const user = new FakeParseObject('_User', {
      objectId: 'user-1',
      acceptedTerms: true,
      acceptedPrivacyPolicy: true,
    });

    const resolved = await mod.resolveUserLegalAcceptanceState(user, { language: 'de' });

    expect(resolved.acceptedTermsVersion).toBe('1.0.2');
    expect(resolved.acceptedPrivacyPolicyVersion).toBe('1.0.2');
  });

  test('resolveUserLegalAcceptanceState prefers LegalConsent over TermsContent', async () => {
    termsRows = [{
      objectId: 'terms-de',
      documentType: 'terms',
      language: 'de',
      isActive: true,
      version: '1.0.2',
      effectiveDate: new Date('2026-01-01'),
    }];
    consentRows = [{
      userId: 'user-1',
      consentType: 'terms_of_service',
      accepted: true,
      version: '1.0.1',
      acceptedAt: new Date('2025-12-01'),
    }];

    const user = new FakeParseObject('_User', {
      objectId: 'user-1',
      acceptedTerms: true,
    });

    const resolved = await mod.resolveUserLegalAcceptanceState(user);
    expect(resolved.acceptedTermsVersion).toBe('1.0.1');
  });

  test('persistResolvedLegalAcceptanceIfNeeded writes missing version columns', async () => {
    const user = new FakeParseObject('_User', {
      objectId: 'user-1',
      acceptedTerms: true,
      acceptedPrivacyPolicy: true,
    });

    const dirty = await mod.persistResolvedLegalAcceptanceIfNeeded(user, {
      acceptedTerms: true,
      acceptedPrivacyPolicy: true,
      acceptedTermsVersion: '1.0.2',
      acceptedPrivacyPolicyVersion: '1.0.2',
    });

    expect(dirty).toBe(true);
    expect(savedUsers[0].data.acceptedTermsVersion).toBe('1.0.2');
    expect(savedUsers[0].data.acceptedPrivacyPolicyVersion).toBe('1.0.2');
  });

  test('syncParseUserLegalAcceptance updates user fields', async () => {
    const user = new FakeParseObject('_User', { objectId: 'user-1' });
    const result = await mod.syncParseUserLegalAcceptance(user, {
      consentType: 'terms_of_service',
      version: '1.0.2',
      acceptedAt: new Date('2026-06-01T12:00:00.000Z'),
    });

    expect(result.version).toBe('1.0.2');
    expect(user.get('acceptedTerms')).toBe(true);
    expect(user.get('acceptedTermsVersion')).toBe('1.0.2');
  });
});
