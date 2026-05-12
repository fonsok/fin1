'use strict';

// Characterization for existing investorCollectionBill → participation backfill short path.

jest.mock('../settlementBackfill', () => ({
  backfillInvestmentFromBillMetadata: jest.fn().mockResolvedValue(undefined),
  backfillCommissionRecordIfMissing: jest.fn().mockResolvedValue(undefined),
  backfillResidualReturnIfMissing: jest.fn().mockResolvedValue(undefined),
}));

jest.mock('../settlementSupport', () => ({
  createCommissionRecord: jest.fn(),
}));

const settlementBackfill = require('../settlementBackfill');
const { trySettleFromExistingBill } = require('../settlementParticipationBackfill');

class FakeQuery {
  constructor(className) {
    this.className = className;
  }

  equalTo() {
    return this;
  }

  async first() {
    return FakeQuery.documentResult;
  }
}

FakeQuery.documentResult = null;

function makeParticipation(overrides = {}) {
  const attrs = Object.assign({
    isSettled: false,
    profitShare: 0,
    commissionAmount: 0,
    commissionRate: null,
  }, overrides);
  return {
    id: 'ptp-bf-1',
    attrs: { ...attrs },
    get(k) {
      return this.attrs[k];
    },
    set(k, v) {
      this.attrs[k] = v;
    },
    save: jest.fn().mockResolvedValue(undefined),
  };
}

function makeInvestment() {
  return {
    id: 'inv-bf-1',
    get(k) {
      if (k === 'investorId') return 'user-inv-1';
      return undefined;
    },
  };
}

const trade = { id: 'trade-bf-1' };

describe('trySettleFromExistingBill', () => {
  beforeEach(() => {
    jest.clearAllMocks();
    FakeQuery.documentResult = null;
    global.Parse = { Query: FakeQuery };
  });

  afterEach(() => {
    delete global.Parse;
  });

  test('returns null when no collection bill exists', async () => {
    const participation = makeParticipation();
    const investment = makeInvestment();
    const out = await trySettleFromExistingBill({
      participation,
      investment,
      traderId: 'trader-1',
      trade,
      tradeNumber: '1',
      commissionRate: 0.2,
      feeConfig: {},
      tradeBuyPrice: 10,
    });
    expect(out).toBeNull();
    expect(participation.save).not.toHaveBeenCalled();
    expect(settlementBackfill.backfillInvestmentFromBillMetadata).not.toHaveBeenCalled();
  });

  test('uses bill metadata and runs backfill chain', async () => {
    const bill = {
      id: 'doc-bill-1',
      get(k) {
        if (k === 'metadata') {
          return {
            grossProfit: 80,
            commission: 16,
            taxBreakdown: { totalTax: 2 },
          };
        }
        return undefined;
      },
    };
    FakeQuery.documentResult = bill;
    const participation = makeParticipation();
    const investment = makeInvestment();
    const out = await trySettleFromExistingBill({
      participation,
      investment,
      traderId: 'trader-1',
      trade,
      tradeNumber: '1',
      commissionRate: 0.2,
      feeConfig: {},
      tradeBuyPrice: 10,
    });
    expect(out).toEqual({
      investorId: 'user-inv-1',
      investmentId: 'inv-bf-1',
      grossProfit: 80,
      commission: 16,
      taxWithheld: 2,
    });
    expect(participation.save).toHaveBeenCalledTimes(1);
    expect(participation.get('isSettled')).toBe(true);
    expect(participation.get('profitShare')).toBe(80);
    expect(participation.get('commissionAmount')).toBe(16);
    expect(settlementBackfill.backfillInvestmentFromBillMetadata).toHaveBeenCalledWith(
      expect.objectContaining({
        investment,
        bill,
        grossProfit: 80,
        commission: 16,
        netProfit: 64,
      }),
    );
    expect(settlementBackfill.backfillCommissionRecordIfMissing).toHaveBeenCalledWith(
      expect.objectContaining({
        traderId: 'trader-1',
        commission: 16,
      }),
    );
    expect(settlementBackfill.backfillResidualReturnIfMissing).toHaveBeenCalledWith(
      expect.objectContaining({
        investorId: 'user-inv-1',
        investmentId: 'inv-bf-1',
        trade,
        tradeNumber: '1',
        bill,
      }),
    );
  });

  test('falls back to participation fields when bill metadata numbers are not finite', async () => {
    const bill = {
      id: 'doc-bill-2',
      get() {
        return { grossProfit: 'x', commission: NaN };
      },
    };
    FakeQuery.documentResult = bill;
    const participation = makeParticipation({
      profitShare: 50,
      commissionAmount: 10,
    });
    const investment = makeInvestment();
    const out = await trySettleFromExistingBill({
      participation,
      investment,
      traderId: 'trader-1',
      trade,
      tradeNumber: '2',
      commissionRate: 0.15,
      feeConfig: {},
      tradeBuyPrice: 5,
    });
    expect(out.grossProfit).toBe(50);
    expect(out.commission).toBe(10);
    expect(out.taxWithheld).toBe(0);
    expect(settlementBackfill.backfillInvestmentFromBillMetadata).toHaveBeenCalledWith(
      expect.objectContaining({
        grossProfit: 50,
        commission: 10,
        netProfit: 40,
      }),
    );
  });
});
