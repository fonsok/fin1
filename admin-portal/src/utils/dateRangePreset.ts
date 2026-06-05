/** Shared date-range presets (App Ledger, Summary Report, …). */
export type DateRangePreset =
  | 'all'
  | 'thisMonth'
  | 'lastMonth'
  | 'thisYear'
  | 'last30Days'
  | 'custom';

export function toYMD(date: Date): string {
  const year = date.getFullYear();
  const month = String(date.getMonth() + 1).padStart(2, '0');
  const day = String(date.getDate()).padStart(2, '0');
  return `${year}-${month}-${day}`;
}

export function resolveDateRange(
  datePreset: DateRangePreset,
  dateFromInput: string,
  dateToInput: string,
): { from?: string; to?: string } {
  const now = new Date();
  const today = new Date(now.getFullYear(), now.getMonth(), now.getDate());

  if (datePreset === 'all') return {};
  if (datePreset === 'custom') {
    return { from: dateFromInput || undefined, to: dateToInput || undefined };
  }
  if (datePreset === 'thisMonth') {
    return {
      from: toYMD(new Date(today.getFullYear(), today.getMonth(), 1)),
      to: toYMD(today),
    };
  }
  if (datePreset === 'lastMonth') {
    const start = new Date(today.getFullYear(), today.getMonth() - 1, 1);
    const end = new Date(today.getFullYear(), today.getMonth(), 0);
    return { from: toYMD(start), to: toYMD(end) };
  }
  if (datePreset === 'thisYear') {
    return { from: toYMD(new Date(today.getFullYear(), 0, 1)), to: toYMD(today) };
  }
  if (datePreset === 'last30Days') {
    const start = new Date(today);
    start.setDate(start.getDate() - 29);
    return { from: toYMD(start), to: toYMD(today) };
  }
  return {};
}

/** Parse Cloud list endpoints expect ISO `dateFrom` / `dateTo`. */
export function dateRangePresetToApiParams(
  datePreset: DateRangePreset,
  dateFromInput: string,
  dateToInput: string,
): Record<string, string> {
  const { from, to } = resolveDateRange(datePreset, dateFromInput, dateToInput);
  const out: Record<string, string> = {};
  if (from) out.dateFrom = `${from}T00:00:00.000Z`;
  if (to) out.dateTo = `${to}T23:59:59.999Z`;
  return out;
}

export function isDateRangeFilterActive(
  datePreset: DateRangePreset,
  dateFromInput: string,
  dateToInput: string,
): boolean {
  return datePreset !== 'all' || Boolean(dateFromInput.trim() || dateToInput.trim());
}
