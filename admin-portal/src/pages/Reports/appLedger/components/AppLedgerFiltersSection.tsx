import clsx from 'clsx';
import { Button } from '../../../../components/ui';
import { DateRangeFilterFields } from '../../../../components/filters/DateRangeFilterFields';
import { useTheme } from '../../../../context/ThemeContext';
import {
  adminBorderChromeSoft,
  adminControlField,
  adminMuted,
  adminStrong,
} from '../../../../utils/adminThemeClasses';
import { formatLedgerAccountDisplayLabel } from '../constants';
import { TRANSACTION_TYPE_LABELS } from '../transactionTypes';
import type { AccountDef, DateRangePreset } from '../types';

export interface AppLedgerFiltersSectionProps {
  accounts: AccountDef[];
  selectedAccount: string;
  onSelectedAccountChange: (value: string) => void;
  userFilter: string;
  onUserFilterChange: (value: string) => void;
  referenceFilter: string;
  onReferenceFilterChange: (value: string) => void;
  typeFilter: string;
  onTypeFilterChange: (value: string) => void;
  datePreset: DateRangePreset;
  dateFromInput: string;
  dateToInput: string;
  onDatePresetChange: (preset: DateRangePreset) => void;
  onDateFromInputChange: (value: string) => void;
  onDateToInputChange: (value: string) => void;
  amountMinInput: string;
  onAmountMinInputChange: (value: string) => void;
  amountMaxInput: string;
  onAmountMaxInputChange: (value: string) => void;
  pageSize: number;
  onPageSizeChange: (value: number) => void;
  filterScanTruncated: boolean;
  onResetFilters: () => void;
  onPagedFilterChange: () => void;
}

export function AppLedgerFiltersSection({
  accounts,
  selectedAccount,
  onSelectedAccountChange,
  userFilter,
  onUserFilterChange,
  referenceFilter,
  onReferenceFilterChange,
  typeFilter,
  onTypeFilterChange,
  datePreset,
  dateFromInput,
  dateToInput,
  onDatePresetChange,
  onDateFromInputChange,
  onDateToInputChange,
  amountMinInput,
  onAmountMinInputChange,
  amountMaxInput,
  onAmountMaxInputChange,
  pageSize,
  onPageSizeChange,
  filterScanTruncated,
  onResetFilters,
  onPagedFilterChange,
}: AppLedgerFiltersSectionProps): JSX.Element {
  const { theme } = useTheme();
  const isDark = theme === 'dark';
  const formLabel = clsx('block text-sm font-medium mb-1', adminStrong(isDark));
  const controlSm = clsx('w-full border rounded-lg px-3 py-2 text-sm', adminControlField(isDark));
  const noteXs = clsx('text-xs', adminMuted(isDark));

  return (
    <div className={clsx('p-4 border-b space-y-4', adminBorderChromeSoft(isDark))}>
      <div className="flex flex-col lg:flex-row flex-wrap gap-4 items-end">
        <div className="flex-1">
          <label className={formLabel}>Konto</label>
          <select
            value={selectedAccount}
            onChange={(e) => {
              onSelectedAccountChange(e.target.value);
              onPagedFilterChange();
            }}
            className={controlSm}
          >
            <option value="">Alle Konten</option>
            {accounts.map((account) => (
              <option key={account.code} value={account.code}>
                {formatLedgerAccountDisplayLabel(account)}
              </option>
            ))}
          </select>
        </div>
        <div className="flex-1 min-w-[12rem]">
          <label className={formLabel}>User / Kundennr.</label>
          <input
            type="text"
            value={userFilter}
            onChange={(e) => onUserFilterChange(e.target.value)}
            placeholder="ObjectId, E-Mail, Username…"
            className={controlSm}
          />
        </div>
        <div className="flex-1 min-w-[12rem]">
          <label className={formLabel}>Beleg / Referenz</label>
          <input
            type="text"
            value={referenceFilter}
            onChange={(e) => onReferenceFilterChange(e.target.value)}
            placeholder="Belegnr., businessCaseId, Trade…"
            className={controlSm}
          />
        </div>
        <div className="flex-1 min-w-[12rem]">
          <label className={formLabel}>Transaktionstyp</label>
          <select
            value={typeFilter}
            onChange={(e) => {
              onTypeFilterChange(e.target.value);
              onPagedFilterChange();
            }}
            className={controlSm}
          >
            <option value="">Alle Typen</option>
            {Object.entries(TRANSACTION_TYPE_LABELS).map(([key, label]) => (
              <option key={key} value={key}>
                {label}
              </option>
            ))}
          </select>
        </div>
        <DateRangeFilterFields
          preset={datePreset}
          dateFromInput={dateFromInput}
          dateToInput={dateToInput}
          onPresetChange={(preset) => {
            onDatePresetChange(preset);
            if (preset !== 'custom') {
              onDateFromInputChange('');
              onDateToInputChange('');
            }
            onPagedFilterChange();
          }}
          onDateFromChange={(value) => {
            onDateFromInputChange(value);
            onPagedFilterChange();
          }}
          onDateToChange={(value) => {
            onDateToInputChange(value);
            onPagedFilterChange();
          }}
        />
        <div className="min-w-[8rem]">
          <label className={formLabel}>Betrag von (€)</label>
          <input
            type="text"
            inputMode="decimal"
            value={amountMinInput}
            onChange={(e) => onAmountMinInputChange(e.target.value)}
            placeholder="Min."
            className={controlSm}
          />
        </div>
        <div className="min-w-[8rem]">
          <label className={formLabel}>Betrag bis (€)</label>
          <input
            type="text"
            inputMode="decimal"
            value={amountMaxInput}
            onChange={(e) => onAmountMaxInputChange(e.target.value)}
            placeholder="Max."
            className={controlSm}
          />
        </div>
        <div>
          <label className={formLabel}>Seite</label>
          <select
            value={pageSize}
            onChange={(e) => {
              onPageSizeChange(Number(e.target.value));
              onPagedFilterChange();
            }}
            className={controlSm}
          >
            <option value={50}>50 / Seite</option>
            <option value={100}>100 / Seite</option>
            <option value={250}>250 / Seite</option>
            <option value={500}>500 / Seite</option>
          </select>
        </div>
        <Button variant="ghost" onClick={onResetFilters}>
          Filter zurücksetzen
        </Button>
      </div>
      {filterScanTruncated && (
        <p className={clsx('text-sm', isDark ? 'text-amber-300' : 'text-amber-700')}>
          Hinweis: Beleg- oder User-Textsuche hat das Scan-Limit (5.000 Zeilen) erreicht. Bitte Zeitraum oder Konto
          einschränken.
        </p>
      )}
      <p className={noteXs}>
        Betragsfilter gilt pro Buchungszeile (Soll/Haben). Beleg-Suche durchsucht Referenz, Belegnummer und
        businessCaseId (serverseitig).
      </p>
    </div>
  );
}
