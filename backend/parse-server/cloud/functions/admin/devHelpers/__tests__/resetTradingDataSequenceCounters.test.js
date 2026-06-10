'use strict';

const {
  isTradingSequenceCounterKey,
  resetTradingSequenceCounters,
} = require('../resetTradingDataSequenceCounters');

describe('resetTradingDataSequenceCounters', () => {
  beforeEach(() => {
    jest.resetModules();
  });

  test('isTradingSequenceCounterKey matches INV/CB/ORD/TXN keys', () => {
    expect(isTradingSequenceCounterKey('Investment::investmentNumber::INV::2026::abc')).toBe(true);
    expect(isTradingSequenceCounterKey('Document::accountingDocumentNumber::CB::2026')).toBe(true);
    expect(isTradingSequenceCounterKey('Order::orderNumber::ORD::2026')).toBe(true);
    expect(isTradingSequenceCounterKey('WalletTransaction::transactionNumber::TXN::2026')).toBe(true);
    expect(isTradingSequenceCounterKey('SupportTicket::ticketNumber::TKT::2026')).toBe(false);
  });

  test('resetTradingSequenceCounters dryRun lists keys without delete', async () => {
    const rows = [
      { get: (k) => ({ key: 'Investment::investmentNumber::INV::2026::u1', value: 12 }[k]), id: 's1' },
      { get: (k) => ({ key: 'SupportTicket::ticketNumber::TKT::2026', value: 3 }[k]), id: 's2' },
    ];
    global.Parse = {
      Query: jest.fn().mockImplementation(() => ({
        limit: jest.fn().mockReturnThis(),
        find: jest.fn().mockResolvedValue(rows),
      })),
      Object: { destroyAll: jest.fn() },
    };

    const out = await resetTradingSequenceCounters({ dryRun: true });
    expect(out.wouldDelete).toBe(1);
    expect(out.keys).toEqual([{ key: 'Investment::investmentNumber::INV::2026::u1', value: 12 }]);
    expect(Parse.Object.destroyAll).not.toHaveBeenCalled();
  });

  test('resetTradingSequenceCounters deletes matching rows', async () => {
    const row = { get: (k) => ({ key: 'Order::orderNumber::ORD::2026', value: 99 }[k]), id: 's1' };
    global.Parse = {
      Query: jest.fn().mockImplementation(() => ({
        limit: jest.fn().mockReturnThis(),
        find: jest.fn().mockResolvedValue([row]),
      })),
      Object: { destroyAll: jest.fn().mockResolvedValue(undefined) },
    };

    const out = await resetTradingSequenceCounters({ dryRun: false });
    expect(out.deleted).toBe(1);
    expect(Parse.Object.destroyAll).toHaveBeenCalledWith([row], { useMasterKey: true });
  });
});
