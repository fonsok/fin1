'use strict';

describe('resolveRequiredReConsents', () => {
  let mod;
  let termsRows;

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
      const rows = termsRows
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
    global.Parse = { Query: FakeQuery };
    // eslint-disable-next-line global-require
    mod = require('../legalConsentUserSync');
  });

  function seedActiveVersions() {
    termsRows = [
      {
        objectId: 'terms-de',
        documentType: 'terms',
        language: 'de',
        isActive: true,
        version: '2.0',
        effectiveDate: new Date('2026-06-01'),
      },
      {
        objectId: 'privacy-de',
        documentType: 'privacy',
        language: 'de',
        isActive: true,
        version: '2.0',
        effectiveDate: new Date('2026-06-01'),
      },
      {
        objectId: 'investor-de',
        documentType: 'investor_agreement',
        language: 'de',
        isActive: true,
        version: '1.1',
        effectiveDate: new Date('2026-06-01'),
      },
    ];
  }

  test('lists TOS drift when stored user version is older than active', async () => {
    seedActiveVersions();
    const user = new FakeParseObject('_User', {
      objectId: 'user-1',
      role: 'investor',
      acceptedTerms: true,
      acceptedTermsVersion: '1.0',
      acceptedPrivacyPolicy: true,
      acceptedPrivacyPolicyVersion: '2.0',
      acceptedInvestorAgreement: true,
      acceptedInvestorAgreementVersion: '1.1',
    });

    const result = await mod.resolveRequiredReConsents(user, { language: 'de' });

    expect(result.required).toHaveLength(1);
    expect(result.required[0]).toMatchObject({
      consentType: 'terms_of_service',
      documentType: 'terms',
      activeVersion: '2.0',
      userVersion: '1.0',
      blocking: true,
      requiresScrollToAccept: false,
    });
  });

  test('skips legacy users without stored version columns', async () => {
    seedActiveVersions();
    const user = new FakeParseObject('_User', {
      objectId: 'user-1',
      role: 'investor',
      acceptedTerms: true,
      acceptedPrivacyPolicy: true,
    });

    const result = await mod.resolveRequiredReConsents(user, { language: 'de' });
    expect(result.required).toEqual([]);
  });

  test('lists role agreement drift with scroll requirement', async () => {
    seedActiveVersions();
    const user = new FakeParseObject('_User', {
      objectId: 'user-1',
      role: 'investor',
      acceptedTerms: true,
      acceptedTermsVersion: '2.0',
      acceptedPrivacyPolicy: true,
      acceptedPrivacyPolicyVersion: '2.0',
      acceptedInvestorAgreement: true,
      acceptedInvestorAgreementVersion: '1.0',
    });

    const result = await mod.resolveRequiredReConsents(user, { language: 'de' });

    expect(result.required).toHaveLength(1);
    expect(result.required[0]).toMatchObject({
      consentType: 'investor_agreement',
      documentType: 'investor_agreement',
      activeVersion: '1.1',
      userVersion: '1.0',
      blocking: true,
      requiresScrollToAccept: true,
    });
  });
});
