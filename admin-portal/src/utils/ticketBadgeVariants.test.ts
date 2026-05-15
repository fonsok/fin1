import { describe, expect, it } from 'vitest';
import {
  ticketPriorityChipClasses,
  ticketStatusChipClasses,
} from './ticketBadgeVariants';

describe('ticketStatusChipClasses', () => {
  it('uses translucent bg and border in dark mode', () => {
    const open = ticketStatusChipClasses('open', true);
    expect(open).toContain('/20');
    expect(open).toContain('/70');
    expect(open).toContain('sky');
  });

  it('maps open and in_progress to different status hues', () => {
    const open = ticketStatusChipClasses('open', true);
    const progress = ticketStatusChipClasses('in_progress', true);
    expect(open).not.toEqual(progress);
    expect(open).toContain('sky');
    expect(progress).toContain('orange');
  });

  it('is case insensitive', () => {
    expect(ticketStatusChipClasses('OPEN', true)).toBe(ticketStatusChipClasses('open', true));
  });
});

describe('ticketPriorityChipClasses', () => {
  it('uses priority-specific hues distinct from status open', () => {
    const low = ticketPriorityChipClasses('low', true);
    const open = ticketStatusChipClasses('open', true);
    expect(low).toContain('cyan');
    expect(open).toContain('sky');
    expect(low).not.toEqual(open);
  });

  it('maps urgent and high to different variants', () => {
    const urgent = ticketPriorityChipClasses('urgent', true);
    const high = ticketPriorityChipClasses('high', true);
    expect(urgent).toContain('red');
    expect(high).toContain('orange');
    expect(urgent).not.toEqual(high);
  });
});
