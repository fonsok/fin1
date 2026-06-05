import clsx from 'clsx';
import { useTheme } from '../../context/ThemeContext';
import { adminControlField, adminStrong } from '../../utils/adminThemeClasses';
import type { DateRangePreset } from '../../utils/dateRangePreset';

interface DateRangeFilterFieldsProps {
  preset: DateRangePreset;
  dateFromInput: string;
  dateToInput: string;
  onPresetChange: (preset: DateRangePreset) => void;
  onDateFromChange: (value: string) => void;
  onDateToChange: (value: string) => void;
  /** App Ledger uses flex-1; Summary Report filter row uses fixed min width. */
  layout?: 'flex' | 'compact';
}

export function DateRangeFilterFields({
  preset,
  dateFromInput,
  dateToInput,
  onPresetChange,
  onDateFromChange,
  onDateToChange,
  layout = 'flex',
}: DateRangeFilterFieldsProps): JSX.Element {
  const { theme } = useTheme();
  const isDark = theme === 'dark';
  const formLabel = clsx('block text-sm font-medium mb-1', adminStrong(isDark));
  const controlSm = clsx(
    'w-full border rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-fin1-primary',
    adminControlField(isDark),
  );
  const wrapClass = layout === 'flex' ? 'flex-1 min-w-[10rem]' : 'min-w-[10rem]';

  return (
    <>
      <div className={wrapClass}>
        <label className={formLabel}>Zeitraum</label>
        <select
          value={preset}
          onChange={(e) => onPresetChange(e.target.value as DateRangePreset)}
          className={controlSm}
        >
          <option value="all">Alle</option>
          <option value="thisMonth">Aktueller Monat</option>
          <option value="lastMonth">Letzter Monat</option>
          <option value="last30Days">Letzte 30 Tage</option>
          <option value="thisYear">Aktuelles Jahr</option>
          <option value="custom">Benutzerdefiniert (Von/Bis)</option>
        </select>
      </div>
      {preset === 'custom' && (
        <>
          <div className={wrapClass}>
            <label className={formLabel}>Von</label>
            <input
              type="date"
              value={dateFromInput}
              onChange={(e) => onDateFromChange(e.target.value)}
              className={controlSm}
            />
          </div>
          <div className={wrapClass}>
            <label className={formLabel}>Bis</label>
            <input
              type="date"
              value={dateToInput}
              onChange={(e) => onDateToChange(e.target.value)}
              className={controlSm}
            />
          </div>
        </>
      )}
    </>
  );
}
