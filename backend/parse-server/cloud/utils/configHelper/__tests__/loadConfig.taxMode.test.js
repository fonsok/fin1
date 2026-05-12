'use strict';

describe('loadConfig taxCollectionMode normalization', () => {
  beforeEach(() => {
    jest.resetModules();
  });

  test('normalizes invalid taxCollectionMode from persisted config to customer_self_reports', async () => {
    class FakeConfigurationObject {
      constructor(data) {
        this._data = data;
        this.id = 'cfg-1';
      }

      get(key) {
        return this._data[key];
      }
    }

    class FakeQuery {
      equalTo() { return this; }
      descending() { return this; }
      async first() {
        return new FakeConfigurationObject({
          isActive: true,
          tax: {
            withholdingTaxRate: 0.25,
            solidaritySurchargeRate: 0.055,
            vatRate: 0.19,
            taxCollectionMode: 'unexpected_mode',
          },
          limits: {},
          updatedAt: new Date('2026-04-15T00:00:00.000Z'),
        });
      }
    }

    global.Parse = {
      Object: {
        extend: () => function Configuration() {},
      },
      Query: FakeQuery,
    };

    // eslint-disable-next-line global-require
    const { loadConfig } = require('../loadConfig');
    const cfg = await loadConfig(true);

    expect(cfg.tax.taxCollectionMode).toBe('customer_self_reports');
  });
});
