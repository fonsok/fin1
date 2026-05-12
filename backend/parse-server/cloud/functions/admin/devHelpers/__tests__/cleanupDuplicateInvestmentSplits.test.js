'use strict';

const {
  statusRank,
  compareInvestmentPriority,
  classifyDuplicateGroup,
} = require('../cleanupDuplicateInvestmentSplits');

function makeInv({
  id,
  status,
  createdAt = '2026-01-01T00:00:00.000Z',
  updatedAt = '2026-01-01T00:00:00.000Z',
}) {
  return {
    id,
    createdAt: new Date(createdAt),
    updatedAt: new Date(updatedAt),
    get(key) {
      if (key === 'status') return status;
      return undefined;
    },
  };
}

describe('cleanupDuplicateInvestmentSplits helpers', () => {
  test('statusRank orders lifecycle conservatively', () => {
    expect(statusRank('completed')).toBeGreaterThan(statusRank('active'));
    expect(statusRank('active')).toBeGreaterThan(statusRank('reserved'));
    expect(statusRank('reserved')).toBeGreaterThan(statusRank('cancelled'));
  });

  test('compareInvestmentPriority prefers stronger status first', () => {
    const active = makeInv({ id: 'a', status: 'active' });
    const reserved = makeInv({ id: 'r', status: 'reserved' });
    expect(compareInvestmentPriority(active, reserved)).toBeLessThan(0);
  });

  test('classifyDuplicateGroup removes only stale reserved rows', () => {
    const keep = makeInv({ id: 'new-active', status: 'active', updatedAt: '2026-01-02T00:00:00.000Z' });
    const staleReserved = makeInv({ id: 'old-res', status: 'reserved', updatedAt: '2026-01-01T00:00:00.000Z' });
    const secondActive = makeInv({ id: 'old-active', status: 'active', updatedAt: '2025-12-31T00:00:00.000Z' });

    const result = classifyDuplicateGroup([staleReserved, keep, secondActive]);
    expect(result.keep.id).toBe('new-active');
    expect(result.removable.map((x) => x.id)).toEqual(['old-res']);
    expect(result.reviewOnly.map((x) => x.id)).toEqual(['old-active']);
  });
});
