import { describe, expect, it } from 'vitest';
import {
  chipVariantClasses,
  severityToChipVariant,
  templateShortcutChipClasses,
} from './chipVariants';

describe('chipVariantClasses', () => {
  it('uses translucent dark tokens', () => {
    const cls = chipVariantClasses('info', true);
    expect(cls).toContain('/20');
    expect(cls).toContain('/70');
  });
});

describe('templateShortcutChipClasses', () => {
  it('maps resolved shortcuts to emerald accent', () => {
    expect(templateShortcutChipClasses('resolved', true)).toContain('emerald');
  });
});

describe('severityToChipVariant', () => {
  it('maps critical to danger', () => {
    expect(severityToChipVariant('critical')).toBe('danger');
  });
});
