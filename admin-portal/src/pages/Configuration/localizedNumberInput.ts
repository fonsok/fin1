import { formatNumber } from '../../utils/format';

/** German thousands grouping without decimal comma (e.g. `1.000`, `10.000`). */
function isThousandSeparatedString(value: string): boolean {
  return /^\d{1,3}(\.\d{3})+$/.test(value);
}

/** JS/JSON decimal string (e.g. `0.1`) — dot is the decimal separator, not thousands. */
function isDotDecimalString(value: string): boolean {
  return /^\d*\.\d+$/.test(value) && !isThousandSeparatedString(value);
}

export function formatLocalizedNumericValue(value: number): string {
  const formatted = formatNumber(value);
  return formatted === '-' ? String(value) : formatted;
}

export function formatRateInputFromNumber(value: number): string {
  if (!Number.isFinite(value)) return '';
  return formatLocalizedInput(String(value));
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
  if (isDotDecimalString(cleaned)) {
    return Number(cleaned);
  }
  return Number(cleaned.replace(/\./g, ''));
}

export function formatLocalizedInput(raw: string): string {
  const normalized = raw.replace(/[^\d.,]/g, '');
  if (!normalized) return '';

  if (!normalized.includes(',') && isDotDecimalString(normalized)) {
    const dotIdx = normalized.indexOf('.');
    const intPart = normalized.slice(0, dotIdx) || '0';
    const fracPart = normalized.slice(dotIdx + 1);
    return fracPart ? `${intPart},${fracPart}` : intPart;
  }

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
