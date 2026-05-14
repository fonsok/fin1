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

import { adminBorderChromeSoft, adminCaption, adminControlField, adminDivideYChart, adminDualMuted, adminEmphasisSoft, adminHeadline, adminLabel, adminMonoHint, adminMuted, adminPrimary, adminSoft, adminStrong, adminSurfaceInset } from '../../utils/adminThemeClasses';
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

  const pageTitle = clsx('text-2xl font-bold', adminPrimary(isDark));
  const leadMuted = clsx('mt-1', adminMuted(isDark));
  const captionMuted = clsx('text-xs text-right max-w-md', adminMuted(isDark));
  const groupHeading = clsx('text-lg font-semibold mb-3', adminStrong(isDark));
  const sectionH2 = clsx('text-lg font-semibold', adminPrimary(isDark));
  const bodyMutedSm = clsx('text-sm', adminMuted(isDark));
  const spanStrongSm = clsx('text-sm font-medium', adminStrong(isDark));
  const formLabel = clsx('block text-sm font-medium mb-1', adminStrong(isDark));
  const formLabelXs = clsx('block text-xs mb-1', adminMuted(isDark));
  const controlSm = clsx(
    'w-full border rounded-lg px-3 py-2 text-sm',
    adminControlField(isDark),
  );
  const controlMono = clsx(
    'w-full border rounded-lg px-3 py-2 text-xs font-mono',
    adminControlField(isDark),
  );
  const cardHeaderBorder = clsx('p-4 border-b space-y-1', adminBorderChromeSoft(isDark));
  const snapshotScrollBox = clsx(
    'max-h-48 overflow-auto border rounded-lg text-xs font-mono',
    adminSurfaceInset(isDark),
  );
  const noteXs = clsx('text-xs', adminMuted(isDark));
  const noteXs600 = clsx('text-xs', adminMonoHint(isDark));
  const accountExt = clsx('font-semibold text-[0.8rem]', adminPrimary(isDark));
  const accountCodeMono = clsx('text-[0.7rem] font-mono', adminSoft(isDark));
  const accountName = clsx('text-[0.8rem] font-medium leading-tight', adminPrimary(isDark));
  const accountChart = clsx('text-[0.7rem]', adminMonoHint(isDark));
  const legLabel = clsx('text-[0.7rem]', adminMuted(isDark));
  const emptyMini = clsx('text-[0.7rem]', adminCaption(isDark));
  const emptyState = clsx('p-8 text-center', adminMuted(isDark));

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex flex-col sm:flex-row justify-between items-start sm:items-center gap-4">
        <div>
          <h1 className={pageTitle}>App Ledger</h1>
          <p className={leadMuted}>
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
          <p className={captionMuted}>
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
          <p className={clsx('text-sm', bodyMutedSm)}>
            Keine Konten geladen. Bitte „Aktualisieren“ klicken oder Berechtigung prüfen.
          </p>
        </Card>
      ) : null}
      {Object.entries(groupedAccounts).map(([group, groupAccounts]) => (
        <div key={group}>
          <h2 className={groupHeading}>
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
                      <span className={accountExt}>
                        {acc.externalAccountNumber || '-'}
                      </span>
                      <span className={accountCodeMono}>{acc.code}</span>
                    </div>
                    <div className="mb-2">
                      <div className={accountName}>{acc.name}</div>
                      <div className={accountChart}>{acc.chartCode || '-'}</div>
                    </div>
                    {t ? (
                      <div className="grid grid-cols-3 gap-2 text-[0.7rem]">
                        <div>
                          <p className={legLabel}>Haben</p>
                          <p className="font-medium text-green-600 text-[0.7rem]">{formatCurrency(t.credit)}</p>
                        </div>
                        <div>
                          <p className={legLabel}>Soll</p>
                          <p className="font-medium text-red-600 text-[0.7rem]">{formatCurrency(t.debit)}</p>
                        </div>
                        <div>
                          <p className={legLabel}>Saldo</p>
                          <p className="font-bold text-fin1-primary text-[0.7rem]">{formatCurrency(t.net)}</p>
                        </div>
                      </div>
                    ) : (
                      <p className={emptyMini}>Keine Buchungen</p>
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
            <label className={formLabel}>Konto</label>
            <select
              value={selectedAccount}
              onChange={(e) => {
                setSelectedAccount(e.target.value);
                setPage(0);
              }}
              className={controlSm}
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
            <label className={formLabel}>User-ID</label>
            <input
              type="text"
              value={userFilter}
              onChange={(e) => setUserFilter(e.target.value)}
              placeholder="User-ID filtern..."
              className={controlSm}
            />
          </div>
          <div className="flex-1">
            <label className={formLabel}>Transaktionstyp</label>
            <select
              value={typeFilter}
              onChange={(e) => {
                setTypeFilter(e.target.value);
                setPage(0);
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
          <div>
            <label className={formLabel}>Zeitraum</label>
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
          {datePreset === 'custom' && (
            <>
              <div>
                <label className={formLabel}>Von</label>
                <input
                  type="date"
                  value={dateFromInput}
                  onChange={(e) => {
                    setDateFromInput(e.target.value);
                    setPage(0);
                  }}
                  className={controlSm}
                />
              </div>
              <div>
                <label className={formLabel}>Bis</label>
                <input
                  type="date"
                  value={dateToInput}
                  onChange={(e) => {
                    setDateToInput(e.target.value);
                    setPage(0);
                  }}
                  className={controlSm}
                />
              </div>
            </>
          )}
          <div>
            <label className={formLabel}>Seite</label>
            <select
              value={pageSize}
              onChange={(e) => {
                setPageSize(Number(e.target.value));
                setPage(0);
              }}
              className={controlSm}
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
        <div className={cardHeaderBorder}>
          <h2 className={sectionH2}>Eröffnungssalden (Snapshot)</h2>
          <p className={bodyMutedSm}>
            Stichtagssalden fürs App-Hauptbuch (netDebitMinusCredit pro Konto, wie Abstimmung). Die Abstimmung nutzt
            standardmäßig den letzten Snapshot{' '}
            <strong className={clsx(adminEmphasisSoft(isDark))}>vor</strong> Periodenbeginn, oder einen
            ausgewählten Datensatz.
          </p>
        </div>
        <div className="p-4 grid gap-4 lg:grid-cols-2">
          <div className="space-y-3">
            <div className="flex flex-wrap items-center gap-2 justify-between">
              <span className={spanStrongSm}>Gespeicherte Snapshots</span>
              <Button variant="ghost" type="button" onClick={() => void refreshOpeningSnapshots()}>
                {openingSnapshotsLoading ? 'Lade…' : 'Aktualisieren'}
              </Button>
            </div>
            <div className={snapshotScrollBox}>
              {openingSnapshots.length === 0 ? (
                <div className={clsx('p-3', noteXs)}>Keine Einträge (oder Klasse noch nicht angelegt).</div>
              ) : (
                <ul className={adminDivideYChart(isDark)}>
                  {openingSnapshots.map((s) => (
                    <li key={s.objectId} className="px-3 py-2 flex flex-col gap-0.5">
                      <span className={clsx(adminHeadline(isDark))}>
                        {s.label || s.objectId}
                      </span>
                      <span className={noteXs}>
                        {String(s.effectiveDate).slice(0, 10)} · {s.objectId}
                      </span>
                    </li>
                  ))}
                </ul>
              )}
            </div>
          </div>
          <div className="space-y-3">
            <span className={spanStrongSm}>Neuen Snapshot speichern</span>
            <div className="grid gap-2 sm:grid-cols-2">
              <div>
                <label className={formLabelXs}>Stichtag</label>
                <input
                  type="date"
                  value={snapshotEffectiveDate}
                  onChange={(e) => setSnapshotEffectiveDate(e.target.value)}
                  className={controlSm}
                />
              </div>
              <div>
                <label className={formLabelXs}>Bezeichnung</label>
                <input
                  type="text"
                  value={snapshotLabel}
                  onChange={(e) => setSnapshotLabel(e.target.value)}
                  placeholder="z. B. Jahresende 2025"
                  className={controlSm}
                />
              </div>
            </div>
            <div>
              <label className={formLabelXs}>balances (JSON)</label>
              <textarea
                value={snapshotBalancesJson}
                onChange={(e) => setSnapshotBalancesJson(e.target.value)}
                rows={8}
                className={controlMono}
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
            <h2 className={sectionH2}>Abstimmung (Zeitraum)</h2>
            <p className={clsx('mt-1', bodyMutedSm)}>
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
            adminBorderChromeSoft(isDark),
          )}
        >
          <div className="flex-1 min-w-[12rem]">
            <label className={formLabelXs}>Eröffnung für Abstimmung</label>
            <select
              value={reconciliationOpeningSnapshotId}
              onChange={(e) => setReconciliationOpeningSnapshotId(e.target.value)}
              className={controlSm}
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
              adminBorderChromeSoft(isDark),
            )}
          >
            <p className={clsx('pt-3', noteXs)}>
              Zeilen: AccountStatement {reconciliationResult.rowCounts.accountStatement} · AppLedger{' '}
              {reconciliationResult.rowCounts.appLedgerEntry} · BankContra{' '}
              {reconciliationResult.rowCounts.bankContraPosting}
              {reconciliationResult.truncation.any ? ' · Hinweis: maxRows erreicht (unvollständig)' : ''}
            </p>
            <p className={noteXs600}>
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
            <p className={noteXs600}>
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
                  <span className={clsx(adminStrong(isDark))}>{c.message}</span>
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
            adminBorderChromeSoft(isDark),
          )}
        >
          <h2 className={sectionH2}>Buchungen ({totalCount})</h2>
        </div>

        {isLoading ? (
          <div className={emptyState}>Daten werden geladen...</div>
        ) : entries.length === 0 ? (
          <div className={emptyState}>
            Keine Buchungen gefunden.
            {!selectedAccount && !userFilter && !typeFilter && (
              <p className={clsx('mt-2 text-sm', adminDualMuted(isDark))}>
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
                      adminMuted(isDark),
                    )}
                  />
                  <th
                    className={clsx(
                      'px-4 py-3 text-left text-xs font-medium uppercase',
                      adminMuted(isDark),
                    )}
                  >
                    Konto
                  </th>
                  <th
                    className={clsx(
                      'px-4 py-3 text-left text-xs font-medium uppercase',
                      adminMuted(isDark),
                    )}
                  >
                    Extern (SKR)
                  </th>
                  <th
                    className={clsx(
                      'px-4 py-3 text-center text-xs font-medium uppercase',
                      adminMuted(isDark),
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
                      adminMuted(isDark),
                    )}
                  />
                  <th
                    className={clsx(
                      'px-4 py-3 text-left text-xs font-medium uppercase',
                      adminMuted(isDark),
                    )}
                  >
                    User
                  </th>
                  <th
                    className={clsx(
                      'px-4 py-3 text-left text-xs font-medium uppercase',
                      adminMuted(isDark),
                    )}
                  >
                    Typ
                  </th>
                  <th
                    className={clsx(
                      'px-4 py-3 text-left text-xs font-medium uppercase',
                      adminMuted(isDark),
                    )}
                  >
                    Beleg/Referenz
                  </th>
                  <th
                    className={clsx(
                      'px-4 py-3 text-left text-xs font-medium uppercase',
                      adminMuted(isDark),
                    )}
                  >
                    Gegenkonto
                  </th>
                  <th
                    className={clsx(
                      'px-4 py-3 text-left text-xs font-medium uppercase',
                      adminMuted(isDark),
                    )}
                  >
                    Beschreibung
                  </th>
                </tr>
              </thead>
              <tbody className={tableBodyDivideClasses(isDark)}>
                {entries.map((e, index) => (
                  <tr key={e.id} className={listRowStripeClasses(isDark, index)}>
                    <td className={clsx('px-4 py-3 text-sm whitespace-nowrap', adminMuted(isDark))}>
                      {formatDateTime(e.createdAt)}
                    </td>
                    <td
                      className={clsx(
                        'px-4 py-3 text-sm font-mono whitespace-nowrap',
                        adminStrong(isDark),
                      )}
                    >
                      {e.account}
                    </td>
                    <td className={clsx('px-4 py-3 text-sm whitespace-nowrap', adminLabel(isDark))}>
                      <div>{e.externalAccountNumberSnapshot || '-'}</div>
                      <div className={clsx('text-xs', adminCaption(isDark))}>
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
                    <td className={clsx('px-4 py-3 text-sm whitespace-nowrap', adminStrong(isDark))}>
                      <div>{e.metadata?.userCustomerNumber || '-'}</div>
                      <div className={clsx('text-xs', adminCaption(isDark))}>
                        {e.metadata?.userDisplayName || '-'}
                      </div>
                      {e.metadata?.userUsername && (
                        <div className={clsx('text-xs', adminCaption(isDark))}>
                          Username: {e.metadata.userUsername}
                        </div>
                      )}
                      <div className={clsx('text-xs font-mono', adminCaption(isDark))}>
                        Technische ID: {e.userId || '-'}
                      </div>
                      {e.metadata?.userIdRaw && e.metadata.userIdRaw !== e.userId && (
                        <div className={clsx('text-xs font-mono', adminCaption(isDark))}>
                          Alias: {e.metadata.userIdRaw}
                        </div>
                      )}
                      <div className={clsx('text-xs', adminCaption(isDark))}>
                        {e.userRole}
                      </div>
                    </td>
                    <td className="px-4 py-3 text-sm">
                      <Badge variant="info">
                        {TRANSACTION_TYPE_LABELS[e.transactionType] || e.transactionType}
                      </Badge>
                    </td>
                    <td className={clsx('px-4 py-3 text-sm whitespace-nowrap', adminLabel(isDark))}>
                      <div className="font-medium">
                        {resolveAuditReferenceLabel(e.referenceId, e.metadata?.businessReference)}
                      </div>
                      {e.referenceType ? (
                        <div className={clsx('text-xs', adminCaption(isDark))}>
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
                    <td className={clsx('px-4 py-3 text-sm font-mono whitespace-nowrap', adminLabel(isDark))}>
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
                        adminMuted(isDark),
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
