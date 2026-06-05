import { useCallback, useMemo, useState } from 'react';
import { Card, Button } from '../../components/ui';
import { ConfigurationHeaderCard } from './components/ConfigurationHeaderCard';
import { PendingChangesCard } from './components/PendingChangesCard';
import { FinancialParametersCard } from './components/FinancialParametersCard';
import { DisplayParametersCard } from './components/DisplayParametersCard';
import { ConfigurationSectionCollapsible } from './components/ConfigurationSectionCollapsible';
import { WalletActionModeBatchCard } from './components/WalletActionModeBatchCard';
import { PARAMETER_DEFINITIONS } from './parameterDefinitions';
import { useConfigurationPage } from './hooks/useConfigurationPage';
import {
  CONFIG_SECTION,
  type ConfigSectionId,
  countPendingInSection,
  getConfigSectionForParameter,
} from './configurationSections';

const financialIcon = (
  <svg className="w-5 h-5 text-fin1-primary shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24" aria-hidden>
    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 8c-1.657 0-3 .895-3 2s1.343 2 3 2 3 .895 3 2-1.343 2-3 2m0-8c1.11 0 2.08.402 2.599 1M12 8V7m0 1v8m0 0v1m0-1c-1.11 0-2.08-.402-2.599-1M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
  </svg>
);

const displayIcon = (
  <svg className="w-5 h-5 text-fin1-primary shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24" aria-hidden>
    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M15 12a3 3 0 11-6 0 3 3 0 016 0z" />
    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M2.458 12C3.732 7.943 7.523 5 12 5c4.478 0 8.268 2.943 9.542 7-1.274 4.057-5.064 7-9.542 7-4.477 0-8.268-2.943-9.542-7z" />
  </svg>
);

const systemIcon = (
  <svg className="w-5 h-5 text-fin1-primary shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24" aria-hidden>
    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M10.325 4.317c.426-1.756 2.924-1.756 3.35 0a1.724 1.724 0 002.573 1.066c1.543-.94 3.31.826 2.37 2.37a1.724 1.724 0 001.065 2.572c1.756.426 1.756 2.924 0 3.35a1.724 1.724 0 00-1.066 2.573c.94 1.543-.826 3.31-2.37 2.37a1.724 1.724 0 00-2.572 1.065c-.426 1.756-2.924 1.756-3.35 0a1.724 1.724 0 00-2.573-1.066c-1.543.94-3.31-.826-2.37-2.37a1.724 1.724 0 00-1.065-2.572c-1.756-.426-1.756-2.924 0-3.35a1.724 1.724 0 001.066-2.573c-.94-1.543.826-3.31 2.37-2.37.996.608 2.296.07 2.572-1.065z" />
    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M15 12a3 3 0 11-6 0 3 3 0 016 0z" />
  </svg>
);

export function ConfigurationPage() {
  const {
    isDark,
    isLoading,
    error,
    queryClient,
    showPending,
    setShowPending,
    config,
    pendingData,
    pendingCount,
    financialParams,
    taxParams,
    systemParams,
    displayParams,
    editingParam,
    editValue,
    changeReason,
    setChangeReason,
    crossLimitError,
    editError,
    requestChangeMutation,
    handleStartEdit,
    handleSaveChange,
    handleCancelEdit,
    formatValue,
    onFinancialEditValueChange,
    onDisplayEditValueChange,
  } = useConfigurationPage();

  const [expandedSections, setExpandedSections] = useState<Set<ConfigSectionId>>(new Set());

  const forceExpandedSection = useMemo(
    () => (editingParam ? getConfigSectionForParameter(editingParam) : null),
    [editingParam],
  );

  const financialKeys = useMemo(() => financialParams.map(([k]) => k), [financialParams]);
  const taxKeys = useMemo(() => taxParams.map(([k]) => k), [taxParams]);
  const systemKeys = useMemo(() => systemParams.map(([k]) => k), [systemParams]);
  const displayKeys = useMemo(() => displayParams.map(([k]) => k), [displayParams]);

  const pendingBySection = useMemo(
    () => ({
      [CONFIG_SECTION.financial]: countPendingInSection(pendingData?.requests, financialKeys),
      [CONFIG_SECTION.tax]: countPendingInSection(pendingData?.requests, taxKeys),
      [CONFIG_SECTION.system]: countPendingInSection(pendingData?.requests, systemKeys),
      [CONFIG_SECTION.display]: countPendingInSection(pendingData?.requests, displayKeys),
    }),
    [pendingData?.requests, financialKeys, taxKeys, systemKeys, displayKeys],
  );

  const toggleSection = useCallback((sectionId: ConfigSectionId) => {
    setExpandedSections((prev) => {
      const next = new Set(prev);
      if (next.has(sectionId)) {
        next.delete(sectionId);
      } else {
        next.add(sectionId);
      }
      return next;
    });
  }, []);

  const isSectionExpanded = useCallback(
    (sectionId: ConfigSectionId) => expandedSections.has(sectionId),
    [expandedSections],
  );

  const sharedCardProps = {
    config,
    isDark,
    editingParam,
    editValue,
    changeReason,
    crossLimitError,
    editError,
    pendingRequests: pendingData?.requests,
    onChangeReason: setChangeReason,
    onSave: handleSaveChange,
    onCancel: handleCancelEdit,
    onStartEdit: handleStartEdit,
    formatValue,
    isSaving: requestChangeMutation.isPending,
    isError: requestChangeMutation.isError,
    isSuccess: requestChangeMutation.isSuccess,
    showHeader: false,
  };

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
          <Button
            variant="secondary"
            className="mt-4"
            onClick={() => queryClient.invalidateQueries({ queryKey: ['configuration'] })}
          >
            Erneut versuchen
          </Button>
        </div>
      </Card>
    );
  }

  return (
    <div className="space-y-6">
      <ConfigurationHeaderCard
        pendingCount={pendingCount}
        onTogglePending={() => setShowPending(!showPending)}
      />

      {showPending && pendingData?.requests && pendingData.requests.length > 0 && (
        <PendingChangesCard
          requests={pendingData.requests}
          parameterDefinitions={PARAMETER_DEFINITIONS}
          formatValue={formatValue}
        />
      )}

      <ConfigurationSectionCollapsible
        title="Finanzparameter"
        icon={financialIcon}
        expanded={isSectionExpanded(CONFIG_SECTION.financial)}
        onToggle={() => toggleSection(CONFIG_SECTION.financial)}
        forceExpanded={forceExpandedSection === CONFIG_SECTION.financial}
        pendingCount={pendingBySection[CONFIG_SECTION.financial]}
        isDark={isDark}
      >
        <FinancialParametersCard
          {...sharedCardProps}
          financialParams={financialParams}
          title="Finanzparameter"
          onEditValueChange={onFinancialEditValueChange}
        />
      </ConfigurationSectionCollapsible>

      <ConfigurationSectionCollapsible
        title="Steuerparameter"
        icon={financialIcon}
        expanded={isSectionExpanded(CONFIG_SECTION.tax)}
        onToggle={() => toggleSection(CONFIG_SECTION.tax)}
        forceExpanded={forceExpandedSection === CONFIG_SECTION.tax}
        pendingCount={pendingBySection[CONFIG_SECTION.tax]}
        isDark={isDark}
      >
        <FinancialParametersCard
          {...sharedCardProps}
          financialParams={taxParams}
          title="Steuerparameter"
          onEditValueChange={onFinancialEditValueChange}
        />
      </ConfigurationSectionCollapsible>

      <ConfigurationSectionCollapsible
        title="Systemparameter"
        icon={systemIcon}
        expanded={isSectionExpanded(CONFIG_SECTION.system)}
        onToggle={() => toggleSection(CONFIG_SECTION.system)}
        forceExpanded={forceExpandedSection === CONFIG_SECTION.system}
        pendingCount={pendingBySection[CONFIG_SECTION.system]}
        isDark={isDark}
      >
        <FinancialParametersCard
          {...sharedCardProps}
          financialParams={systemParams}
          title="Systemparameter"
          onEditValueChange={onFinancialEditValueChange}
        />
      </ConfigurationSectionCollapsible>

      {displayParams.length > 0 && (
        <ConfigurationSectionCollapsible
          title="Anzeige"
          icon={displayIcon}
          expanded={isSectionExpanded(CONFIG_SECTION.display)}
          onToggle={() => toggleSection(CONFIG_SECTION.display)}
          forceExpanded={forceExpandedSection === CONFIG_SECTION.display}
          pendingCount={pendingBySection[CONFIG_SECTION.display]}
          isDark={isDark}
        >
          <DisplayParametersCard
            {...sharedCardProps}
            displayParams={displayParams}
            onEditValueChange={onDisplayEditValueChange}
          />
        </ConfigurationSectionCollapsible>
      )}

      <WalletActionModeBatchCard />

      <Card className="bg-slate-600/80 border-slate-500 border-blue-400/40">
        <div className="flex gap-3">
          <svg
            className="w-5 h-5 text-blue-500 flex-shrink-0 mt-0.5"
            fill="none"
            stroke="currentColor"
            viewBox="0 0 24 24"
          >
            <path
              strokeLinecap="round"
              strokeLinejoin="round"
              strokeWidth={2}
              d="M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"
            />
          </svg>
          <div className="text-sm text-blue-800">
            <p className="font-medium">4-Augen-Prinzip</p>
            <p className="mt-1">
              Kritische Konfigurationsänderungen erfordern die Genehmigung eines zweiten Administrators. Ausstehende
              Änderungen können unter &quot;Freigaben&quot; genehmigt oder abgelehnt werden.
            </p>
          </div>
        </div>
      </Card>
    </div>
  );
}
