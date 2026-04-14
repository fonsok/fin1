'use strict';

const mockLoadConfig = jest.fn();
const mockHydrateFaqLocaleJSON = jest.fn((json) => json);

jest.mock('../../../utils/configHelper/index.js', () => ({
  loadConfig: (...args) => mockLoadConfig(...args),
}));

jest.mock('../faqLocales', () => ({
  hydrateFaqLocaleJSON: (...args) => mockHydrateFaqLocaleJSON(...args),
}));

describe('getFAQs placeholder hydration', () => {
  let cloudFunctions;
  let queryData;

  class FakeParseObject {
    constructor(data) {
      this._data = data;
      this.id = data.objectId || data.id || 'mock-id';
    }

    get(key) {
      return this._data[key];
    }

    toJSON() {
      return { ...this._data };
    }
  }

  class FakeQuery {
    constructor(className) {
      this.className = className;
    }

    equalTo() { return this; }
    ascending() { return this; }
    limit() { return this; }

    async find() {
      return (queryData[this.className] || []).map((row) => new FakeParseObject(row));
    }

    async first() {
      const first = (queryData[this.className] || [])[0];
      return first ? new FakeParseObject(first) : null;
    }

    static or(...queries) {
      return {
        equalTo() { return this; },
        ascending() { return this; },
        limit() { return this; },
        async find() {
          const merged = queries.flatMap((q) => queryData[q.className] || []);
          return merged.map((row) => new FakeParseObject(row));
        },
      };
    }
  }

  beforeEach(() => {
    jest.resetModules();
    cloudFunctions = {};
    queryData = {};
    mockLoadConfig.mockReset();
    mockHydrateFaqLocaleJSON.mockClear();

    global.Parse = {
      Cloud: {
        define: (name, fn) => {
          cloudFunctions[name] = fn;
        },
      },
      Query: FakeQuery,
      Role: function Role() {},
    };

    // eslint-disable-next-line global-require
    require('../faq.js');
  });

  test('replaces financial placeholders from live configuration', async () => {
    queryData.FAQ = [
      {
        objectId: 'faq-1',
        faqId: 'faq-investor-fees',
        categoryId: 'cat-1',
        isPublished: true,
        isArchived: false,
        isPublic: true,
        question: 'Welche Gebühren fallen an?',
        answer: 'Service {{APP_SERVICE_CHARGE_RATE}}, Provision {(TRADER_COMMISSION_RATE)}',
      },
    ];

    mockLoadConfig.mockResolvedValue({
      legal: { appName: 'FIN1' },
      financial: {
        appServiceChargeRate: 0.0275,
        traderCommissionRate: 0.1234,
      },
    });

    const result = await cloudFunctions.getFAQs({
      params: { location: 'landing', isPublic: true },
      user: null,
    });

    expect(result.faqs).toHaveLength(1);
    expect(result.faqs[0].answer).toContain('2,75 %');
    expect(result.faqs[0].answer).toContain('12,34 %');
    expect(result.faqs[0].answer).not.toContain('{{APP_SERVICE_CHARGE_RATE}}');
    expect(result.faqs[0].answer).not.toContain('{(TRADER_COMMISSION_RATE)}');
  });
});
