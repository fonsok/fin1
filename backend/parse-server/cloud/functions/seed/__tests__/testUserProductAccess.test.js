'use strict';

const { applyProductAccessFields } = require('../testUserProductAccess');

describe('seed test user product access', () => {
  class FakeUser {
    constructor() {
      this._data = {};
    }

    get(key) {
      return this._data[key];
    }

    set(key, value) {
      this._data[key] = value;
    }
  }

  test('applyProductAccessFields sets investor legal + role agreement', () => {
    const user = new FakeUser();
    applyProductAccessFields(user, 'investor', 5);

    expect(user.get('riskTolerance')).toBe(5);
    expect(user.get('onboardingCompleted')).toBe(true);
    expect(user.get('acceptedTerms')).toBe(true);
    expect(user.get('acceptedInvestorAgreement')).toBe(true);
    expect(user.get('acceptedInvestorAgreementVersion')).toBe('1.0');
    expect(user.get('acceptedTraderAgreement')).toBeUndefined();
  });

  test('applyProductAccessFields sets trader legal + role agreement', () => {
    const user = new FakeUser();
    applyProductAccessFields(user, 'trader', 7);

    expect(user.get('riskTolerance')).toBe(7);
    expect(user.get('acceptedTraderAgreement')).toBe(true);
    expect(user.get('acceptedTraderAgreementVersion')).toBe('1.0');
    expect(user.get('acceptedInvestorAgreement')).toBeUndefined();
  });
});
