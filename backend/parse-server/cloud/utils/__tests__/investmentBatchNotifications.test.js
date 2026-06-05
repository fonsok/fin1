'use strict';

jest.mock('../../triggers/investmentTriggerHelpers', () => ({
  formatCurrency: jest.fn((n) => `€${n}`),
  createNotification: jest.fn(async () => {}),
  logComplianceEvent: jest.fn(async () => {}),
}));

const {
  createNotification,
  logComplianceEvent,
} = require('../../triggers/investmentTriggerHelpers');

const {
  beginBatchNotificationDefer,
  shouldDeferInvestmentCreatedNotifications,
  recordDeferredSplitNotification,
  flushBatchCreatedNotifications,
  discardDeferredBatchNotifications,
  buildDigestMessages,
} = require('../investmentBatchNotifications');

describe('investmentBatchNotifications', () => {
  beforeEach(() => {
    jest.clearAllMocks();
    discardDeferredBatchNotifications('inv-1', 'batch-1');
  });

  test('shouldDefer while batch is open', () => {
    expect(shouldDeferInvestmentCreatedNotifications('inv-1', 'batch-1')).toBe(false);
    beginBatchNotificationDefer('inv-1', 'batch-1', 'trader-1');
    expect(shouldDeferInvestmentCreatedNotifications('inv-1', 'batch-1')).toBe(true);
  });

  test('buildDigestMessages pluralizes split count', () => {
    const msg = buildDigestMessages({
      splits: [
        { amount: 1000, investmentId: 'a' },
        { amount: 2000, investmentId: 'b' },
      ],
    });
    expect(msg.investorTitle).toBe('Investments reserviert');
    expect(msg.investorBody).toContain('2 Anteile');
    expect(msg.traderBody).toContain('2 Anteile');
    expect(msg.count).toBe(2);
    expect(msg.total).toBe(3000);
  });

  test('flush sends one investor and one trader notification', async () => {
    beginBatchNotificationDefer('inv-1', 'batch-42', 'trader-9');
    recordDeferredSplitNotification('inv-1', 'batch-42', {
      investmentId: 'inv-a',
      amount: 5000,
      investmentNumber: 'INV-1',
    });
    recordDeferredSplitNotification('inv-1', 'batch-42', {
      investmentId: 'inv-b',
      amount: 3000,
      investmentNumber: 'INV-2',
    });

    await flushBatchCreatedNotifications('inv-1', 'batch-42');

    expect(createNotification).toHaveBeenCalledTimes(2);
    expect(createNotification).toHaveBeenCalledWith(
      'inv-1',
      'investment_created',
      'investment',
      'Investments reserviert',
      expect.stringContaining('2 Anteile'),
    );
    expect(logComplianceEvent).toHaveBeenCalledTimes(1);
    expect(shouldDeferInvestmentCreatedNotifications('inv-1', 'batch-42')).toBe(false);
  });

  test('discard prevents flush', async () => {
    beginBatchNotificationDefer('inv-1', 'batch-x', 'trader-1');
    recordDeferredSplitNotification('inv-1', 'batch-x', {
      investmentId: 'inv-z',
      amount: 100,
      investmentNumber: 'INV-Z',
    });
    discardDeferredBatchNotifications('inv-1', 'batch-x');
    await flushBatchCreatedNotifications('inv-1', 'batch-x');
    expect(createNotification).not.toHaveBeenCalled();
  });
});
