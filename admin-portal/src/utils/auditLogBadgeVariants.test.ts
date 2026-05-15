import { describe, expect, it } from 'vitest';
import { auditLogTypeChipClasses } from './auditLogBadgeVariants';

describe('auditLogTypeChipClasses', () => {
  it('uses translucent bg and border in dark mode', () => {
    const cls = auditLogTypeChipClasses('data_access', true);
    expect(cls).toContain('/20');
    expect(cls).toContain('/70');
    expect(cls).toContain('cyan');
  });

  it('maps data_access and action to different hues', () => {
    const dataAccess = auditLogTypeChipClasses('data_access', true);
    const action = auditLogTypeChipClasses('action', true);
    expect(dataAccess).not.toEqual(action);
    expect(dataAccess).toContain('cyan');
    expect(action).toContain('orange');
  });

  it('maps admin_customer_view distinctly from data_access', () => {
    const portal = auditLogTypeChipClasses('admin_customer_view', true);
    const dataAccess = auditLogTypeChipClasses('data_access', true);
    expect(portal).toContain('sky');
    expect(portal).not.toEqual(dataAccess);
  });
});
