import clsx from 'clsx';
import { Card, Button, Input, Badge } from '../../../components/ui';
import { listRowStripeClasses } from '../../../utils/tableStriping';
import type { ConfigurationParameter, PendingConfigChange } from '../types';

interface DisplayParametersCardProps {
  displayParams: [string, Omit<ConfigurationParameter, 'value'>][];
  config: Record<string, number | string | boolean>;
  isDark: boolean;
  editingParam: string | null;
  editValue: string;
  changeReason: string;
  editError: string | null;
  pendingRequests?: PendingConfigChange[];
  onEditValueChange: (value: string) => void;
  onChangeReason: (value: string) => void;
  onSave: () => void;
  onCancel: () => void;
  onStartEdit: (key: string, value: number | string | boolean) => void;
  formatValue: (key: string, value: number | string | boolean) => string;
  isSaving: boolean;
  isError: boolean;
  isSuccess: boolean;
}

export function DisplayParametersCard({
  displayParams,
  config,
  isDark,
  editingParam,
  editValue,
  changeReason,
  editError,
  pendingRequests,
  onEditValueChange,
  onChangeReason,
  onSave,
  onCancel,
  onStartEdit,
  formatValue,
  isSaving,
  isError,
  isSuccess,
}: DisplayParametersCardProps) {
  if (displayParams.length === 0) return null;
  const allowedFromRaw = String(config.serviceChargeLegacyDisableAllowedFrom ?? '2999-12-31');
  const now = new Date();
  const isoToday = `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, '0')}-${String(now.getDate()).padStart(2, '0')}`;
  const canDisableLegacy = isoToday >= allowedFromRaw;

  return (
    <Card>
      <h3 className="text-md font-semibold mb-4 flex items-center gap-2">
        <svg className="w-5 h-5 text-fin1-primary" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M15 12a3 3 0 11-6 0 3 3 0 016 0z" />
          <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M2.458 12C3.732 7.943 7.523 5 12 5c4.478 0 8.268 2.943 9.542 7-1.274 4.057-5.064 7-9.542 7-4.477 0-8.268-2.943-9.542-7z" />
        </svg>
        Anzeige
      </h3>

      <div className="divide-y divide-gray-100">
        {displayParams.map(([key, def], index: number) => {
          const value = config[key];
          const isEditing = editingParam === key;
          const hasPendingChange = pendingRequests?.some(c => c.parameterName === key);
          const isLegacyToggle = key === 'serviceChargeLegacyClientFallbackEnabled';
          const legacyActive = value === true || value === 'true' || value === 1 || value === '1';
          const blockLegacyEdit = isLegacyToggle && legacyActive && !canDisableLegacy;

          return (
            <div
              key={key}
              className={clsx(
                'py-4 first:pt-0 last:pb-0 rounded-lg px-3 -mx-3',
                listRowStripeClasses(isDark, index, { hover: false }),
              )}
            >
              <div className="flex items-start justify-between">
                <div className="flex-1">
                  <div className="flex items-center gap-2">
                    <span className="font-medium">{def.displayName}</span>
                    {def.isCritical && (
                      <Badge variant="warning" size="sm">4-Augen</Badge>
                    )}
                    {hasPendingChange && (
                      <Badge variant="info" size="sm">Änderung ausstehend</Badge>
                    )}
                  </div>
                  <p className="text-sm text-gray-500 mt-1">{def.description}</p>
                  {isLegacyToggle && legacyActive && (
                    <p className={clsx(
                      'mt-2 text-xs',
                      canDisableLegacy ? 'text-green-500' : 'text-amber-500',
                    )}>
                      {canDisableLegacy
                        ? `Deaktivierung ist seit ${allowedFromRaw} freigegeben.`
                        : `Deaktivierung erlaubt ab ${allowedFromRaw}.`}
                    </p>
                  )}

                  {isEditing ? (
                    <div className="mt-3 space-y-3">
                      <div className="flex items-center gap-2">
                        <span className="text-sm text-gray-500">Aktuell:</span>
                        <span className="font-medium">{formatValue(key, value)}</span>
                      </div>
                      {def.type === 'boolean' ? (
                        <div className="flex items-center gap-2">
                          <label className="flex items-center gap-2 cursor-pointer">
                            <input
                              type="checkbox"
                              checked={editValue === 'true' || editValue === '1'}
                              onChange={(e) => onEditValueChange(e.target.checked ? 'true' : 'false')}
                              className="rounded border-gray-300"
                            />
                            <span className="text-sm">{editValue === 'true' || editValue === '1' ? 'Aktiv' : 'Deaktiviert'}</span>
                          </label>
                        </div>
                      ) : (
                        <div className="flex items-center gap-2">
                          <Input
                            type="text"
                            inputMode="decimal"
                            value={editValue}
                            onChange={(e) => onEditValueChange(e.target.value)}
                            className="w-32"
                          />
                          {def.type === 'percent_display' && (
                            <span className="text-sm text-gray-500">
                              ({parseFloat(editValue || '0').toFixed(0)} %)
                            </span>
                          )}
                        </div>
                      )}
                      <div>
                        <Input
                          placeholder="Begründung für die Änderung..."
                          value={changeReason}
                          onChange={(e) => onChangeReason(e.target.value)}
                          className="w-full"
                        />
                      </div>
                      <div className="flex gap-2">
                        <Button
                          size="sm"
                          onClick={onSave}
                          loading={isSaving}
                          disabled={!changeReason.trim()}
                        >
                          {def.isCritical ? 'Änderung beantragen' : 'Speichern'}
                        </Button>
                        <Button
                          variant="secondary"
                          size="sm"
                          onClick={onCancel}
                        >
                          Abbrechen
                        </Button>
                      </div>
                      {editError && (
                        <p className="text-sm text-red-500">{editError}</p>
                      )}
                      {isError && (
                        <p className="text-sm text-red-500">Fehler beim Speichern</p>
                      )}
                      {isSuccess && (
                        <p className="text-sm text-green-600">
                          {def.isCritical ? 'Änderungsantrag wurde erstellt' : 'Wert aktualisiert'}
                        </p>
                      )}
                    </div>
                  ) : (
                    <div className="mt-2 flex items-center gap-4">
                      <span className="text-lg font-semibold text-fin1-primary">
                        {formatValue(key, value)}
                      </span>
                    </div>
                  )}
                </div>

                {!isEditing && (
                  <Button
                    variant="secondary"
                    size="sm"
                    onClick={() => onStartEdit(key, value)}
                    disabled={hasPendingChange || blockLegacyEdit}
                  >
                    {isLegacyToggle && legacyActive ? 'Legacy-Pfad deaktivieren' : 'Bearbeiten'}
                  </Button>
                )}
              </div>
            </div>
          );
        })}
      </div>
    </Card>
  );
}
