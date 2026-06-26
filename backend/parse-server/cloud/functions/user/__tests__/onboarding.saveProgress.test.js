'use strict';

describe('saveOnboardingProgress load optimizations', () => {
  let handlers;
  let user;
  let progressDocs;
  let userSaveCount;
  let progressSaveCount;

  class FakeUser {
    constructor(id) {
      this.id = id;
      this._data = { onboardingStep: 'welcome' };
    }

    get(key) {
      return this._data[key];
    }

    set(key, value) {
      this._data[key] = value;
    }

    async save() {
      userSaveCount += 1;
      return this;
    }
  }

  class FakeProgress {
    constructor() {
      this._data = {};
      this.id = `progress-${progressDocs.length + 1}`;
    }

    get(key) {
      return this._data[key];
    }

    set(key, value) {
      this._data[key] = value;
    }

    async save() {
      progressSaveCount += 1;
      if (!progressDocs.includes(this)) {
        progressDocs.push(this);
      }
      return this;
    }
  }

  beforeEach(() => {
    jest.resetModules();
    progressDocs = [];
    userSaveCount = 0;
    progressSaveCount = 0;
    user = new FakeUser('user-save');

    const { resetOnboardingProgressRateLimitForTests } = require('../../../utils/onboardingProgressRateLimit');
    resetOnboardingProgressRateLimitForTests();

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
        extend: () => FakeProgress,
      },
      Query: class FakeQuery {
        constructor() {
          this.filters = [];
          this._limit = null;
          this._order = null;
        }

        equalTo(field, value) {
          this.filters.push({ field, value });
          return this;
        }

        descending(field) {
          this._order = { field, direction: 'desc' };
          return this;
        }

        limit(value) {
          this._limit = value;
          return this;
        }

        async first() {
          let matches = progressDocs;
          for (const filter of this.filters) {
            matches = matches.filter((doc) => doc.get(filter.field) === filter.value);
          }
          if (matches.length === 0) {
            return null;
          }
          if (this._order?.field === 'updatedAt' && this._order.direction === 'desc') {
            return matches[matches.length - 1];
          }
          return matches[0];
        }

        async find() {
          return [];
        }
      },
    };
    global.Parse.Error.INVALID_SESSION_TOKEN = 209;
    global.Parse.Error.INVALID_VALUE = 142;
    global.Parse.Error.OPERATION_FORBIDDEN = 119;

    handlers = {};
    // eslint-disable-next-line global-require
    require('../onboarding.js');
  });

  test('reuses one OnboardingProgress row per user', async () => {
    user.set('onboardingStep', 'financial');

    await handlers.saveOnboardingProgress({
      user,
      params: {
        step: 'financial',
        partial: true,
        data: {
          userRole: 'investor',
          registrationMarker: 'financial-save',
        },
      },
    });
    await handlers.saveOnboardingProgress({
      user,
      params: {
        step: 'experience',
        partial: true,
        data: {
          userRole: 'investor',
          registrationMarker: 'experience-save',
        },
      },
    });

    expect(progressDocs).toHaveLength(1);
    expect(progressDocs[0].get('step')).toBe('experience');
    expect(progressDocs[0].get('data').registrationMarker).toBe('experience-save');
  });

  test('skips user save when step is unchanged', async () => {
    user.set('onboardingStep', 'financial');

    await handlers.saveOnboardingProgress({
      user,
      params: {
        step: 'financial',
        partial: true,
        data: { incomeRange: 'middle' },
      },
    });

    expect(userSaveCount).toBe(0);
    expect(progressSaveCount).toBe(1);
  });

  test('position-only save does not overwrite stored progress data', async () => {
    user.set('onboardingStep', 'experience');

    await handlers.saveOnboardingProgress({
      user,
      params: {
        step: 'experience',
        partial: true,
        data: {
          userRole: 'investor',
          registrationMarker: 'experience-save',
        },
      },
    });

    await handlers.saveOnboardingProgress({
      user,
      params: {
        step: 'financial',
        partial: true,
        data: { _positionOnly: true },
      },
    });

    expect(progressDocs[0].get('step')).toBe('financial');
    expect(progressDocs[0].get('data').registrationMarker).toBe('experience-save');
  });

  test('rejects userRole change in progress data after account creation', async () => {
    user.set('role', 'trader');
    user.set('onboardingStep', 'welcome');

    await expect(handlers.saveOnboardingProgress({
      user,
      params: {
        step: 'welcome',
        partial: true,
        data: {
          userRole: 'investor',
          registrationMarker: 'role-change',
        },
      },
    })).rejects.toMatchObject({
      code: 119,
    });

    expect(user.get('role')).toBe('trader');
  });
});
