'use strict';

const { rejectDeprecatedUpdateConfig, DEPRECATED_UPDATE_CONFIG_MESSAGE } = require('../rejectDeprecatedUpdateConfig');

describe('rejectDeprecatedUpdateConfig', () => {
  beforeEach(() => {
    global.Parse = {
      Error: class ParseError extends Error {
        constructor(code, message) {
          super(message);
          this.code = code;
        }

        static get INVALID_SESSION_TOKEN() {
          return 209;
        }

        static get OPERATION_FORBIDDEN() {
          return 119;
        }
      },
    };
  });

  test('requires login', () => {
    expect(() => rejectDeprecatedUpdateConfig({})).toThrow(/Login required/i);
  });

  test('rejects authenticated legacy updateConfig calls', () => {
    expect(() => rejectDeprecatedUpdateConfig({ user: { id: 'admin-1' } })).toThrow(
      DEPRECATED_UPDATE_CONFIG_MESSAGE,
    );
  });
});
