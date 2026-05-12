import clsx from 'clsx';
import { Card, Button, Input, Badge } from '../../../components/ui';
import { listRowStripeClasses } from '../../../utils/tableStriping';
import type { ConfigurationParameter, PendingConfigChange } from '../types';
import { getAppWithholdsLabel } from '../../../constants/branding';

interface FinancialParametersCardProps {
  financialParams: [string, Omit<ConfigurationParameter, 'value'>][];
  title?: string;
  config: Record<string, number | string | boolean>;
  isDark: boolean;
  editingParam: string | null;
  editValue: string;
  changeReason: string;
  crossLimitError: string | null;
  editError: string | null;
  pendingRequests?: PendingConfigChange[];
  onEditValueChange: (value: string, key: string) => void;
  onChangeReason: (value: string) => void;
  onSave: () => void;
  onCancel: () => void;
  onStartEdit: (key: string, value: number | string | boolean) => void;
  formatValue: (key: string, value: number | string | boolean) => string;
  isSaving: boolean;
  isError: boolean;
  isSuccess: boolean;
}

function normalizeTaxCollectionMode(value: unknown): 'customer_self_reports' | 'platform_withholds' {
  return value === 'platform_withholds' ? 'platform_withholds' : 'customer_self_reports';
}

function normalizeWalletActionMode(value: unknown): 'disabled' | 'deposit_only' | 'withdrawal_only' | 'deposit_and_withdrawal' {
  if (value === 'deposit_only') return 'deposit_only';
  if (value === 'withdrawal_only') return 'withdrawal_only';
  if (value === 'deposit_and_withdrawal') return 'deposit_and_withdrawal';
  return 'disabled';
}

export function FinancialParametersCard({
  financialParams,
  title = 'Finanzparameter',
  config,
  isDark,
  editingParam,
  editValue,
  changeReason,
  crossLimitError,
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
}: FinancialParametersCardProps) {
  const isTaxCard = title === 'Steuerparameter';
  const appWithholdsLabel = getAppWithholdsLabel(config);
  const modeFromConfig = normalizeTaxCollectionMode(config.taxCollectionMode);
  const effectiveTaxMode = normalizeTaxCollectionMode(
    isTaxCard && editingParam === 'taxCollectionMode' && editValue
      ? editValue
      : modeFromConfig,
  );
  const taxDetailKeys = new Set(['withholdingTaxRate', 'solidaritySurchargeRate']);
  const showTaxDetailSection = !isTaxCard || effectiveTaxMode === 'platform_withholds';
  const isInlineTaxModeEdit = isTaxCard && editingParam === 'taxCollectionMode';

  const visibleParams = isTaxCard
    ? financialParams.filter(([key]) => showTaxDetailSection || !taxDetailKeys.has(key))
    : financialParams;

  return (
    <Card>
      <h3 className="text-md font-semibold mb-4 flex items-center gap-2">
        <svg className="w-5 h-5 text-fin1-primary" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 8c-1.657 0-3 .895-3 2s1.343 2 3 2 3 .895 3 2-1.343 2-3 2m0-8c1.11 0 2.08.402 2.599 1M12 8V7m0 1v8m0 0v1m0-1c-1.11 0-2.08-.402-2.599-1M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
        </svg>
        {title}
      </h3>

      <div className="divide-y divide-gray-100">
        {visibleParams.map(([key, def], index: number) => {
          const value = config[key];
          const isEditing = editingParam === key;
          const showInlineTaxModeSelector = isTaxCard && key === 'taxCollectionMode';
          const hasPendingChange = pendingRequests?.some(c => c.parameterName === key);

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

                  {isEditing && !showInlineTaxModeSelector ? (
                    <div className="mt-3 space-y-3">
                      <div className="flex items-center gap-2">
                        <span className="text-sm text-gray-500">Aktuell:</span>
                        <span className="font-medium">{formatValue(key, value)}</span>
                      </div>
                      <div className="flex items-center gap-2">
                        {def.type === 'string' && key === 'taxCollectionMode' ? (
                          <select
                            value={editValue}
                            onChange={(e) => onEditValueChange(e.target.value, key)}
                            className="w-72 rounded-md border border-gray-300 bg-white px-3 py-2 text-sm"
                          >
                            <option value="platform_withholds">{appWithholdsLabel}</option>
                            <option value="customer_self_reports">Kunde führt selbst ab</option>
                          </select>
                        ) : def.type === 'string' && key.startsWith('walletActionMode') ? (
                          <select
                            value={normalizeWalletActionMode(editValue)}
                            onChange={(e) => onEditValueChange(e.target.value, key)}
                            className="w-72 rounded-md border border-gray-300 bg-white px-3 py-2 text-sm"
                          >
                            <option value="disabled">Deaktiviert</option>
                            <option value="deposit_only">Nur Einzahlungen</option>
                            <option value="withdrawal_only">Nur Auszahlungen</option>
                            <option value="deposit_and_withdrawal">Ein- und Auszahlungen</option>
                          </select>
                        ) : (
                          <>
                            <Input
                              type="text"
                              inputMode={def.type === 'string' && key !== 'taxCollectionMode' ? 'text' : 'decimal'}
                              value={editValue}
                              onChange={(e) => onEditValueChange(e.target.value, key)}
                              className={def.type === 'string' && key !== 'taxCollectionMode' ? 'w-full max-w-md' : 'w-32'}
                            />
                            {def.type === 'percentage' && (
                              <span className="text-sm text-gray-500">
                                ({(parseFloat(editValue) * 100).toFixed(0)} %)
                              </span>
                            )}
                            {def.type === 'percent_display' && (
                              <span className="text-sm text-gray-500">
                                ({parseFloat(editValue || '0').toFixed(0)} %)
                              </span>
                            )}
                          </>
                        )}
                      </div>
                      {crossLimitError && ['daily_transaction_limit', 'weekly_transaction_limit', 'monthly_transaction_limit'].includes(key) && (
                        <p className="text-sm text-red-500">{crossLimitError}</p>
                      )}
                      {editError && (
                        <p className="text-sm text-red-500">{editError}</p>
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
                      {isError && (
                        <p className="text-sm text-red-500">Fehler beim Speichern</p>
                      )}
                      {isSuccess && def.isCritical && (
                        <p className="text-sm text-green-600">Änderungsantrag wurde erstellt</p>
                      )}
                    </div>
                  ) : showInlineTaxModeSelector ? (
                    <div className="mt-3 space-y-3">
                      <div className="flex items-center gap-2">
                        <select
                          value={effectiveTaxMode}
                          onChange={(e) => {
                            if (!isInlineTaxModeEdit) {
                              onStartEdit(key, value);
                            }
                            onEditValueChange(e.target.value, key);
                          }}
                          disabled={hasPendingChange}
                          className="w-72 rounded-md border border-gray-300 bg-white px-3 py-2 text-sm"
                        >
                          <option value="customer_self_reports">Kunde führt selbst ab</option>
                          <option value="platform_withholds">{appWithholdsLabel}</option>
                        </select>
                      </div>
                      {isInlineTaxModeEdit && (
                        <>
                          {editError && (
                            <p className="text-sm text-red-500">{editError}</p>
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
                              Änderung beantragen
                            </Button>
                            <Button
                              variant="secondary"
                              size="sm"
                              onClick={onCancel}
                            >
                              Abbrechen
                            </Button>
                          </div>
                          {isError && (
                            <p className="text-sm text-red-500">Fehler beim Speichern</p>
                          )}
                          {isSuccess && (
                            <p className="text-sm text-green-600">Änderungsantrag wurde erstellt</p>
                          )}
                        </>
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

                {!isEditing && !showInlineTaxModeSelector && (
                  <Button
                    variant="secondary"
                    size="sm"
                    className="self-center"
                    onClick={() => onStartEdit(key, value)}
                    disabled={hasPendingChange}
                  >
                    Bearbeiten
                  </Button>
                )}
              </div>
            </div>
          );
        })}

        {isTaxCard && showTaxDetailSection && (
          <div
            className={clsx(
              'py-4 first:pt-0 last:pb-0 rounded-lg px-3 -mx-3',
              listRowStripeClasses(isDark, visibleParams.length, { hover: false }),
            )}
          >
            <div className="flex items-start justify-between">
              <div className="flex-1">
                <div className="flex items-center gap-2">
                  <span className="font-medium">Kirchensteuer</span>
                  <Badge variant="info" size="sm">Automatisch</Badge>
                </div>
                <p className="text-sm text-gray-500 mt-1">
                  Wird automatisch je Nutzerprofil ermittelt: nur bei ev./kath. Konfession; 8 % in Bayern/Baden-Württemberg,
                  sonst 9 % (auf Abgeltungsteuer).
                </p>
              </div>
            </div>
          </div>
        )}
      </div>
    </Card>
  );
}
