'use strict';

const auditCalls = [];
jest.mock('../../../utils/structuredLogger', () => ({
  audit: {
    info: (event, fields) => auditCalls.push({ event, fields }),
    warn: jest.fn(),
    error: jest.fn(),
  },
}));

const { verifyAccountStatementChainRows, handleVerifyAccountStatementChain } = require('../financialVerifyAccountStatementChain');

describe('verifyAccountStatementChainRows', () => {
  test('empty array is valid', () => {
    const r = verifyAccountStatementChainRows([]);
    expect(r.validChain).toBe(true);
    expect(r.entryCount).toBe(0);
    expect(r.sumMatchesLastClosing).toBe(true);
  });

  test('single row with correct arithmetic', () => {
    const r = verifyAccountStatementChainRows([
      { objectId: 'a', balanceBefore: 0, balanceAfter: 100, amount: 100 },
    ]);
    expect(r.validChain).toBe(true);
    expect(r.chainBreakCount).toBe(0);
    expect(r.arithmeticBreakCount).toBe(0);
    expect(r.sumMatchesLastClosing).toBe(true);
  });

  test('single row with arithmetic mismatch', () => {
    const r = verifyAccountStatementChainRows([
      { objectId: 'a', balanceBefore: 0, balanceAfter: 99, amount: 100 },
    ]);
    expect(r.validChain).toBe(false);
    expect(r.arithmeticBreakCount).toBe(1);
    expect(r.firstArithmeticBreak.reason).toBe('balance_after_mismatch');
  });

  test('two linked rows pass', () => {
    const r = verifyAccountStatementChainRows([
      { objectId: 'a', balanceBefore: 0, balanceAfter: 100, amount: 100 },
      { objectId: 'b', balanceBefore: 100, balanceAfter: 75, amount: -25 },
    ]);
    expect(r.validChain).toBe(true);
    expect(r.lastBalanceAfter).toBe(75);
    expect(r.sumMatchesLastClosing).toBe(true);
  });

  test('detects chain break between rows', () => {
    const r = verifyAccountStatementChainRows([
      { objectId: 'a', balanceBefore: 0, balanceAfter: 100, amount: 100, entryType: 'deposit' },
      { objectId: 'b', balanceBefore: 80, balanceAfter: 55, amount: -25, entryType: 'commission_debit' },
    ]);
    expect(r.validChain).toBe(false);
    expect(r.chainBreakCount).toBe(1);
    expect(r.firstChainBreak.expectedBalanceBefore).toBe(100);
    expect(r.firstChainBreak.actualBalanceBefore).toBe(80);
    expect(r.firstChainBreak.previousObjectId).toBe('a');
  });

  test('sub-cent drift within tolerance is ok', () => {
    const r = verifyAccountStatementChainRows([
      { objectId: 'a', balanceBefore: 0, balanceAfter: 100.002, amount: 100.002 },
      { objectId: 'b', balanceBefore: 100.001, balanceAfter: 50, amount: -50.001 },
    ]);
    expect(r.validChain).toBe(true);
  });
});

describe('handleVerifyAccountStatementChain', () => {
  beforeEach(() => {
    auditCalls.length = 0;
  });

  test('throws when userId missing', async () => {
    class ParseError extends Error {
      constructor(code, message) {
        super(message);
        this.code = code;
      }
    }
    ParseError.INVALID_VALUE = 142;
    global.Parse = { Error: ParseError };
    await expect(handleVerifyAccountStatementChain({ params: {} })).rejects.toThrow('userId is required');
  });

  test('loads rows and returns merged result + audit', async () => {
    const stored = [
      { id: 'x1', userId: 'u1', createdAt: new Date('2020-01-01'), objectId: 'x1', balanceBefore: 0, balanceAfter: 10, amount: 10, entryType: 'deposit' },
      { id: 'x2', userId: 'u1', createdAt: new Date('2020-01-02'), objectId: 'x2', balanceBefore: 10, balanceAfter: 5, amount: -5, entryType: 'withdrawal' },
    ];

    class FakeQuery {
      constructor() {
        this.userId = null;
        this.skipVal = 0;
        this.limitVal = 1000;
      }
      equalTo(field, value) {
        if (field === 'userId') this.userId = value;
        return this;
      }
      ascending() { return this; }
      addAscending() { return this; }
      limit(n) { this.limitVal = n; return this; }
      skip(n) { this.skipVal = n; return this; }
      async find() {
        const rows = stored
          .filter((r) => r.userId === this.userId)
          .sort((a, b) => {
            const ta = a.createdAt.getTime();
            const tb = b.createdAt.getTime();
            if (ta !== tb) return ta - tb;
            return String(a.objectId).localeCompare(String(b.objectId));
          });
        return rows.slice(this.skipVal, this.skipVal + this.limitVal).map((r) => ({
          id: r.id,
          get(k) {
            if (k === 'createdAt') return r.createdAt;
            return r[k];
          },
        }));
      }
    }

    class ParseError extends Error {
      constructor(code, message) {
        super(message);
        this.code = code;
      }
    }
    ParseError.INVALID_VALUE = 142;

    global.Parse = {
      Error: ParseError,
      Query: FakeQuery,
    };

    const out = await handleVerifyAccountStatementChain({ params: { userId: 'u1' } });

    expect(out.userId).toBe('u1');
    expect(out.entryCount).toBe(2);
    expect(out.validChain).toBe(true);
    expect(auditCalls.some((c) => c.event === 'admin.accountstatement.verifyChain' && c.fields.userId === 'u1')).toBe(true);
  });
});
