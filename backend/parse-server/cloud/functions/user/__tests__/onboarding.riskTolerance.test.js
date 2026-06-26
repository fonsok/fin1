'use strict';

describe('completeOnboardingStep riskTolerance sync', () => {
  let handlers;
  let user;
  let savedUserPayloads;

  class FakeUser {
    constructor(id) {
      this.id = id;
      this._data = { onboardingCompleted: false, riskTolerance: 1 };
    }

    get(key) {
      return this._data[key];
    }

    set(key, value) {
      this._data[key] = value;
    }

    async save(_acl, opts) {
      if (opts?.useMasterKey) savedUserPayloads.push({ ...this._data });
      return this;
    }
  }

  beforeEach(() => {
    jest.resetModules();
    savedUserPayloads = [];
    handlers = {};
    user = new FakeUser('user-rc7');

    global.Parse = {
      Cloud: {
        define: (name, fn) => {
          handlers[name] = fn;
        },
      },
      Error: class ParseError extends Error {
        constructor(code, message) {
          super(message);
          this.code = code;
        }
      },
      Object: {
        extend: () => class Audit {
          set() {}
          save() { return Promise.resolve(this); }
        },
      },
    };
    global.Parse.Error.INVALID_SESSION_TOKEN = 209;
    global.Parse.Error.INVALID_VALUE = 142;

    // eslint-disable-next-line global-require
    require('../onboarding.js');
  });

  test('persists finalRiskClass to user.riskTolerance on risk step', async () => {
    await handlers.completeOnboardingStep({
      user,
      params: {
        step: 'risk',
        data: {
          finalRiskClass: 7,
          calculatedRiskClass: 5,
          desiredReturn: 'atLeastHundredPercent',
          leveragedProductsTotalLossRiskAcknowledged: true,
          leveragedProductsKnowledgeTestAnswers: { put_dow_jones_falling: 'A' },
        },
      },
    });

    expect(user.get('riskTolerance')).toBe(7);
    expect(savedUserPayloads.at(-1).riskTolerance).toBe(7);
  });

  test('persists finalRiskClass to user.riskTolerance on verification step', async () => {
    await handlers.completeOnboardingStep({
      user,
      params: {
        step: 'verification',
        data: {
          finalRiskClass: 7,
          identificationType: 'passport',
        },
      },
    });

    expect(user.get('riskTolerance')).toBe(7);
    expect(savedUserPayloads.at(-1).onboardingCompleted).toBe(true);
  });

  test('caps trader RC5 to RC4 on risk step when step-16c gate is missing', async () => {
    await handlers.completeOnboardingStep({
      user,
      params: {
        step: 'risk',
        data: {
          userRole: 'trader',
          finalRiskClass: 5,
          calculatedRiskClass: 5,
          desiredReturn: 'at_least_fifty_percent',
          leveragedProductsTotalLossRiskAcknowledged: true,
          leveragedProductsKnowledgeTestAnswers: { put_dow_jones_falling: 'A' },
          derivativesTransactionsCount: '50+',
          derivativesInvestmentAmount: 'ten_thousand_to_hundred_thousand',
          derivativesHoldingPeriod: 'days_to_weeks',
        },
      },
    });

    expect(user.get('riskTolerance')).toBe(4);
  });
});
