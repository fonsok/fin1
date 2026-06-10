import type { ReactNode } from 'react';
import clsx from 'clsx';
import { Input, Button } from '../ui';
import { useTheme } from '../../context/ThemeContext';
import { adminControlField, adminMuted, adminStrong } from '../../utils/adminThemeClasses';
import { DateRangeFilterFields } from './DateRangeFilterFields';
import type { DateRangePreset } from '../../utils/dateRangePreset';

export interface AdminTableFilterSelect {
  id: string;
  label: string;
  value: string;
  options: { value: string; label: string }[];
  onChange: (value: string) => void;
}

interface AdminTableFilterBarProps {
  searchPlaceholder?: string;
  searchValue?: string;
  onSearchChange?: (value: string) => void;
  selects?: AdminTableFilterSelect[];
  dateRange?: {
    preset: DateRangePreset;
    dateFromInput: string;
    dateToInput: string;
    onPresetChange: (preset: DateRangePreset) => void;
    onDateFromChange: (value: string) => void;
    onDateToChange: (value: string) => void;
  };
  pageSize?: {
    value: number;
    options?: number[];
    onChange: (size: number) => void;
  };
  onReset?: () => void;
  hasActiveFilters?: boolean;
  resultHint?: string;
  trailingContent?: ReactNode;
}

/**
 * Filter row aligned with App Ledger (`AppLedgerPage` filter card):
 * labeled fields, Zeitraum presets, optional live search, reset.
 */
export function AdminTableFilterBar({
  searchPlaceholder,
  searchValue = '',
  onSearchChange,
  selects = [],
  dateRange,
  pageSize,
  onReset,
  hasActiveFilters,
  resultHint,
  trailingContent,
}: AdminTableFilterBarProps): JSX.Element {
  const { theme } = useTheme();
  const isDark = theme === 'dark';
  const formLabel = clsx('block text-sm font-medium mb-1', adminStrong(isDark));
  const controlSm = clsx(
    'w-full border rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-fin1-primary',
    adminControlField(isDark),
  );
  const pageSizeOptions = pageSize?.options ?? [25, 50, 100];

  return (
    <div className="space-y-3">
      <div className="flex flex-col sm:flex-row gap-4 items-end flex-wrap">
        {onSearchChange && searchPlaceholder && (
          <div className="flex-1 min-w-[12rem] w-full sm:w-auto">
            <label className={formLabel}>Suche</label>
            <Input
              placeholder={searchPlaceholder}
              value={searchValue}
              onChange={(e) => onSearchChange(e.target.value)}
              icon={
                <svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24" aria-hidden>
                  <path
                    strokeLinecap="round"
                    strokeLinejoin="round"
                    strokeWidth={2}
                    d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z"
                  />
                </svg>
              }
            />
          </div>
        )}
        {selects.map((filter) => (
          <div key={filter.id} className="flex-1 min-w-[10rem]">
            <label className={formLabel}>{filter.label}</label>
            <select
              value={filter.value}
              onChange={(e) => filter.onChange(e.target.value)}
              className={controlSm}
            >
              {filter.options.map((opt) => (
                <option key={opt.value || '__all__'} value={opt.value}>
                  {opt.label}
                </option>
              ))}
            </select>
          </div>
        ))}
        {trailingContent}
        {dateRange && (
          <DateRangeFilterFields
            preset={dateRange.preset}
            dateFromInput={dateRange.dateFromInput}
            dateToInput={dateRange.dateToInput}
            onPresetChange={dateRange.onPresetChange}
            onDateFromChange={dateRange.onDateFromChange}
            onDateToChange={dateRange.onDateToChange}
            layout="flex"
          />
        )}
        {pageSize && (
          <div className="min-w-[8rem]">
            <label className={formLabel}>Seite</label>
            <select
              value={pageSize.value}
              onChange={(e) => pageSize.onChange(Number(e.target.value))}
              className={controlSm}
            >
              {pageSizeOptions.map((n) => (
                <option key={n} value={n}>
                  {n} / Seite
                </option>
              ))}
            </select>
          </div>
        )}
        {hasActiveFilters && onReset && (
          <Button variant="ghost" onClick={onReset}>
            Filter zurücksetzen
          </Button>
        )}
      </div>
      {resultHint && (
        <p className={clsx('text-sm', adminMuted(isDark))}>{resultHint}</p>
      )}
    </div>
  );
}
