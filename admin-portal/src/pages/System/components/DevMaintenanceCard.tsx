import clsx from 'clsx';
import { Button, Card } from '../../../components/ui';

import { adminControlField, adminStrong } from '../../../utils/adminThemeClasses';
type ResetScope = 'all' | 'sinceHours' | 'testUsers';

type Props = {
  isDark: boolean;
  resetBusy: boolean;
  cleanupBusy: boolean;
  resetScope: ResetScope;
  resetSinceHours: number;
  reseedInitialBalance: boolean;
  onResetScopeChange: (scope: ResetScope) => void;
  onResetSinceHoursChange: (hours: number) => void;
  onReseedInitialBalanceChange: (value: boolean) => void;
  onResetTradingData: () => void;
  onCleanupDuplicateSplits: () => void;
};

export function DevMaintenanceCard({
  isDark,
  resetBusy,
  cleanupBusy,
  resetScope,
  resetSinceHours,
  reseedInitialBalance,
  onResetScopeChange,
  onResetSinceHoursChange,
  onReseedInitialBalanceChange,
  onResetTradingData,
  onCleanupDuplicateSplits,
}: Props) {
  return (
    <Card className={clsx('border', isDark ? 'border-red-700 bg-red-950/20' : 'border-red-200 bg-red-50')}>
      <div className="flex items-start justify-between gap-4 flex-col md:flex-row">
        <div>
          <h3 className="text-md font-semibold">Development Maintenance</h3>
          <p className={clsx('text-sm mt-1', isDark ? 'text-red-200' : 'text-red-700')}>
            Gefaehrlich: setzt Testdaten aus Trading/Investments zurueck (Vorlagen bleiben erhalten).
          </p>
          <div className="mt-3 flex flex-col md:flex-row gap-3 md:items-center">
            <label className={clsx('text-sm', adminStrong(isDark))}>
              Scope
              <select
                className={clsx(
                  'ml-2 px-3 py-2 rounded-md border text-sm',
                  adminControlField(isDark),
                )}
                value={resetScope}
                onChange={(event) => onResetScopeChange(event.target.value as ResetScope)}
                disabled={resetBusy}
              >
                <option value="all">Alles (komplett)</option>
                <option value="sinceHours">Nur letzte X Stunden</option>
                <option value="testUsers">Nur Test-User</option>
              </select>
            </label>

            {resetScope === 'sinceHours' && (
              <label className={clsx('text-sm', adminStrong(isDark))}>
                Stunden
                <input
                  type="number"
                  min={1}
                  step={1}
                  className={clsx(
                    'ml-2 w-24 px-3 py-2 rounded-md border text-sm',
                    adminControlField(isDark),
                  )}
                  value={resetSinceHours}
                  onChange={(event) => onResetSinceHoursChange(Number(event.target.value || 24))}
                  disabled={resetBusy}
                />
              </label>
            )}
            <label className={clsx('text-sm flex items-center gap-2', adminStrong(isDark))}>
              <input
                type="checkbox"
                checked={reseedInitialBalance}
                onChange={(event) => onReseedInitialBalanceChange(event.target.checked)}
                disabled={resetBusy}
              />
              Startguthaben nach Reset neu buchen
            </label>
          </div>
        </div>
        <Button
          variant="secondary"
          onClick={onResetTradingData}
          disabled={resetBusy}
        >
          {resetBusy ? 'Loesche…' : 'DEV: Reset Testdaten (Trading/Investments)'}
        </Button>
      </div>

      <div className="mt-4 flex items-start justify-between gap-4 flex-col md:flex-row">
        <div>
          <p className={clsx('text-sm', isDark ? 'text-red-200' : 'text-red-700')}>
            Bereinigt historische Doppel-Splits (`investorId + batchId + sequenceNumber`) mit Dry-Run-Preview.
          </p>
          <p className={clsx('text-xs mt-1', isDark ? 'text-red-300' : 'text-red-800')}>
            Sicherer Modus: loescht nur stale `reserved` Duplikate; komplexe Faelle bleiben als Review-only erhalten.
          </p>
        </div>
        <Button variant="secondary" onClick={onCleanupDuplicateSplits} disabled={cleanupBusy}>
          {cleanupBusy ? 'Bereinige…' : 'DEV: Bereinige doppelte Investment-Splits'}
        </Button>
      </div>
    </Card>
  );
}
