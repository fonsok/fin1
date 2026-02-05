import { useState } from 'react';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { cloudFunction } from '../../api/admin';
import { Card, Button, Input, Badge } from '../../components/ui';
import { formatCurrency, formatPercentage, formatDateTime } from '../../utils/format';
import type { ConfigurationParameter, PendingConfigChange } from './types';

// Parameter definitions with metadata
const PARAMETER_DEFINITIONS: Record<string, Omit<ConfigurationParameter, 'value'>> = {
  traderCommissionRate: {
    key: 'traderCommissionRate',
    displayName: 'Trader Commission Rate',
    description: 'Prozentsatz des Gewinns, den Trader als Provision erhalten',
    type: 'percentage',
    category: 'financial',
    isCritical: true,
    min: 0,
    max: 1,
  },
  initialAccountBalance: {
    key: 'initialAccountBalance',
    displayName: 'Initial Account Balance',
    description: 'Startguthaben für neue Benutzerkonten',
    type: 'currency',
    category: 'financial',
    isCritical: true,
    min: 1000,
    max: 1000000,
  },
  platformServiceChargeRate: {
    key: 'platformServiceChargeRate',
    displayName: 'Platform Service Charge',
    description: 'Plattform-Servicegebühr als Prozentsatz',
    type: 'percentage',
    category: 'financial',
    isCritical: true,
    min: 0,
    max: 0.1,
  },
  minimumCashReserve: {
    key: 'minimumCashReserve',
    displayName: 'Minimum Cash Reserve',
    description: 'Mindestbetrag, den Benutzer auf dem Konto behalten müssen',
    type: 'currency',
    category: 'financial',
    isCritical: false,
    min: 1,
    max: 1000,
  },
  poolBalanceDistributionThreshold: {
    key: 'poolBalanceDistributionThreshold',
    displayName: 'Pool Distribution Threshold',
    description: 'Schwellenwert für die Pool-Verteilung',
    type: 'currency',
    category: 'financial',
    isCritical: false,
    min: 1,
    max: 100,
  },
};

interface ConfigResponse {
  config: Record<string, number | string | boolean>;
  pendingChanges: PendingConfigChange[];
}

export function ConfigurationPage() {
  const queryClient = useQueryClient();
  const [editingParam, setEditingParam] = useState<string | null>(null);
  const [editValue, setEditValue] = useState<string>('');
  const [changeReason, setChangeReason] = useState<string>('');
  const [showPending, setShowPending] = useState(false);

  // Fetch configuration
  const { data, isLoading, error } = useQuery({
    queryKey: ['configuration'],
    queryFn: () => cloudFunction<ConfigResponse>('getConfiguration'),
  });

  // Fetch pending changes
  const { data: pendingData } = useQuery({
    queryKey: ['pendingConfigChanges'],
    queryFn: () => cloudFunction<{ requests: PendingConfigChange[]; total: number }>('getPendingConfigurationChanges'),
  });

  // Request change mutation
  const requestChangeMutation = useMutation({
    mutationFn: (params: { parameterName: string; newValue: number; reason: string }) =>
      cloudFunction('requestConfigurationChange', params),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['configuration'] });
      queryClient.invalidateQueries({ queryKey: ['pendingConfigChanges'] });
      setEditingParam(null);
      setEditValue('');
      setChangeReason('');
    },
  });

  const handleStartEdit = (key: string, currentValue: number | string | boolean) => {
    setEditingParam(key);
    setEditValue(String(currentValue));
    setChangeReason('');
  };

  const handleSaveChange = () => {
    if (!editingParam || !changeReason.trim()) return;

    const def = PARAMETER_DEFINITIONS[editingParam];
    let newValue = parseFloat(editValue);

    // Validate
    if (isNaN(newValue)) return;
    if (def.min !== undefined && newValue < def.min) return;
    if (def.max !== undefined && newValue > def.max) return;

    requestChangeMutation.mutate({
      parameterName: editingParam,
      newValue,
      reason: changeReason,
    });
  };

  const formatValue = (key: string, value: number | string | boolean): string => {
    const def = PARAMETER_DEFINITIONS[key];
    if (!def) return String(value);

    switch (def.type) {
      case 'percentage':
        return formatPercentage(Number(value));
      case 'currency':
        return formatCurrency(Number(value));
      default:
        return String(value);
    }
  };

  const pendingCount = pendingData?.requests?.length || 0;

  if (isLoading) {
    return (
      <div className="flex items-center justify-center h-64">
        <div className="animate-spin w-8 h-8 border-4 border-fin1-primary border-t-transparent rounded-full" />
      </div>
    );
  }

  if (error) {
    return (
      <Card>
        <div className="text-center py-8">
          <p className="text-red-500">Fehler beim Laden der Konfiguration</p>
          <Button variant="secondary" className="mt-4" onClick={() => queryClient.invalidateQueries({ queryKey: ['configuration'] })}>
            Erneut versuchen
          </Button>
        </div>
      </Card>
    );
  }

  const config = data?.config || {};

  // Group parameters by category
  const financialParams = Object.entries(PARAMETER_DEFINITIONS).filter(([_, def]) => def.category === 'financial');

  return (
    <div className="space-y-6">
      {/* Header */}
      <Card>
        <div className="flex items-center justify-between">
          <div>
            <h2 className="text-lg font-semibold">System-Konfiguration</h2>
            <p className="text-sm text-gray-500 mt-1">
              Kritische Parameter erfordern 4-Augen-Genehmigung
            </p>
          </div>
          <div className="flex gap-2">
            {pendingCount > 0 && (
              <Button variant="secondary" onClick={() => setShowPending(!showPending)}>
                <span className="flex items-center gap-2">
                  Ausstehend
                  <Badge variant="warning">{pendingCount}</Badge>
                </span>
              </Button>
            )}
          </div>
        </div>
      </Card>

      {/* Pending Changes */}
      {showPending && pendingData?.requests && pendingData.requests.length > 0 && (
        <Card>
          <h3 className="text-md font-semibold mb-4">Ausstehende Änderungen</h3>
          <div className="space-y-3">
            {pendingData.requests.map((change) => (
              <div key={change.id} className="p-4 bg-yellow-50 border border-yellow-200 rounded-lg">
                <div className="flex justify-between items-start">
                  <div>
                    <p className="font-medium">{PARAMETER_DEFINITIONS[change.parameterName]?.displayName || change.parameterName}</p>
                    <p className="text-sm text-gray-600 mt-1">
                      {formatValue(change.parameterName, change.oldValue)} → {formatValue(change.parameterName, change.newValue)}
                    </p>
                    <p className="text-sm text-gray-500 mt-1">Grund: {change.reason}</p>
                    <p className="text-xs text-gray-400 mt-2">
                      Von: {change.requesterEmail} • {formatDateTime(change.createdAt)}
                    </p>
                  </div>
                  <Badge variant="warning">Ausstehend</Badge>
                </div>
              </div>
            ))}
          </div>
        </Card>
      )}

      {/* Financial Parameters */}
      <Card>
        <h3 className="text-md font-semibold mb-4 flex items-center gap-2">
          <svg className="w-5 h-5 text-fin1-primary" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 8c-1.657 0-3 .895-3 2s1.343 2 3 2 3 .895 3 2-1.343 2-3 2m0-8c1.11 0 2.08.402 2.599 1M12 8V7m0 1v8m0 0v1m0-1c-1.11 0-2.08-.402-2.599-1M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
          </svg>
          Finanzparameter
        </h3>

        <div className="divide-y divide-gray-100">
          {financialParams.map(([key, def]) => {
            const value = config[key];
            const isEditing = editingParam === key;
            const hasPendingChange = pendingData?.requests?.some(c => c.parameterName === key);

            return (
              <div key={key} className="py-4 first:pt-0 last:pb-0">
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

                    {isEditing ? (
                      <div className="mt-3 space-y-3">
                        <div className="flex items-center gap-2">
                          <span className="text-sm text-gray-500">Aktuell:</span>
                          <span className="font-medium">{formatValue(key, value)}</span>
                        </div>
                        <div className="flex items-center gap-2">
                          <Input
                            type="number"
                            value={editValue}
                            onChange={(e) => setEditValue(e.target.value)}
                            className="w-32"
                            step={def.type === 'percentage' ? '0.01' : '1'}
                            min={def.min}
                            max={def.max}
                          />
                          {def.type === 'percentage' && (
                            <span className="text-sm text-gray-500">
                              ({(parseFloat(editValue) * 100).toFixed(0)}%)
                            </span>
                          )}
                        </div>
                        <div>
                          <Input
                            placeholder="Begründung für die Änderung..."
                            value={changeReason}
                            onChange={(e) => setChangeReason(e.target.value)}
                            className="w-full"
                          />
                        </div>
                        <div className="flex gap-2">
                          <Button
                            size="sm"
                            onClick={handleSaveChange}
                            loading={requestChangeMutation.isPending}
                            disabled={!changeReason.trim()}
                          >
                            {def.isCritical ? 'Änderung beantragen' : 'Speichern'}
                          </Button>
                          <Button
                            variant="secondary"
                            size="sm"
                            onClick={() => setEditingParam(null)}
                          >
                            Abbrechen
                          </Button>
                        </div>
                        {requestChangeMutation.isError && (
                          <p className="text-sm text-red-500">Fehler beim Speichern</p>
                        )}
                        {requestChangeMutation.isSuccess && def.isCritical && (
                          <p className="text-sm text-green-600">Änderungsantrag wurde erstellt</p>
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
                      onClick={() => handleStartEdit(key, value)}
                      disabled={hasPendingChange}
                    >
                      Bearbeiten
                    </Button>
                  )}
                </div>
              </div>
            );
          })}
        </div>
      </Card>

      {/* Info Box */}
      <Card className="bg-blue-50 border-blue-200">
        <div className="flex gap-3">
          <svg className="w-5 h-5 text-blue-500 flex-shrink-0 mt-0.5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
          </svg>
          <div className="text-sm text-blue-800">
            <p className="font-medium">4-Augen-Prinzip</p>
            <p className="mt-1">
              Kritische Konfigurationsänderungen erfordern die Genehmigung eines zweiten Administrators.
              Ausstehende Änderungen können unter "Freigaben" genehmigt oder abgelehnt werden.
            </p>
          </div>
        </div>
      </Card>
    </div>
  );
}
