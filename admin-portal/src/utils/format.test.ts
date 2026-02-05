import { describe, it, expect } from 'vitest';
import {
  formatDateTime,
  formatCurrency,
  formatDate,
  formatRelative,
  formatNumber,
  truncate,
  getStatusColor,
  getRoleDisplay,
  getStatusDisplay,
} from './format';

describe('formatDateTime', () => {
  it('formats valid ISO date string', () => {
    const result = formatDateTime('2026-02-02T14:30:00Z');
    expect(result).toMatch(/02\.02\.2026/);
    expect(result).toMatch(/\d{2}:\d{2}/);
  });

  it('formats Date object', () => {
    const date = new Date('2026-02-02T14:30:00Z');
    const result = formatDateTime(date);
    expect(result).toMatch(/02\.02\.2026/);
  });

  it('returns dash for invalid date', () => {
    expect(formatDateTime('invalid')).toBe('-');
    expect(formatDateTime('')).toBe('-');
    expect(formatDateTime(null)).toBe('-');
    expect(formatDateTime(undefined)).toBe('-');
  });
});

describe('formatDate', () => {
  it('formats valid date string', () => {
    const result = formatDate('2026-02-02');
    expect(result).toMatch(/02\.02\.2026/);
  });

  it('formats Date object', () => {
    const date = new Date('2026-06-15');
    const result = formatDate(date);
    expect(result).toMatch(/15\.06\.2026/);
  });

  it('returns dash for invalid date', () => {
    expect(formatDate('invalid')).toBe('-');
    expect(formatDate(null)).toBe('-');
    expect(formatDate(undefined)).toBe('-');
  });
});

describe('formatRelative', () => {
  it('formats recent date as relative time', () => {
    const recentDate = new Date();
    recentDate.setMinutes(recentDate.getMinutes() - 5);
    const result = formatRelative(recentDate);
    expect(result).toMatch(/Minuten|gerade/i);
  });

  it('formats Date object', () => {
    const date = new Date();
    date.setHours(date.getHours() - 2);
    const result = formatRelative(date);
    expect(result).toMatch(/Stunden|vor/i);
  });

  it('returns dash for invalid date', () => {
    expect(formatRelative('invalid')).toBe('-');
    expect(formatRelative(null)).toBe('-');
    expect(formatRelative(undefined)).toBe('-');
  });
});

describe('formatCurrency', () => {
  it('formats positive numbers', () => {
    const result = formatCurrency(1234.56);
    expect(result).toMatch(/1[\.,]?234/);
    expect(result).toMatch(/€/);
  });

  it('formats zero', () => {
    const result = formatCurrency(0);
    expect(result).toMatch(/0/);
    expect(result).toMatch(/€/);
  });

  it('formats negative numbers', () => {
    const result = formatCurrency(-100);
    expect(result).toMatch(/-/);
  });

  it('returns dash for undefined', () => {
    expect(formatCurrency(undefined)).toBe('-');
  });
});

describe('formatNumber', () => {
  it('formats integers', () => {
    const result = formatNumber(1234567);
    expect(result).toMatch(/1[\.,]?234[\.,]?567/);
  });

  it('formats decimals', () => {
    const result = formatNumber(1234.56);
    expect(result).toMatch(/1[\.,]?234/);
  });

  it('formats zero', () => {
    expect(formatNumber(0)).toBe('0');
  });

  it('returns dash for undefined', () => {
    expect(formatNumber(undefined)).toBe('-');
  });
});

describe('truncate', () => {
  it('does not truncate short text', () => {
    expect(truncate('Hello', 10)).toBe('Hello');
  });

  it('truncates long text with ellipsis', () => {
    expect(truncate('Hello World!', 8)).toBe('Hello...');
  });

  it('handles exact length', () => {
    expect(truncate('Hello', 5)).toBe('Hello');
  });

  it('handles empty string', () => {
    expect(truncate('', 10)).toBe('');
  });
});

describe('getStatusColor', () => {
  it('returns success for active', () => {
    expect(getStatusColor('active')).toBe('badge-success');
  });

  it('returns warning for pending', () => {
    expect(getStatusColor('pending')).toBe('badge-warning');
  });

  it('returns danger for suspended', () => {
    expect(getStatusColor('suspended')).toBe('badge-danger');
  });

  it('returns danger for locked', () => {
    expect(getStatusColor('locked')).toBe('badge-danger');
  });

  it('returns neutral for closed', () => {
    expect(getStatusColor('closed')).toBe('badge-neutral');
  });

  it('returns info for in_progress', () => {
    expect(getStatusColor('in_progress')).toBe('badge-info');
  });

  it('returns danger for critical', () => {
    expect(getStatusColor('critical')).toBe('badge-danger');
  });

  it('returns neutral for unknown status', () => {
    expect(getStatusColor('unknown')).toBe('badge-neutral');
  });

  it('is case insensitive', () => {
    expect(getStatusColor('ACTIVE')).toBe('badge-success');
    expect(getStatusColor('Pending')).toBe('badge-warning');
  });
});

describe('getRoleDisplay', () => {
  it('returns German label for admin', () => {
    expect(getRoleDisplay('admin')).toBe('Administrator');
  });

  it('returns German label for business_admin', () => {
    expect(getRoleDisplay('business_admin')).toBe('Finance Admin');
  });

  it('returns German label for security_officer', () => {
    expect(getRoleDisplay('security_officer')).toBe('Security Officer');
  });

  it('returns German label for compliance', () => {
    expect(getRoleDisplay('compliance')).toBe('Compliance');
  });

  it('returns German label for customer_service', () => {
    expect(getRoleDisplay('customer_service')).toBe('Kundenservice');
  });

  it('returns German label for investor', () => {
    expect(getRoleDisplay('investor')).toBe('Anleger');
  });

  it('returns German label for trader', () => {
    expect(getRoleDisplay('trader')).toBe('Händler');
  });

  it('returns original for unknown role', () => {
    expect(getRoleDisplay('unknown_role')).toBe('unknown_role');
  });
});

describe('getStatusDisplay', () => {
  it('returns German label for active', () => {
    expect(getStatusDisplay('active')).toBe('Aktiv');
  });

  it('returns German label for pending', () => {
    expect(getStatusDisplay('pending')).toBe('Ausstehend');
  });

  it('returns German label for suspended', () => {
    expect(getStatusDisplay('suspended')).toBe('Gesperrt');
  });

  it('returns German label for open', () => {
    expect(getStatusDisplay('open')).toBe('Offen');
  });

  it('returns German label for in_progress', () => {
    expect(getStatusDisplay('in_progress')).toBe('In Bearbeitung');
  });

  it('returns German label for resolved', () => {
    expect(getStatusDisplay('resolved')).toBe('Gelöst');
  });

  it('returns German label for approved', () => {
    expect(getStatusDisplay('approved')).toBe('Genehmigt');
  });

  it('returns German label for rejected', () => {
    expect(getStatusDisplay('rejected')).toBe('Abgelehnt');
  });

  it('returns German label for verified', () => {
    expect(getStatusDisplay('verified')).toBe('Verifiziert');
  });

  it('is case insensitive', () => {
    expect(getStatusDisplay('ACTIVE')).toBe('Aktiv');
    expect(getStatusDisplay('Pending')).toBe('Ausstehend');
  });

  it('returns original for unknown status', () => {
    expect(getStatusDisplay('unknown')).toBe('unknown');
  });
});
