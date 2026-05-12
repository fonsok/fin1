'use strict';

describe('applyConfigurationChange taxCollectionMode guardrail', () => {
  beforeEach(() => {
    jest.resetModules();
  });

  test('normalizes invalid taxCollectionMode to customer_self_reports when applying changes', async () => {
    const savedState = {
      tax: {
        withholdingTaxRate: 0.25,
        solidaritySurchargeRate: 0.055,
        vatRate: 0.19,
      },
    };

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
      equalTo() { return this; }
      descending() { return this; }
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

    await applyConfigurationChange('taxCollectionMode', 'not_allowed_mode', 'admin-user-1');

    expect(savedState.tax.taxCollectionMode).toBe('customer_self_reports');
    expect(consoleSpy).toHaveBeenCalledWith(
      "✅ Configuration 'taxCollectionMode' updated to customer_self_reports by admin-user-1",
    );
    consoleSpy.mockRestore();
  });
});
