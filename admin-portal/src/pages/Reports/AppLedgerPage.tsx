import clsx from 'clsx';
import { Link } from 'react-router-dom';
import { Card, Button, Badge, PaginationBar, Input } from '../../components/ui';
import { formatCurrency, formatDateTime } from '../../utils/format';
import { useTheme } from '../../context/ThemeContext';
import { listRowStripeClasses, tableBodyDivideClasses } from '../../utils/tableStriping';
import { SortableTh } from '../../components/table/SortableTh';
import {
  GROUP_LABELS,
  TRANSACTION_TYPE_LABELS,
  getOverviewClasses,
  formatLedgerAccountDisplayLabel,
} from './appLedger/constants';
import { useAppLedgerPage } from './appLedger/hooks/useAppLedgerPage';
import type { DateRangePreset } from './appLedger/types';

function resolveCounterAccountLabel(
  account: string,
  transactionType: string,
  pairedAccountsRaw?: string,
  pairedAccountRaw?: string,
  escrowLegRaw?: string,
): string {
  const pairedSource = pairedAccountsRaw || pairedAccountRaw || '';
  const pairedAccounts = pairedSource
    .split(',')
    .map((entry) => entry.trim())
    .filter(Boolean);
  if (pairedAccounts.length > 0) return pairedAccounts.join(', ');

  // App-Service-Charge: one debit clearing leg against two credit legs.
  if (transactionType === 'appServiceCharge') {
    if (account === 'PLT-REV-PSC' || account === 'PLT-TAX-VAT') return 'PLT-CLR-GEN';
    if (account === 'PLT-CLR-GEN') return 'PLT-REV-PSC, PLT-TAX-VAT';
  }

  // investmentEscrow legacy rows do not always carry pairedAccount metadata.
  // Derive the counter-account from deterministic leg/account pairs.
  if (transactionType === 'investmentEscrow') {
    const leg = String(escrowLegRaw || '').trim();
    if (leg === 'reserve' || leg === 'releaseReserve' || leg === 'releaseReservedComplete') {
      if (account === 'CLT-LIAB-AVA') return 'CLT-LIAB-RSV';
      if (account === 'CLT-LIAB-RSV') return 'CLT-LIAB-AVA';
    }
    if (leg === 'deploy') {
      if (account === 'CLT-LIAB-RSV') return 'CLT-LIAB-TRD';
      if (account === 'CLT-LIAB-TRD') return 'CLT-LIAB-RSV';
    }
    if (leg === 'releaseTradingComplete' || leg === 'releaseTradingRefund') {
      if (account === 'CLT-LIAB-TRD') return 'CLT-LIAB-AVA';
      if (account === 'CLT-LIAB-AVA') return 'CLT-LIAB-TRD';
    }
  }
  return '-';
}

function resolveAuditReferenceLabel(referenceId: string, businessReferenceRaw?: string): string {
  const businessReference = String(businessReferenceRaw || '').trim();
  const tech = String(referenceId || '').trim();
  if (businessReference && tech) {
    return `${businessReference} · ID ${tech}`;
  }
  if (businessReference) return businessReference;
  if (tech) return `Technische Referenz · ${tech}`;
  return '—';
}

export function AppLedgerPage(): JSX.Element {
  const { theme } = useTheme();
  const isDark = theme === 'dark';
  const {
    isLoading,
    refetch,
    entries,
    accounts,
    totalCount,
    totals,
    totalRevenue,
    totalRefunds,
    vatSummary,
    groupedAccounts,
    exportCSV,
    exportAuditorFinancialPackage,
    auditorExporting,
    auditorBusinessCaseId,
    setAuditorBusinessCaseId,
    reconciliationResult,
    reconciliationLoading,
    reconciliationOpeningSnapshotId,
    setReconciliationOpeningSnapshotId,
    openingSnapshots,
    openingSnapshotsLoading,
    refreshOpeningSnapshots,
    snapshotEffectiveDate,
    setSnapshotEffectiveDate,
    snapshotLabel,
    setSnapshotLabel,
    snapshotBalancesJson,
    setSnapshotBalancesJson,
    snapshotSaving,
    saveLedgerOpeningSnapshotRow,
    runFinancialReconciliation,
    downloadReconciliationJson,
    selectedAccount,
    setSelectedAccount,
    userFilter,
    setUserFilter,
    typeFilter,
    setTypeFilter,
    page,
    setPage,
    pageSize,
    setPageSize,
    datePreset,
    setDatePreset,
    dateFromInput,
    setDateFromInput,
    dateToInput,
    setDateToInput,
    resetFilters,
    sortBy,
    sortOrder,
    onLedgerSort,
  } = useAppLedgerPage();
  const {
    overviewLabelClass,
    overviewSubtitleClass,
    greenCardClass,
    redCardClass,
    blueCardClass,
    purpleCardClass,
    greenValueClass,
    redValueClass,
    blueValueClass,
    purpleValueClass,
  } = getOverviewClasses(isDark);

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex flex-col sm:flex-row justify-between items-start sm:items-center gap-4">
        <div>
          <h1 className="text-2xl font-bold text-gray-900">App Ledger</h1>
          <p className="text-gray-500 mt-1">
            Eigenkonten der App – Gegenbuchungen zu allen Gebühren (doppelte Buchführung).
            Unten: Konten-Karten und Filter (inkl. Bank Clearing – Service Charge NET/VAT).
          </p>
          <Link
            to="/documents"
            className={clsx(
              'text-sm font-medium mt-2 inline-block hover:underline',
              isDark ? 'text-blue-300' : 'text-blue-700',
            )}
          >
            Beleg-Suche (alle Belegtypen, filterpflichtig) →
          </Link>
        </div>
        <div className="flex flex-col items-stretch sm:items-end gap-2">
          <div className="flex flex-wrap items-center gap-2 justify-end">
            <Input
              className="min-w-[12rem] max-w-[20rem]"
              placeholder="businessCaseId (optional)"
              value={auditorBusinessCaseId}
              onChange={(e) => setAuditorBusinessCaseId(e.target.value)}
              aria-label="Optional: businessCaseId filter for auditor export"
            />
            <Button
              variant="secondary"
              onClick={() => void exportAuditorFinancialPackage()}
              disabled={auditorExporting}
            >
              {auditorExporting ? 'Prüferpaket…' : 'Prüferpaket (CSV)'}
            </Button>
            <Button variant="secondary" onClick={exportCSV} disabled={entries.length === 0}>
              CSV Export
            </Button>
            <Button variant="secondary" onClick={() => refetch()} disabled={isLoading}>
              {isLoading ? 'Laden...' : 'Aktualisieren'}
            </Button>
          </div>
          <p className="text-xs text-gray-500 text-right max-w-md">
            Prüferpaket: nutzt den Datumsfilter der Tabelle unten; ein ZIP (Unterordner mit Datenwörterbuch, CSVs und
            Meta-JSON) — Kompression im Browser, schlankes Server-JSON.
          </p>
        </div>
      </div>

      {/* Financial Overview */}
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4">
        <Card className={greenCardClass}>
          <p className={`text-sm font-medium ${overviewLabelClass}`}>Gesamterlös</p>
          <p className={`text-2xl font-bold ${greenValueClass} mt-1`}>
            {formatCurrency(totalRevenue)}
          </p>
          <p className={`text-xs ${overviewSubtitleClass} mt-1`}>{totalCount} Buchungen</p>
        </Card>

        <Card className={redCardClass}>
          <p className={`text-sm font-medium ${overviewLabelClass}`}>Erstattungen</p>
          <p className={`text-2xl font-bold ${redValueClass} mt-1`}>
            {formatCurrency(totalRefunds)}
          </p>
          <p className={`text-xs ${overviewSubtitleClass} mt-1`}>Gutschriften an User</p>
        </Card>

        {vatSummary && (
          <>
            <Card className={blueCardClass}>
              <p className={`text-sm font-medium ${overviewLabelClass}`}>USt-Verbindlichkeit</p>
              <p className={`text-2xl font-bold ${blueValueClass} mt-1`}>
                {formatCurrency(vatSummary.outstandingVATLiability)}
              </p>
              <p className={`text-xs ${overviewSubtitleClass} mt-1`}>
                Kassiert: {formatCurrency(vatSummary.outputVATCollected)}
              </p>
            </Card>

            <Card className={purpleCardClass}>
              <p className={`text-sm font-medium ${overviewLabelClass}`}>USt abgeführt</p>
              <p className={`text-2xl font-bold ${purpleValueClass} mt-1`}>
                {formatCurrency(vatSummary.outputVATRemitted)}
              </p>
              <p className={`text-xs ${overviewSubtitleClass} mt-1`}>
                Vorsteuer: {formatCurrency(vatSummary.inputVATClaimed)}
              </p>
            </Card>
          </>
        )}
      </div>

      {/* Account Cards by Group */}
      {accounts.length === 0 && !isLoading ? (
        <Card>
          <p className="text-gray-500 text-sm">Keine Konten geladen. Bitte „Aktualisieren“ klicken oder Berechtigung prüfen.</p>
        </Card>
      ) : null}
      {Object.entries(groupedAccounts).map(([group, groupAccounts]) => (
        <div key={group}>
          <h2 className="text-lg font-semibold text-gray-700 mb-3">
            {GROUP_LABELS[group] || group}
          </h2>
          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-3">
            {groupAccounts.map((acc) => {
              const t = totals[acc.code];
              const isSelected = selectedAccount === acc.code;
              return (
                <Card key={acc.code} className={clsx('p-3', isSelected && 'ring-2 ring-fin1-primary')}>
                  <button
                    className="w-full text-left"
                    onClick={() => setSelectedAccount(isSelected ? '' : acc.code)}
                  >
                    <div className="flex items-center justify-between mb-2">
                      <span className="font-semibold text-[0.8rem] text-gray-100">
                        {acc.externalAccountNumber || '-'}
                      </span>
                      <span className="text-[0.7rem] font-mono text-gray-300">{acc.code}</span>
                    </div>
                    <div className="mb-2">
                      <div className="text-[0.8rem] font-medium text-gray-100 leading-tight">{acc.name}</div>
                      <div className="text-[0.7rem] text-gray-300">{acc.chartCode || '-'}</div>
                    </div>
                    {t ? (
                      <div className="grid grid-cols-3 gap-2 text-[0.7rem]">
                        <div>
                          <p className="text-gray-500">Haben</p>
                          <p className="font-medium text-green-600 text-[0.7rem]">{formatCurrency(t.credit)}</p>
                        </div>
                        <div>
                          <p className="text-gray-500">Soll</p>
                          <p className="font-medium text-red-600 text-[0.7rem]">{formatCurrency(t.debit)}</p>
                        </div>
                        <div>
                          <p className="text-gray-500">Saldo</p>
                          <p className="font-bold text-fin1-primary text-[0.7rem]">{formatCurrency(t.net)}</p>
                        </div>
                      </div>
                    ) : (
                      <p className="text-[0.7rem] text-gray-400">Keine Buchungen</p>
                    )}
                  </button>
                </Card>
              );
            })}
          </div>
        </div>
      ))}

      {/* Filters */}
      <Card>
        <div className="flex flex-col sm:flex-row gap-4 items-end">
          <div className="flex-1">
            <label className="block text-sm font-medium text-gray-700 mb-1">Konto</label>
            <select
              value={selectedAccount}
              onChange={(e) => {
                setSelectedAccount(e.target.value);
                setPage(0);
              }}
              className="w-full border border-gray-300 rounded-lg px-3 py-2 text-sm"
            >
              <option value="">Alle Konten</option>
              {accounts.map((a) => (
                <option key={a.code} value={a.code}>
                  {formatLedgerAccountDisplayLabel(a)}
                </option>
              ))}
            </select>
          </div>
          <div className="flex-1">
            <label className="block text-sm font-medium text-gray-700 mb-1">User-ID</label>
            <input
              type="text"
              value={userFilter}
              onChange={(e) => setUserFilter(e.target.value)}
              placeholder="User-ID filtern..."
              className="w-full border border-gray-300 rounded-lg px-3 py-2 text-sm"
            />
          </div>
          <div className="flex-1">
            <label className="block text-sm font-medium text-gray-700 mb-1">Transaktionstyp</label>
            <select
              value={typeFilter}
              onChange={(e) => {
                setTypeFilter(e.target.value);
                setPage(0);
              }}
              className="w-full border border-gray-300 rounded-lg px-3 py-2 text-sm"
            >
              <option value="">Alle Typen</option>
              {Object.entries(TRANSACTION_TYPE_LABELS).map(([key, label]) => (
                <option key={key} value={key}>
                  {label}
                </option>
              ))}
            </select>
          </div>
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">Zeitraum</label>
            <select
              value={datePreset}
              onChange={(e) => {
                const preset = e.target.value as DateRangePreset;
                setDatePreset(preset);
                if (preset !== 'custom') {
                  setDateFromInput('');
                  setDateToInput('');
                }
                setPage(0);
              }}
              className="w-full border border-gray-300 rounded-lg px-3 py-2 text-sm"
            >
              <option value="all">Alle</option>
              <option value="thisMonth">Aktueller Monat</option>
              <option value="lastMonth">Letzter Monat</option>
              <option value="last30Days">Letzte 30 Tage</option>
              <option value="thisYear">Aktuelles Jahr</option>
              <option value="custom">Benutzerdefiniert (Von/Bis)</option>
            </select>
          </div>
          {datePreset === 'custom' && (
            <>
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">Von</label>
                <input
                  type="date"
                  value={dateFromInput}
                  onChange={(e) => {
                    setDateFromInput(e.target.value);
                    setPage(0);
                  }}
                  className="w-full border border-gray-300 rounded-lg px-3 py-2 text-sm"
                />
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">Bis</label>
                <input
                  type="date"
                  value={dateToInput}
                  onChange={(e) => {
                    setDateToInput(e.target.value);
                    setPage(0);
                  }}
                  className="w-full border border-gray-300 rounded-lg px-3 py-2 text-sm"
                />
              </div>
            </>
          )}
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">Seite</label>
            <select
              value={pageSize}
              onChange={(e) => {
                setPageSize(Number(e.target.value));
                setPage(0);
              }}
              className="w-full border border-gray-300 rounded-lg px-3 py-2 text-sm"
            >
              <option value={50}>50 / Seite</option>
              <option value={100}>100 / Seite</option>
              <option value={250}>250 / Seite</option>
              <option value={500}>500 / Seite</option>
            </select>
          </div>
          <Button
            variant="ghost"
            onClick={resetFilters}
          >
            Filter zurücksetzen
          </Button>
        </div>
      </Card>

      <Card>
        <div className="p-4 border-b border-gray-100 space-y-1">
          <h2 className="text-lg font-semibold text-gray-900">Eröffnungssalden (Snapshot)</h2>
          <p className="text-sm text-gray-500">
            Stichtagssalden fürs App-Hauptbuch (netDebitMinusCredit pro Konto, wie Abstimmung). Die Abstimmung nutzt
            standardmäßig den letzten Snapshot <strong>vor</strong> Periodenbeginn, oder einen ausgewählten Datensatz.
          </p>
        </div>
        <div className="p-4 grid gap-4 lg:grid-cols-2">
          <div className="space-y-3">
            <div className="flex flex-wrap items-center gap-2 justify-between">
              <span className="text-sm font-medium text-gray-700">Gespeicherte Snapshots</span>
              <Button variant="ghost" type="button" onClick={() => void refreshOpeningSnapshots()}>
                {openingSnapshotsLoading ? 'Lade…' : 'Aktualisieren'}
              </Button>
            </div>
            <div className="max-h-48 overflow-auto border border-gray-200 rounded-lg text-xs font-mono">
              {openingSnapshots.length === 0 ? (
                <div className="p-3 text-gray-500">Keine Einträge (oder Klasse noch nicht angelegt).</div>
              ) : (
                <ul className="divide-y divide-gray-100">
                  {openingSnapshots.map((s) => (
                    <li key={s.objectId} className="px-3 py-2 flex flex-col gap-0.5">
                      <span className="text-gray-800">{s.label || s.objectId}</span>
                      <span className="text-gray-500">
                        {String(s.effectiveDate).slice(0, 10)} · {s.objectId}
                      </span>
                    </li>
                  ))}
                </ul>
              )}
            </div>
          </div>
          <div className="space-y-3">
            <span className="text-sm font-medium text-gray-700">Neuen Snapshot speichern</span>
            <div className="grid gap-2 sm:grid-cols-2">
              <div>
                <label className="block text-xs text-gray-500 mb-1">Stichtag</label>
                <input
                  type="date"
                  value={snapshotEffectiveDate}
                  onChange={(e) => setSnapshotEffectiveDate(e.target.value)}
                  className="w-full border border-gray-300 rounded-lg px-3 py-2 text-sm"
                />
              </div>
              <div>
                <label className="block text-xs text-gray-500 mb-1">Bezeichnung</label>
                <input
                  type="text"
                  value={snapshotLabel}
                  onChange={(e) => setSnapshotLabel(e.target.value)}
                  placeholder="z. B. Jahresende 2025"
                  className="w-full border border-gray-300 rounded-lg px-3 py-2 text-sm"
                />
              </div>
            </div>
            <div>
              <label className="block text-xs text-gray-500 mb-1">balances (JSON)</label>
              <textarea
                value={snapshotBalancesJson}
                onChange={(e) => setSnapshotBalancesJson(e.target.value)}
                rows={8}
                className="w-full border border-gray-300 rounded-lg px-3 py-2 text-xs font-mono"
                spellCheck={false}
              />
            </div>
            <Button
              variant="secondary"
              type="button"
              disabled={snapshotSaving}
              onClick={() => void saveLedgerOpeningSnapshotRow()}
            >
              {snapshotSaving ? 'Speichere…' : 'Snapshot speichern'}
            </Button>
          </div>
        </div>
      </Card>

      <Card>
        <div className="p-4 flex flex-col sm:flex-row sm:items-center justify-between gap-3">
          <div>
            <h2 className="text-lg font-semibold text-gray-900">Abstimmung (Zeitraum)</h2>
            <p className="text-sm text-gray-500 mt-1">
              Aggregiert Personenkonto, App-Hauptbuch und Bank-Contra für den gleichen Datumsfilter wie oben (nur Lesen,
              serverseitig begrenzt). Vertieft: Eröffnung + definierte Konten-Paare (tradeCash, wallet in/out).
            </p>
          </div>
          <div className="flex flex-wrap gap-2">
            <Button
              variant="secondary"
              onClick={() => void runFinancialReconciliation()}
              disabled={reconciliationLoading}
            >
              {reconciliationLoading ? 'Berechne…' : 'Abstimmung ausführen'}
            </Button>
            <Button variant="ghost" onClick={downloadReconciliationJson} disabled={!reconciliationResult}>
              JSON speichern
            </Button>
          </div>
        </div>
        <div
          className={clsx(
            'px-4 pb-3 border-t flex flex-col sm:flex-row gap-3 sm:items-end',
            isDark ? 'border-slate-600' : 'border-gray-100',
          )}
        >
          <div className="flex-1 min-w-[12rem]">
            <label className="block text-xs text-gray-500 mb-1">Eröffnung für Abstimmung</label>
            <select
              value={reconciliationOpeningSnapshotId}
              onChange={(e) => setReconciliationOpeningSnapshotId(e.target.value)}
              className="w-full border border-gray-300 rounded-lg px-3 py-2 text-sm bg-white"
            >
              <option value="">Automatisch: letzter Snapshot vor Periodenbeginn</option>
              {openingSnapshots.map((s) => (
                <option key={s.objectId} value={s.objectId}>
                  {String(s.effectiveDate).slice(0, 10)} — {s.label || s.objectId}
                </option>
              ))}
            </select>
          </div>
        </div>
        {reconciliationResult ? (
          <div
            className={clsx(
              'px-4 pb-4 border-t space-y-3',
              isDark ? 'border-slate-600' : 'border-gray-100',
            )}
          >
            <p className="text-xs text-gray-500 pt-3">
              Zeilen: AccountStatement {reconciliationResult.rowCounts.accountStatement} · AppLedger{' '}
              {reconciliationResult.rowCounts.appLedgerEntry} · BankContra{' '}
              {reconciliationResult.rowCounts.bankContraPosting}
              {reconciliationResult.truncation.any ? ' · Hinweis: maxRows erreicht (unvollständig)' : ''}
            </p>
            <p className="text-xs text-gray-600">
              Eröffnung:{' '}
              <span className="font-mono">
                {reconciliationResult.parameters.openingSelection === 'latestBeforePeriod' && !reconciliationResult.openingSnapshot
                  ? 'keiner (0)'
                  : reconciliationResult.openingSnapshot
                    ? `${reconciliationResult.openingSnapshot.label || reconciliationResult.openingSnapshot.objectId} (${String(reconciliationResult.openingSnapshot.effectiveDate).slice(0, 10)})`
                    : reconciliationResult.parameters.openingSelection}
              </span>
              {' · '}
              Paarregeln OK:{' '}
              <span className="font-mono">
                {reconciliationResult.reconciliationDeep.pairResults.filter((p) => p.ok).length}/
                {reconciliationResult.reconciliationDeep.pairResults.length}
              </span>
            </p>
            <p className="text-xs text-gray-600">
              Personenkonto Σ Betrag (Zeitraum):{' '}
              <span className="font-mono">{reconciliationResult.accountStatement.sumAmount.toFixed(2)} €</span>
            </p>
            <ul className="space-y-2">
              {reconciliationResult.checks.map((c) => (
                <li key={c.id} className="flex gap-2 items-start text-sm">
                  <Badge
                    variant={
                      c.severity === 'warning' ? 'warning' : c.severity === 'error' ? 'danger' : 'info'
                    }
                  >
                    {c.severity}
                  </Badge>
                  <span className={clsx(isDark ? 'text-slate-200' : 'text-gray-700')}>{c.message}</span>
                </li>
              ))}
            </ul>
          </div>
        ) : null}
      </Card>

      {/* Entries Table */}
      <Card>
        <div
          className={clsx(
            'p-4 border-b flex justify-between items-center',
            isDark ? 'border-slate-600' : 'border-gray-100',
          )}
        >
          <h2 className="text-lg font-semibold">Buchungen ({totalCount})</h2>
        </div>

        {isLoading ? (
          <div className="p-8 text-center text-gray-500">Daten werden geladen...</div>
        ) : entries.length === 0 ? (
          <div className="p-8 text-center text-gray-500">
            Keine Buchungen gefunden.
            {!selectedAccount && !userFilter && !typeFilter && (
              <p className="mt-2 text-sm">
                Gegenbuchungen werden automatisch erzeugt, wenn Gebühren von Nutzern erhoben werden.
              </p>
            )}
          </div>
        ) : (
          <div className="overflow-x-auto">
            <table className="w-full min-w-[1500px]">
              <thead
                className={clsx(
                  'border-b',
                  isDark ? 'bg-slate-800/50 border-slate-600' : 'bg-gray-50 border-gray-200',
                )}
              >
                <tr>
                  <SortableTh
                    label="Datum"
                    field="createdAt"
                    sortBy={sortBy}
                    sortOrder={sortOrder}
                    onSort={onLedgerSort}
                    className={clsx(
                      'px-4 py-3 text-xs font-medium uppercase',
                      isDark ? 'text-slate-400' : 'text-gray-500',
                    )}
                  />
                  <th
                    className={clsx(
                      'px-4 py-3 text-left text-xs font-medium uppercase',
                      isDark ? 'text-slate-400' : 'text-gray-500',
                    )}
                  >
                    Konto
                  </th>
                  <th
                    className={clsx(
                      'px-4 py-3 text-left text-xs font-medium uppercase',
                      isDark ? 'text-slate-400' : 'text-gray-500',
                    )}
                  >
                    Extern (SKR)
                  </th>
                  <th
                    className={clsx(
                      'px-4 py-3 text-center text-xs font-medium uppercase',
                      isDark ? 'text-slate-400' : 'text-gray-500',
                    )}
                  >
                    Seite
                  </th>
                  <SortableTh
                    label="Betrag"
                    field="amount"
                    sortBy={sortBy}
                    sortOrder={sortOrder}
                    onSort={onLedgerSort}
                    align="right"
                    className={clsx(
                      'px-4 py-3 text-xs font-medium uppercase',
                      isDark ? 'text-slate-400' : 'text-gray-500',
                    )}
                  />
                  <th
                    className={clsx(
                      'px-4 py-3 text-left text-xs font-medium uppercase',
                      isDark ? 'text-slate-400' : 'text-gray-500',
                    )}
                  >
                    User
                  </th>
                  <th
                    className={clsx(
                      'px-4 py-3 text-left text-xs font-medium uppercase',
                      isDark ? 'text-slate-400' : 'text-gray-500',
                    )}
                  >
                    Typ
                  </th>
                  <th
                    className={clsx(
                      'px-4 py-3 text-left text-xs font-medium uppercase',
                      isDark ? 'text-slate-400' : 'text-gray-500',
                    )}
                  >
                    Beleg/Referenz
                  </th>
                  <th
                    className={clsx(
                      'px-4 py-3 text-left text-xs font-medium uppercase',
                      isDark ? 'text-slate-400' : 'text-gray-500',
                    )}
                  >
                    Gegenkonto
                  </th>
                  <th
                    className={clsx(
                      'px-4 py-3 text-left text-xs font-medium uppercase',
                      isDark ? 'text-slate-400' : 'text-gray-500',
                    )}
                  >
                    Beschreibung
                  </th>
                </tr>
              </thead>
              <tbody className={tableBodyDivideClasses(isDark)}>
                {entries.map((e, index) => (
                  <tr key={e.id} className={listRowStripeClasses(isDark, index)}>
                    <td className={clsx('px-4 py-3 text-sm whitespace-nowrap', isDark ? 'text-slate-400' : 'text-gray-500')}>
                      {formatDateTime(e.createdAt)}
                    </td>
                    <td
                      className={clsx(
                        'px-4 py-3 text-sm font-mono whitespace-nowrap',
                        isDark ? 'text-slate-200' : 'text-gray-700',
                      )}
                    >
                      {e.account}
                    </td>
                    <td className={clsx('px-4 py-3 text-sm whitespace-nowrap', isDark ? 'text-slate-300' : 'text-gray-700')}>
                      <div>{e.externalAccountNumberSnapshot || '-'}</div>
                      <div className={clsx('text-xs', isDark ? 'text-slate-500' : 'text-gray-400')}>
                        {e.chartCodeSnapshot || '-'} {e.vatKeySnapshot ? `• VAT ${e.vatKeySnapshot}` : ''}
                      </div>
                    </td>
                    <td className="px-4 py-3 text-center">
                      <Badge variant={e.side === 'credit' ? 'success' : 'danger'}>
                        {e.side === 'credit' ? 'Haben' : 'Soll'}
                      </Badge>
                    </td>
                    <td
                      className={clsx(
                        'px-4 py-3 text-sm text-right font-medium whitespace-nowrap',
                        e.side === 'credit'
                          ? isDark
                            ? 'text-green-400'
                            : 'text-green-600'
                          : isDark
                            ? 'text-red-400'
                            : 'text-red-600',
                      )}
                    >
                      {formatCurrency(e.amount)}
                    </td>
                    <td className={clsx('px-4 py-3 text-sm whitespace-nowrap', isDark ? 'text-slate-200' : 'text-gray-700')}>
                      <div>{e.metadata?.userCustomerNumber || '-'}</div>
                      <div className={clsx('text-xs', isDark ? 'text-slate-500' : 'text-gray-400')}>
                        {e.metadata?.userDisplayName || '-'}
                      </div>
                      {e.metadata?.userUsername && (
                        <div className={clsx('text-xs', isDark ? 'text-slate-500' : 'text-gray-400')}>
                          Username: {e.metadata.userUsername}
                        </div>
                      )}
                      <div className={clsx('text-xs font-mono', isDark ? 'text-slate-500' : 'text-gray-400')}>
                        Technische ID: {e.userId || '-'}
                      </div>
                      {e.metadata?.userIdRaw && e.metadata.userIdRaw !== e.userId && (
                        <div className={clsx('text-xs font-mono', isDark ? 'text-slate-500' : 'text-gray-400')}>
                          Alias: {e.metadata.userIdRaw}
                        </div>
                      )}
                      <div className={clsx('text-xs', isDark ? 'text-slate-500' : 'text-gray-400')}>
                        {e.userRole}
                      </div>
                    </td>
                    <td className="px-4 py-3 text-sm">
                      <Badge variant="info">
                        {TRANSACTION_TYPE_LABELS[e.transactionType] || e.transactionType}
                      </Badge>
                    </td>
                    <td className={clsx('px-4 py-3 text-sm whitespace-nowrap', isDark ? 'text-slate-300' : 'text-gray-700')}>
                      <div className="font-medium">
                        {resolveAuditReferenceLabel(e.referenceId, e.metadata?.businessReference)}
                      </div>
                      {e.referenceType ? (
                        <div className={clsx('text-xs', isDark ? 'text-slate-500' : 'text-gray-400')}>
                          Referenz-Typ: {e.referenceType}
                        </div>
                      ) : null}
                      {(() => {
                        const refDocId = String(e.metadata?.referenceDocumentId ?? '').trim();
                        const refNum = String(e.metadata?.referenceDocumentNumber ?? '').trim();
                        if (refDocId) {
                          return (
                            <div className="mt-1.5">
                              <Link
                                to={`/documents?openDocumentId=${encodeURIComponent(refDocId)}`}
                                className={clsx(
                                  'text-sm font-medium hover:underline',
                                  isDark ? 'text-blue-300' : 'text-blue-700',
                                )}
                              >
                                Beleg ansehen
                              </Link>
                            </div>
                          );
                        }
                        if (refNum) {
                          return (
                            <div className="mt-1.5">
                              <Link
                                to={`/documents?openDocumentNumber=${encodeURIComponent(refNum)}`}
                                className={clsx(
                                  'text-sm font-medium hover:underline',
                                  isDark ? 'text-blue-300' : 'text-blue-700',
                                )}
                              >
                                Beleg ansehen
                              </Link>
                            </div>
                          );
                        }
                        return null;
                      })()}
                    </td>
                    <td className={clsx('px-4 py-3 text-sm font-mono whitespace-nowrap', isDark ? 'text-slate-300' : 'text-gray-700')}>
                      {resolveCounterAccountLabel(
                        e.account,
                        e.transactionType,
                        e.metadata?.pairedAccounts,
                        e.metadata?.pairedAccount,
                        e.metadata?.leg,
                      )}
                    </td>
                    <td
                      className={clsx(
                        'px-4 py-3 text-sm whitespace-nowrap',
                        isDark ? 'text-slate-400' : 'text-gray-500',
                      )}
                    >
                      {e.description}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
        {!isLoading && entries.length > 0 && (
          <PaginationBar
            page={page}
            pageSize={pageSize}
            total={totalCount}
            itemLabel="Buchungen"
            isDark={isDark}
            onPageChange={setPage}
          />
        )}
      </Card>
    </div>
  );
}
