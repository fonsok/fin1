'use strict';

const { isOverrideEffective, isScheduledOverride } = require('../overrideEffectiveFrom');

describe('overrideEffectiveFrom', () => {
  it('treats missing effectiveFrom as immediately effective', () => {
    expect(isOverrideEffective(null)).toBe(true);
    expect(isScheduledOverride(null)).toBe(false);
  });

  it('treats invalid effectiveFrom as immediately effective', () => {
    expect(isOverrideEffective('not-a-date')).toBe(true);
    expect(isScheduledOverride('not-a-date')).toBe(false);
  });

  it('detects future scheduled overrides', () => {
    const future = new Date('2099-01-01');
    const now = new Date('2026-01-01');
    expect(isOverrideEffective(future, now)).toBe(false);
    expect(isScheduledOverride(future, now)).toBe(true);
  });

  it('detects active overrides after effectiveFrom', () => {
    const past = new Date('2020-01-01');
    const now = new Date('2026-01-01');
    expect(isOverrideEffective(past, now)).toBe(true);
    expect(isScheduledOverride(past, now)).toBe(false);
  });
});
