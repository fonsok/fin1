'use strict';

const mockInspect = jest.fn();

jest.mock('../../../utils/accountingHelper/traderCollectionBillBelegSnapshot/belegDriftInspect', () => ({
  inspectTraderCollectionBillBelegDrift: (...args) => mockInspect(...args),
}));

const { handleGetTraderCollectionBillBelegDriftStatus } = require('../opsHealthTraderCollectionBillBelegDrift');

describe('getTraderCollectionBillBelegDriftStatus', () => {
  beforeEach(() => {
    mockInspect.mockReset();
  });

  test('returns healthy when no drift', async () => {
    mockInspect.mockResolvedValue({
      checkedAt: new Date().toISOString(),
      examined: 10,
      healthy: 10,
      needsBackfill: 0,
      drifted: 0,
      samples: [],
      repairHint: 'hint',
    });

    const out = await handleGetTraderCollectionBillBelegDriftStatus({ params: { limit: 10 } });
    expect(out.overall).toBe('healthy');
    expect(out.driftedDocuments).toBe(0);
    expect(out.reason).toBeNull();
  });

  test('returns degraded when drift detected', async () => {
    mockInspect.mockResolvedValue({
      checkedAt: new Date().toISOString(),
      examined: 5,
      healthy: 3,
      needsBackfill: 1,
      drifted: 1,
      samples: [{ objectId: 'doc-1', status: 'drifted', drifts: [{ field: 'quantity' }] }],
      repairHint: 'hint',
    });

    const out = await handleGetTraderCollectionBillBelegDriftStatus({ params: {} });
    expect(out.overall).toBe('degraded');
    expect(out.driftedDocuments).toBe(1);
    expect(out.driftSamples).toHaveLength(1);
    expect(out.reason).toContain('drift');
  });
});
