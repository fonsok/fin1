import { Card, Button } from '../../components/ui';
import { ConfigurationHeaderCard } from './components/ConfigurationHeaderCard';
import { PendingChangesCard } from './components/PendingChangesCard';
import { FinancialParametersCard } from './components/FinancialParametersCard';
import { DisplayParametersCard } from './components/DisplayParametersCard';
import { WalletActionModeBatchCard } from './components/WalletActionModeBatchCard';
import { PARAMETER_DEFINITIONS } from './parameterDefinitions';
import { useConfigurationPage } from './hooks/useConfigurationPage';

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

      <FinancialParametersCard
        financialParams={financialParams}
        title="Finanzparameter"
        config={config}
        isDark={isDark}
        editingParam={editingParam}
        editValue={editValue}
        changeReason={changeReason}
        crossLimitError={crossLimitError}
        editError={editError}
        pendingRequests={pendingData?.requests}
        onEditValueChange={onFinancialEditValueChange}
        onChangeReason={setChangeReason}
        onSave={handleSaveChange}
        onCancel={handleCancelEdit}
        onStartEdit={handleStartEdit}
        formatValue={formatValue}
        isSaving={requestChangeMutation.isPending}
        isError={requestChangeMutation.isError}
        isSuccess={requestChangeMutation.isSuccess}
      />

      <FinancialParametersCard
        financialParams={taxParams}
        title="Steuerparameter"
        config={config}
        isDark={isDark}
        editingParam={editingParam}
        editValue={editValue}
        changeReason={changeReason}
        crossLimitError={crossLimitError}
        editError={editError}
        pendingRequests={pendingData?.requests}
        onEditValueChange={onFinancialEditValueChange}
        onChangeReason={setChangeReason}
        onSave={handleSaveChange}
        onCancel={handleCancelEdit}
        onStartEdit={handleStartEdit}
        formatValue={formatValue}
        isSaving={requestChangeMutation.isPending}
        isError={requestChangeMutation.isError}
        isSuccess={requestChangeMutation.isSuccess}
      />

      <FinancialParametersCard
        financialParams={systemParams}
        title="Systemparameter"
        config={config}
        isDark={isDark}
        editingParam={editingParam}
        editValue={editValue}
        changeReason={changeReason}
        crossLimitError={crossLimitError}
        editError={editError}
        pendingRequests={pendingData?.requests}
        onEditValueChange={onFinancialEditValueChange}
        onChangeReason={setChangeReason}
        onSave={handleSaveChange}
        onCancel={handleCancelEdit}
        onStartEdit={handleStartEdit}
        formatValue={formatValue}
        isSaving={requestChangeMutation.isPending}
        isError={requestChangeMutation.isError}
        isSuccess={requestChangeMutation.isSuccess}
      />

      <DisplayParametersCard
        displayParams={displayParams}
        config={config}
        isDark={isDark}
        editingParam={editingParam}
        editValue={editValue}
        changeReason={changeReason}
        editError={editError}
        pendingRequests={pendingData?.requests}
        onEditValueChange={onDisplayEditValueChange}
        onChangeReason={setChangeReason}
        onSave={handleSaveChange}
        onCancel={handleCancelEdit}
        onStartEdit={handleStartEdit}
        formatValue={formatValue}
        isSaving={requestChangeMutation.isPending}
        isError={requestChangeMutation.isError}
        isSuccess={requestChangeMutation.isSuccess}
      />

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
