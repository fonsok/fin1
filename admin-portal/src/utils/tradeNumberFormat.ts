const BERLIN_TZ = 'Europe/Berlin';

/** Calendar year in Europe/Berlin (matches iOS / Parse Cloud). */
export function tradeNumberCalendarYear(date: Date = new Date()): number {
  const formatter = new Intl.DateTimeFormat('en-CA', {
    timeZone: BERLIN_TZ,
    year: 'numeric',
  });
  return Number(formatter.format(date));
}

function resolveYear(
  tradeNumberYear?: number | null,
  referenceDate?: string | Date | null,
): number | null {
  const explicit = Number(tradeNumberYear);
  if (Number.isFinite(explicit) && explicit > 0) return explicit;
  if (referenceDate) {
    const ref = referenceDate instanceof Date ? referenceDate : new Date(referenceDate);
    if (!Number.isNaN(ref.getTime())) return tradeNumberCalendarYear(ref);
  }
  return null;
}

/** User-facing trade reference, e.g. `2026-001`. */
export function formatTradeNumber(
  tradeNumber: number | null | undefined,
  tradeNumberYear?: number | null,
  referenceDate?: string | Date | null,
): string {
  const number = Number(tradeNumber);
  if (!Number.isFinite(number) || number <= 0) return '';
  const seq = String(number).padStart(3, '0');
  const year = resolveYear(tradeNumberYear, referenceDate);
  if (year != null && year > 0) return `${year}-${seq}`;
  return seq;
}

export function formatTradeNumberLabel(
  tradeNumber: number | null | undefined,
  tradeNumberYear?: number | null,
  referenceDate?: string | Date | null,
): string {
  const value = formatTradeNumber(tradeNumber, tradeNumberYear, referenceDate);
  return value ? `Trade #${value}` : '';
}

export function formatTradeNumberHash(
  tradeNumber: number | null | undefined,
  tradeNumberYear?: number | null,
  referenceDate?: string | Date | null,
): string {
  const value = formatTradeNumber(tradeNumber, tradeNumberYear, referenceDate);
  return value ? `#${value}` : '';
}
