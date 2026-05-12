'use strict';

const mockLoadConfig = jest.fn();

jest.mock('../../../utils/configHelper/index.js', () => ({
  loadConfig: (...args) => mockLoadConfig(...args),
}));

describe('getCurrentTerms placeholder hydration', () => {
  let cloudFunctions;
  let termsRows;

  class FakeParseObject {
    constructor(data) {
      this._data = data;
      this.id = data.objectId || 'mock-terms-id';
      this.createdAt = new Date('2026-01-01T00:00:00.000Z');
      this.updatedAt = new Date('2026-01-02T00:00:00.000Z');
    }

    get(key) {
      return this._data[key];
    }
  }

  class FakeQuery {
    constructor(className) {
      this.className = className;
    }
    equalTo() { return this; }
    descending() { return this; }
    limit() { return this; }
    async first() {
      const row = (termsRows[this.className] || [])[0];
      return row ? new FakeParseObject(row) : null;
    }
  }

  beforeEach(() => {
    jest.resetModules();
    mockLoadConfig.mockReset();
    cloudFunctions = {};
    termsRows = {};

    global.Parse = {
      Cloud: {
        define: (name, fn) => {
          cloudFunctions[name] = fn;
        },
        run: jest.fn(),
      },
      Query: FakeQuery,
      Error: class ParseError extends Error {
        constructor(code, message) {
          super(message);
          this.code = code;
        }
      },
    };
    global.Parse.Error.OBJECT_NOT_FOUND = 101;
    global.Parse.Error.INVALID_VALUE = 142;

    // eslint-disable-next-line global-require
    const { registerLegalPublicAuditFunctions } = require('../publicAudit.js');
    registerLegalPublicAuditFunctions();
  });

  test('replaces legal placeholders in terms sections for both syntaxes', async () => {
    termsRows.TermsContent = [{
      objectId: 'terms-1',
      version: '1.0.0',
      language: 'de',
      documentType: 'terms',
      effectiveDate: new Date('2026-04-01T00:00:00.000Z'),
      isActive: true,
      documentHash: null,
      sections: [
        {
          id: 'intro',
          title: 'Willkommen bei {{LEGAL_PLATFORM_NAME}}',
          content: 'Gebühr {(APP_SERVICE_CHARGE_RATE)} / Tageslimit {{DAILY_LIMIT}}',
          icon: 'doc.text',
        },
      ],
    }];

    mockLoadConfig.mockResolvedValue({
      financial: { appServiceChargeRate: 0.04 },
      limits: { dailyTransactionLimit: 90000 },
      display: { maximumRiskExposurePercent: 2.5 },
      legal: { appName: 'FIN1', platformName: 'FIN1 Plattform' },
    });

    const result = await cloudFunctions.getCurrentTerms({
      params: { language: 'de', documentType: 'terms' },
    });

    expect(result.sections).toHaveLength(1);
    expect(result.sections[0].title).toContain('FIN1 Plattform');
    expect(result.sections[0].content).toContain('4 %');
    expect(result.sections[0].content).toContain('90.000,00');
    expect(result.sections[0].content).not.toContain('{{DAILY_LIMIT}}');
    expect(result.sections[0].content).not.toContain('{(APP_SERVICE_CHARGE_RATE)}');
  });
});
