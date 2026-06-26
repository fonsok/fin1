'use strict';

const {
  assertOnboardingProgressRateLimit,
  resetOnboardingProgressRateLimitForTests,
  MAX_SAVES_PER_WINDOW,
} = require('../onboardingProgressRateLimit');

describe('onboardingProgressRateLimit', () => {
  beforeEach(() => {
    resetOnboardingProgressRateLimitForTests();
    global.Parse = {
      Error: class ParseError extends Error {
        constructor(code, message) {
          super(message);
          this.code = code;
        }
      },
    };
    global.Parse.Error.OPERATION_FORBIDDEN = 119;
  });

  test('allows saves within the per-minute budget', () => {
    for (let i = 0; i < MAX_SAVES_PER_WINDOW; i += 1) {
      expect(() => assertOnboardingProgressRateLimit('user-1')).not.toThrow();
    }
  });

  test('blocks excessive saves for the same user', () => {
    for (let i = 0; i < MAX_SAVES_PER_WINDOW; i += 1) {
      assertOnboardingProgressRateLimit('user-1');
    }
    expect(() => assertOnboardingProgressRateLimit('user-1')).toThrow(/Too many onboarding save requests/);
  });
});
