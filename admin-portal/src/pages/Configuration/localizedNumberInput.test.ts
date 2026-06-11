import { describe, it, expect } from 'vitest';
import {
  formatLocalizedInput,
  formatRateInputFromNumber,
  parseLocalizedNumberInput,
} from './localizedNumberInput';

describe('localizedNumberInput rates', () => {
  it('formats JS decimal 0.1 as German rate input 0,1', () => {
    expect(formatLocalizedInput('0.1')).toBe('0,1');
    expect(formatRateInputFromNumber(0.1)).toBe('0,1');
  });

  it('formats JS decimal 0.05 as German rate input 0,05', () => {
    expect(formatLocalizedInput('0.05')).toBe('0,05');
    expect(formatRateInputFromNumber(0.05)).toBe('0,05');
  });

  it('parses dot-decimal strings as rates not thousands', () => {
    expect(parseLocalizedNumberInput('0.1')).toBe(0.1);
    expect(parseLocalizedNumberInput('0.05')).toBe(0.05);
  });

  it('parses German comma decimals', () => {
    expect(parseLocalizedNumberInput('0,1')).toBe(0.1);
    expect(parseLocalizedNumberInput('0,05')).toBe(0.05);
  });

  it('still parses thousand-separated amounts without comma', () => {
    expect(parseLocalizedNumberInput('1.000')).toBe(1000);
  });
});
