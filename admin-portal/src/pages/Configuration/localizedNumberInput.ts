import { formatNumber } from '../../utils/format';

export function formatLocalizedNumericValue(value: number): string {
  const formatted = formatNumber(value);
  return formatted === '-' ? String(value) : formatted;
}

export function parseLocalizedNumberInput(raw: string): number {
  if (!raw) return NaN;
  const cleaned = raw
    .replace(/\s/g, '')
    .replace(/[€%]/g, '')
    .trim();
  if (!cleaned) return NaN;

  if (cleaned.includes(',')) {
    const normalized = cleaned.replace(/\./g, '').replace(',', '.');
    return Number(normalized);
  }
  return Number(cleaned.replace(/\./g, ''));
}

export function formatLocalizedInput(raw: string): string {
  const normalized = raw.replace(/[^\d.,]/g, '');
  if (!normalized) return '';

  const hasComma = normalized.includes(',');
  const hasTrailingComma = normalized.endsWith(',');
  const lastSeparatorIdx = hasComma ? normalized.lastIndexOf(',') : -1;

  const integerPartRaw = lastSeparatorIdx >= 0 ? normalized.slice(0, lastSeparatorIdx) : normalized;
  const fractionPartRaw = lastSeparatorIdx >= 0 ? normalized.slice(lastSeparatorIdx + 1) : '';

  const intDigits = integerPartRaw.replace(/[^\d]/g, '');
  const groupedInt = intDigits ? formatLocalizedNumericValue(Number(intDigits)) : '';

  const fracDigits = fractionPartRaw.replace(/[^\d]/g, '');
  if (lastSeparatorIdx >= 0) {
    if (hasTrailingComma && fracDigits.length === 0) {
      return `${groupedInt},`;
    }
    return fracDigits.length > 0 ? `${groupedInt},${fracDigits}` : groupedInt;
  }

  return groupedInt;
}
