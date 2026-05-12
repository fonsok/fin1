'use strict';

describe('applyConfigurationChange legalAppName trimming', () => {
  beforeEach(() => {
    jest.resetModules();
  });

  test('trims legalAppName before persisting', async () => {
    const savedState = {};

    class FakeConfigurationObject {
      constructor() {
        this._data = { ...savedState };
        this.id = 'cfg-1';
      }

      get(key) {
        return this._data[key];
      }

      set(key, value) {
        this._data[key] = value;
      }

      async save() {
        Object.assign(savedState, this._data);
        return this;
      }
    }

    const fakeConfig = new FakeConfigurationObject();

    class FakeQuery {
      equalTo() {
        return this;
      }

      descending() {
        return this;
      }

      async first() {
        return fakeConfig;
      }
    }

    global.Parse = {
      Object: {
        extend: () => FakeConfigurationObject,
      },
      Query: FakeQuery,
    };

    const consoleSpy = jest.spyOn(console, 'log').mockImplementation(() => {});

    // eslint-disable-next-line global-require
    const { applyConfigurationChange } = require('../shared');

    await applyConfigurationChange('legalAppName', '  FIN1  ', 'admin-user-1');

    expect(savedState.legalAppName).toBe('FIN1');
    expect(consoleSpy).toHaveBeenCalledWith(
      "✅ Configuration 'legalAppName' updated to FIN1 by admin-user-1",
    );
    consoleSpy.mockRestore();
  });
});
