'use strict';

const {
  findExistingStatementEntry,
  sumStatementAmounts,
  getStatementSumsByType,
  prefetchInvestmentsById,
} = require('../settlementQueries');

class FakeQuery {
  constructor(className) {
    this.className = className;
  }

  equalTo() {
    return this;
  }

  containedIn() {
    return this;
  }

  limit() {
    return this;
  }

  async first() {
    return FakeQuery.firstResult;
  }

  async find() {
    return FakeQuery.findResults;
  }
}

FakeQuery.firstResult = null;
FakeQuery.findResults = [];

function row(entryType, amount) {
  return {
    get(k) {
      if (k === 'entryType') return entryType;
      if (k === 'amount') return amount;
      return undefined;
    },
  };
}

describe('settlementQueries', () => {
  beforeEach(() => {
    FakeQuery.firstResult = null;
    FakeQuery.findResults = [];
    global.Parse = { Query: FakeQuery };
  });

  afterEach(() => {
    delete global.Parse;
  });

  test('findExistingStatementEntry returns first() result', async () => {
    FakeQuery.firstResult = { id: 's1' };
    const r = await findExistingStatementEntry({
      userId: 'u1',
      tradeId: 't1',
      entryType: 'trade_buy',
    });
    expect(r).toEqual({ id: 's1' });
  });

  test('findExistingStatementEntry returns null when args missing', async () => {
    expect(await findExistingStatementEntry({ userId: '', tradeId: 't', entryType: 'x' })).toBeNull();
  });

  test('sumStatementAmounts returns 0 when args missing', async () => {
    expect(await sumStatementAmounts({ userId: 'u', tradeId: '', entryType: 'x' })).toBe(0);
  });

  test('sumStatementAmounts sums amounts with optional investmentId filter path', async () => {
    FakeQuery.findResults = [row('investment_return', 100), row('investment_return', -30.5)];
    const sum = await sumStatementAmounts({
      userId: 'u1',
      tradeId: 't1',
      investmentId: 'inv-1',
      entryType: 'investment_return',
      absolute: false,
    });
    expect(sum).toBe(69.5);
  });

  test('sumStatementAmounts absolute uses abs of total', async () => {
    FakeQuery.findResults = [row('commission_debit', -40)];
    const sum = await sumStatementAmounts({
      userId: 'u1',
      tradeId: 't1',
      entryType: 'commission_debit',
      absolute: true,
    });
    expect(sum).toBe(40);
  });

  test('getStatementSumsByType returns empty object for invalid entryTypes', async () => {
    expect(await getStatementSumsByType({
      userId: 'u1',
      tradeId: 't1',
      entryTypes: [],
    })).toEqual({});
  });

  test('getStatementSumsByType buckets by entryType', async () => {
    FakeQuery.findResults = [
      row('withholding_tax_debit', -10),
      row('withholding_tax_debit', -2),
      row('solidarity_surcharge_debit', -1),
    ];
    const sums = await getStatementSumsByType({
      userId: 'u1',
      tradeId: 't1',
      investmentId: 'inv-1',
      entryTypes: ['withholding_tax_debit', 'solidarity_surcharge_debit', 'church_tax_debit'],
      absolute: true,
    });
    expect(sums.withholding_tax_debit).toBe(12);
    expect(sums.solidarity_surcharge_debit).toBe(1);
    expect(sums.church_tax_debit).toBe(0);
  });

  test('prefetchInvestmentsById returns empty map for empty input', async () => {
    const m = await prefetchInvestmentsById([]);
    expect(m.size).toBe(0);
  });

  test('prefetchInvestmentsById loads investments by objectId', async () => {
    const p1 = { get: (k) => (k === 'investmentId' ? 'abc123' : undefined) };
    const inv = { id: 'abc123', get: () => 'x' };
    FakeQuery.findResults = [inv];
    const m = await prefetchInvestmentsById([p1]);
    expect(m.get('abc123')).toBe(inv);
  });
});
