import { describe, expect, it } from 'vitest';
import {
  complianceEventTypeChipClasses,
  complianceSeverityChipClasses,
} from './complianceBadgeVariants';

describe('complianceSeverityChipClasses', () => {
  it('maps critical and high to different hues', () => {
    const critical = complianceSeverityChipClasses('critical', true);
    const high = complianceSeverityChipClasses('high', true);
    expect(critical).toContain('red');
    expect(high).toContain('orange');
    expect(critical).not.toEqual(high);
  });

  it('maps medium and low distinctly', () => {
    const medium = complianceSeverityChipClasses('medium', true);
    const low = complianceSeverityChipClasses('low', true);
    expect(medium).toContain('amber');
    expect(low).toContain('cyan');
    expect(medium).not.toEqual(low);
  });
});

describe('complianceEventTypeChipClasses', () => {
  it('maps aml_check_failed and large_transaction to different hues', () => {
    const aml = complianceEventTypeChipClasses('aml_check_failed', true);
    const large = complianceEventTypeChipClasses('large_transaction', true);
    expect(aml).toContain('red');
    expect(large).toContain('violet');
    expect(aml).not.toEqual(large);
  });

  it('maps order_placed and escalation to blue vs red', () => {
    const order = complianceEventTypeChipClasses('order_placed', true);
    const escalation = complianceEventTypeChipClasses('escalation', true);
    expect(order).toContain('blue');
    expect(escalation).toContain('red');
    expect(order).not.toEqual(escalation);
  });

  it('maps iOS camelCase trading quartet to blue yellow green red', () => {
    const placed = complianceEventTypeChipClasses('orderPlaced', true);
    const risk = complianceEventTypeChipClasses('riskCheck', true);
    const completed = complianceEventTypeChipClasses('orderCompleted', true);
    const escalation = complianceEventTypeChipClasses('escalation', true);
    expect(placed).toContain('blue');
    expect(risk).toContain('yellow');
    expect(completed).toContain('green');
    expect(escalation).toContain('red');
    expect(new Set([placed, risk, completed, escalation]).size).toBe(4);
  });
});

describe('complianceSeverityChipClasses info', () => {
  it('maps info severity to sky (not slate fallback)', () => {
    const info = complianceSeverityChipClasses('info', true);
    expect(info).toContain('sky');
    expect(info).not.toContain('slate-500/20');
  });
});
