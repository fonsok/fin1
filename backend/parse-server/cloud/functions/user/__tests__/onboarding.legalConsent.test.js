'use strict';

jest.mock('../../legal/legalConsentRecording', () => ({
  persistOnboardingLegalConsents: jest.fn(async () => ({ recorded: [{ consentType: 'terms_of_service' }] })),
}));

describe('completeOnboardingStep consents', () => {
  let handlers;
  let user;
  let savedUserPayloads;

  class FakeUser {
    constructor(id) {
      this.id = id;
      this._data = { onboardingCompleted: false };
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
    user = new FakeUser('user-abc');

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

  test('calls persistOnboardingLegalConsents when step is consents', async () => {
    const { persistOnboardingLegalConsents } = require('../../legal/legalConsentRecording');

    const response = await handlers.completeOnboardingStep({
      user,
      params: {
        step: 'consents',
        data: {
          acceptedTerms: true,
          acceptedPrivacyPolicy: true,
          deviceInstallId: 'device-1',
        },
      },
    });

    expect(persistOnboardingLegalConsents).toHaveBeenCalledTimes(1);
    expect(response.success).toBe(true);
    expect(savedUserPayloads[0].onboardingStep).toBe('consents');
  });
});
