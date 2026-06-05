'use strict';

function buildMockParse() {
  const store = {
    investments: [
      { id: 'inv1', traderId: 'traderA', traderUsername: null },
      { id: 'inv2', traderId: 'traderB', traderUsername: '' },
      { id: 'inv3', traderId: 'traderA', traderUsername: 'existing' },
    ],
    users: [
      { id: 'traderA', username: 'jbecker' },
      { id: 'traderB', username: 'awolf' },
    ],
  };

  class MockQuery {
    constructor(className) {
      this.className = className;
      this.filters = [];
      this._limit = 100;
      this._skip = 0;
    }
    doesNotExist(field) {
      this.filters.push({ type: 'missing', field });
      return this;
    }
    equalTo(field, value) {
      this.filters.push({ type: 'eq', field, value });
      return this;
    }
    containedIn(field, values) {
      this.filters.push({ type: 'in', field, values });
      return this;
    }
    limit(n) {
      this._limit = n;
      return this;
    }
    skip(n) {
      this._skip = n;
      return this;
    }
    ascending() { return this; }
    async find() {
      if (this.className === '_User') {
        const ids = this.filters.find((f) => f.type === 'in')?.values || [];
        return ids
          .map((id) => store.users.find((u) => u.id === id))
          .filter(Boolean)
          .map((u) => ({
            id: u.id,
            get: (k) => (k === 'username' ? u.username : undefined),
          }));
      }
      let rows = store.investments.map((inv) => ({
        id: inv.id,
        get: (k) => inv[k],
        set: (k, v) => { inv[k] = v; },
      }));
      const orFilters = this._orFilters;
      if (orFilters) {
        rows = rows.filter((row) => orFilters.some((qf) => matches(row, qf)));
      } else {
        rows = rows.filter((row) => this.filters.every((qf) => matches(row, qf)));
      }
      const offset = this._skip || 0;
      return rows.slice(offset, offset + this._limit);
    }
    async count() {
      const rows = await this.find();
      return rows.length;
    }
    static or(...queries) {
      const combined = new MockQuery('Investment');
      combined._orFilters = queries.flatMap((q) => q.filters);
      combined._limit = queries[0]?._limit ?? 100;
      combined._skip = queries[0]?._skip ?? 0;
      return combined;
    }
  }

  function matches(row, filter) {
    const val = row.get(filter.field);
    if (filter.type === 'missing') return val == null || val === '';
    if (filter.type === 'eq') return val === filter.value;
    return true;
  }

  return {
    Query: MockQuery,
    User: '_User',
    Object: {
      saveAll: async (objs) => {
        objs.forEach((o) => {
          const inv = store.investments.find((i) => i.id === o.id);
          if (inv) inv.traderUsername = o.get('traderUsername');
        });
      },
    },
  };
}

global.Parse = buildMockParse();

const { backfillInvestmentTraderUsername } = require('../backfillInvestmentTraderUsername');

describe('backfillInvestmentTraderUsername', () => {
  test('fills missing usernames from trader Parse users', async () => {
    const result = await backfillInvestmentTraderUsername();
    expect(result.updated).toBe(2);
    expect(result.ok).toBe(true);
  });
});
