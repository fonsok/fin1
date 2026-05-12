import { useCallback, useEffect, useMemo, useState } from 'react';
import { useQuery } from '@tanstack/react-query';
import { cloudFunction } from '../../../../api/admin';
import { nextSortState, type SortOrder } from '../../../../components/table/SortableTh';
import { formatDateTime } from '../../../../utils/format';
import { TRANSACTION_TYPE_LABELS } from '../constants';
import type { AccountDef, AccountTotals, AppLedgerEntry, DateRangePreset, LedgerResponse, VATSummary } from '../types';

/** Response shape of `exportAuditorFinancialCsv` (Parse Cloud). */
export interface AuditorFinancialExportResult {
  generatedAt: string;
  parameters: {
    dateFrom: string;
    dateTo: string;
    businessCaseId: string;
    limitPerSection: number;
  };
  rowCounts: Record<string, number>;
  dataDictionary: unknown;
  csv: {
    accountStatement: string;
    appLedgerEntry: string;
    document: string;
    walletTransaction: string;
    invoice: string;
  };
}

export interface ReconciliationCheck {
  id: string;
  severity: 'info' | 'warning' | 'error';
  message: string;
  value?: number;
  details?: unknown;
}

export interface LedgerOpeningSnapshotRow {
  objectId: string;
  effectiveDate: string;
  label: string;
  notes?: string;
  balances: Record<string, { netDebitMinusCredit: number } | number>;
  source?: string;
  createdAt?: string;
}

export interface FinancialReconciliationPairResult {
  id: string;
  description?: string;
  toleranceEUR: number;
  legNets: Array<{
    account: string;
    transactionTypes: string[];
    netDebitMinusCredit: number;
  }>;
  pairSumNetDebitMinusCredit: number;
  ok: boolean;
}

export interface FinancialReconciliationResult {
  generatedAt: string;
  period: { from: string; to: string };
  parameters: {
    maxRows: number;
    openingSelection: 'none' | 'explicit' | 'latestBeforePeriod';
    useLatestOpeningBeforePeriod: boolean;
    openingSnapshotObjectId: string | null;
  };
  truncation: {
    accountStatement: boolean;
    appLedgerEntry: boolean;
    bankContraPosting: boolean;
    any: boolean;
  };
  rowCounts: Record<string, number>;
  accountStatement: {
    rowCount: number;
    sumAmount: number;
    byEntryType: Record<string, { count: number; sumAmount: number }>;
    missingBusinessCaseId: number;
    missingReferenceDocument: number;
  };
  appLedger: {
    rowCount: number;
    byAccount: Record<
      string,
      { debitSum: number; creditSum: number; rowCount: number; netDebitMinusCredit: number }
    >;
    missingBusinessCaseId: number;
    byAccountByTransactionType?: Record<
      string,
      Record<string, { debitSum: number; creditSum: number; rowCount: number; netDebitMinusCredit: number }>
    >;
  };
  bankContraPosting: {
    rowCount: number;
    byAccount: Record<string, unknown>;
  };
  checks: ReconciliationCheck[];
  accountCatalog: { code: string; name: string; group: string; normalBalance: string }[];
  openingSnapshot: LedgerOpeningSnapshotRow | null;
  reconciliationDeep: {
    periodPairRuleDefinitions: unknown[];
    pairResults: FinancialReconciliationPairResult[];
    closingByAccount: Record<
      string,
      {
        openingNetDebitMinusCredit: number;
        periodNetDebitMinusCredit: number;
        closingEstimateNetDebitMinusCredit: number;
      }
    >;
  };
}

function toYMD(date: Date): string {
  const year = date.getFullYear();
  const month = String(date.getMonth() + 1).padStart(2, '0');
  const day = String(date.getDate()).padStart(2, '0');
  return `${year}-${month}-${day}`;
}

function resolveDateRange(
  datePreset: DateRangePreset,
  dateFromInput: string,
  dateToInput: string,
): { from?: string; to?: string } {
  const now = new Date();
  const today = new Date(now.getFullYear(), now.getMonth(), now.getDate());

  if (datePreset === 'all') return {};
  if (datePreset === 'custom') return { from: dateFromInput || undefined, to: dateToInput || undefined };
  if (datePreset === 'thisMonth') return { from: toYMD(new Date(today.getFullYear(), today.getMonth(), 1)), to: toYMD(today) };
  if (datePreset === 'lastMonth') {
    const start = new Date(today.getFullYear(), today.getMonth() - 1, 1);
    const end = new Date(today.getFullYear(), today.getMonth(), 0);
    return { from: toYMD(start), to: toYMD(end) };
  }
  if (datePreset === 'thisYear') return { from: toYMD(new Date(today.getFullYear(), 0, 1)), to: toYMD(today) };
  if (datePreset === 'last30Days') {
    const start = new Date(today);
    start.setDate(start.getDate() - 29);
    return { from: toYMD(start), to: toYMD(today) };
  }
  return {};
}

/** Safe single path segment for archive / download names (no slashes). */
function safeExportSegment(raw: string, maxLen: number): string {
  const s = raw.replace(/[/\\?*:|"<>]/g, '_').replace(/\s+/g, '_').slice(0, maxLen);
  return s.length > 0 ? s : 'all';
}

/**
 * One ZIP on the client: keeps Parse payloads as JSON+text (no server-side zip),
 * loads `fflate` only on demand (smaller main bundle), moderate compression.
 */
export function useAppLedgerPage() {
  const [selectedAccount, setSelectedAccount] = useState<string>('');
  const [userFilter, setUserFilter] = useState('');
  const [debouncedUserFilter, setDebouncedUserFilter] = useState('');
  const [typeFilter, setTypeFilter] = useState<string>('');
  const [page, setPage] = useState(0);
  const [pageSize, setPageSize] = useState(100);
  const [datePreset, setDatePreset] = useState<DateRangePreset>('all');
  const [dateFromInput, setDateFromInput] = useState('');
  const [dateToInput, setDateToInput] = useState('');
  const [auditorBusinessCaseId, setAuditorBusinessCaseId] = useState('');
  const [auditorExporting, setAuditorExporting] = useState(false);
  const [reconciliationResult, setReconciliationResult] = useState<FinancialReconciliationResult | null>(null);
  const [reconciliationLoading, setReconciliationLoading] = useState(false);
  const [reconciliationOpeningSnapshotId, setReconciliationOpeningSnapshotId] = useState('');
  const [openingSnapshots, setOpeningSnapshots] = useState<LedgerOpeningSnapshotRow[]>([]);
  const [openingSnapshotsLoading, setOpeningSnapshotsLoading] = useState(false);
  const [snapshotEffectiveDate, setSnapshotEffectiveDate] = useState('');
  const [snapshotLabel, setSnapshotLabel] = useState('');
  const [snapshotBalancesJson, setSnapshotBalancesJson] = useState(
    '{\n  "CLT-LIAB-AVA": { "netDebitMinusCredit": 0 },\n  "BANK-TRT-CLT": { "netDebitMinusCredit": 0 }\n}\n',
  );
  const [snapshotSaving, setSnapshotSaving] = useState(false);
  const [sortBy, setSortBy] = useState('createdAt');
  const [sortOrder, setSortOrder] = useState<SortOrder>('desc');

  useEffect(() => {
    const timer = window.setTimeout(() => {
      setDebouncedUserFilter(userFilter.trim());
    }, 300);
    return () => window.clearTimeout(timer);
  }, [userFilter]);

  useEffect(() => {
    setPage(0);
  }, [debouncedUserFilter]);

  const refreshOpeningSnapshots = useCallback(async () => {
    setOpeningSnapshotsLoading(true);
    try {
      const rows = await cloudFunction<LedgerOpeningSnapshotRow[]>('listLedgerOpeningSnapshots', { limit: 80 });
      setOpeningSnapshots(Array.isArray(rows) ? rows : []);
    } catch {
      setOpeningSnapshots([]);
    } finally {
      setOpeningSnapshotsLoading(false);
    }
  }, []);

  useEffect(() => {
    void refreshOpeningSnapshots();
  }, [refreshOpeningSnapshots]);

  const saveLedgerOpeningSnapshotRow = useCallback(async () => {
    if (!snapshotEffectiveDate.trim()) {
      window.alert('Stichtag (effectiveDate) angeben.');
      return;
    }
    let balances: Record<string, unknown>;
    try {
      balances = JSON.parse(snapshotBalancesJson) as Record<string, unknown>;
    } catch {
      window.alert('balances: kein gültiges JSON.');
      return;
    }
    setSnapshotSaving(true);
    try {
      const iso = `${snapshotEffectiveDate.trim()}T12:00:00.000Z`;
      await cloudFunction<LedgerOpeningSnapshotRow>('saveLedgerOpeningSnapshot', {
        effectiveDate: iso,
        label: snapshotLabel.trim() || undefined,
        balances,
      });
      await refreshOpeningSnapshots();
      window.alert('Snapshot gespeichert.');
    } catch (err) {
      window.alert(err instanceof Error ? err.message : 'Snapshot speichern fehlgeschlagen.');
    } finally {
      setSnapshotSaving(false);
    }
  }, [snapshotEffectiveDate, snapshotLabel, snapshotBalancesJson, refreshOpeningSnapshots]);

  const resolvedDateRange = useMemo(
    () => resolveDateRange(datePreset, dateFromInput, dateToInput),
    [datePreset, dateFromInput, dateToInput],
  );

  const onLedgerSort = useCallback(
    (field: string) => {
      const next = nextSortState(field, sortBy, sortOrder);
      setSortBy(next.sortBy);
      setSortOrder(next.sortOrder);
      setPage(0);
    },
    [sortBy, sortOrder],
  );

  const { data, isLoading, refetch } = useQuery({
    queryKey: [
      'appLedger',
      selectedAccount,
      debouncedUserFilter,
      typeFilter,
      page,
      pageSize,
      datePreset,
      dateFromInput,
      dateToInput,
      sortBy,
      sortOrder,
    ],
    queryFn: () =>
      cloudFunction<LedgerResponse>('getAppLedger', {
        ...(selectedAccount ? { account: selectedAccount } : {}),
        ...(debouncedUserFilter ? { userId: debouncedUserFilter } : {}),
        ...(typeFilter ? { transactionType: typeFilter } : {}),
        ...(resolvedDateRange.from ? { dateFrom: `${resolvedDateRange.from}T00:00:00.000Z` } : {}),
        ...(resolvedDateRange.to ? { dateTo: `${resolvedDateRange.to}T23:59:59.999Z` } : {}),
        limit: pageSize,
        skip: page * pageSize,
      sortBy,
      sortOrder,
    }),
    placeholderData: (previousData) => previousData,
    staleTime: 30_000,
  });

  const dataEntries = data?.entries;
  const dataAccounts = data?.accounts;
  const dataTotals = data?.totals;
  const rawEntries = useMemo(() => dataEntries ?? [], [dataEntries]);
  const accounts = useMemo(() => dataAccounts ?? [], [dataAccounts]);

  const entries = useMemo(() => {
    const hasDateFrom = Boolean(resolvedDateRange.from);
    const hasDateTo = Boolean(resolvedDateRange.to);
    const matches = (entry: AppLedgerEntry): boolean => {
      if (selectedAccount && entry.account !== selectedAccount) return false;
      if (typeFilter && entry.transactionType !== typeFilter) return false;
      if (hasDateFrom && new Date(entry.createdAt) < new Date(`${resolvedDateRange.from as string}T00:00:00.000Z`)) return false;
      if (hasDateTo && new Date(entry.createdAt) > new Date(`${resolvedDateRange.to as string}T23:59:59.999Z`)) return false;
      return true;
    };
    const backendMismatch = rawEntries.some((entry) => !matches(entry));
    return backendMismatch ? rawEntries.filter(matches) : rawEntries;
  }, [rawEntries, resolvedDateRange, selectedAccount, typeFilter]);

  const backendFilterMismatch = rawEntries.length !== entries.length;
  const totalCount = backendFilterMismatch ? entries.length : (data?.totalCount ?? 0);

  const totals = useMemo(() => {
    if (!backendFilterMismatch && dataTotals) {
      return dataTotals;
    }

    const nextTotals: Record<string, AccountTotals> = {};
    for (const e of entries) {
      const key = e.account;
      if (!nextTotals[key]) nextTotals[key] = { credit: 0, debit: 0, net: 0 };
      if (e.side === 'credit') {
        nextTotals[key].credit += e.amount;
        nextTotals[key].net += e.amount;
      } else {
        nextTotals[key].debit += e.amount;
        nextTotals[key].net -= e.amount;
      }
    }
    Object.keys(nextTotals).forEach((key) => {
      nextTotals[key].credit = Math.round(nextTotals[key].credit * 100) / 100;
      nextTotals[key].debit = Math.round(nextTotals[key].debit * 100) / 100;
      nextTotals[key].net = Math.round(nextTotals[key].net * 100) / 100;
    });
    return nextTotals;
  }, [backendFilterMismatch, dataTotals, entries]);

  const totalRevenue = useMemo(
    () => accounts.filter((a) => a.group === 'revenue').reduce((sum, a) => sum + (totals[a.code]?.net ?? 0), 0),
    [accounts, totals],
  );
  const totalRefunds = useMemo(
    () => accounts.filter((a) => a.group === 'expense').reduce((sum, a) => sum + (totals[a.code]?.debit ?? 0), 0),
    [accounts, totals],
  );

  const vatSummary: VATSummary | undefined = useMemo(() => {
    if (!data?.vatSummary) return undefined;
    const vatCollected = totals['PLT-TAX-VAT']?.credit ?? 0;
    const vatRemitted = totals['PLT-TAX-VAT']?.debit ?? 0;
    const inputVATClaimed = totals['PLT-TAX-VST']?.debit ?? 0;
    return {
      outputVATCollected: Math.round(vatCollected * 100) / 100,
      outputVATRemitted: Math.round(vatRemitted * 100) / 100,
      inputVATClaimed: Math.round(inputVATClaimed * 100) / 100,
      outstandingVATLiability: Math.round((vatCollected - vatRemitted - inputVATClaimed) * 100) / 100,
    };
  }, [data?.vatSummary, totals]);

  const groupedAccounts = useMemo(
    () =>
      accounts.reduce<Record<string, AccountDef[]>>((acc, a) => {
        const group = a.group || 'other';
        if (!acc[group]) acc[group] = [];
        acc[group].push(a);
        return acc;
      }, {}),
    [accounts],
  );

  const resetFilters = () => {
    setSelectedAccount('');
    setUserFilter('');
    setTypeFilter('');
    setDatePreset('all');
    setDateFromInput('');
    setDateToInput('');
    setSortBy('createdAt');
    setSortOrder('desc');
    setPage(0);
  };

  const exportAuditorFinancialPackage = useCallback(async () => {
    const range = resolveDateRange(datePreset, dateFromInput, dateToInput);
    if (!range.from || !range.to) {
      window.alert('Bitte einen Zeitraum wählen (z. B. „Letzte 30 Tage“ oder benutzerdefiniertes Von/Bis).');
      return;
    }
    setAuditorExporting(true);
    try {
      const dateFrom = `${range.from}T00:00:00.000Z`;
      const dateTo = `${range.to}T23:59:59.999Z`;
      const bc = auditorBusinessCaseId.trim();
      const res = await cloudFunction<AuditorFinancialExportResult>('exportAuditorFinancialCsv', {
        dateFrom,
        dateTo,
        limitPerSection: 8000,
        ...(bc ? { businessCaseId: bc } : {}),
      });

      const { zipSync, strToU8 } = await import('fflate');

      const fromSeg = safeExportSegment(range.from, 12);
      const toSeg = safeExportSegment(range.to, 12);
      const bcSeg = bc ? safeExportSegment(bc, 48) : 'all-cases';
      const utcSeg = safeExportSegment(new Date().toISOString().replace(/\.\d{3}Z$/, 'Z'), 24);
      const folder = `FIN1-auditor-export_${fromSeg}_${toSeg}_${bcSeg}_${utcSeg}`;
      const zipName = `${folder}.zip`;

      const dictJson = JSON.stringify(res.dataDictionary, null, 2);
      const { csv } = res;
      const files: Record<string, Uint8Array> = {
        [`${folder}/00-data-dictionary.json`]: strToU8(dictJson),
        [`${folder}/01-account-statement.csv`]: strToU8(csv.accountStatement),
        [`${folder}/02-app-ledger-entry.csv`]: strToU8(csv.appLedgerEntry),
        [`${folder}/03-document.csv`]: strToU8(csv.document),
        [`${folder}/04-wallet-transaction.csv`]: strToU8(csv.walletTransaction),
        [`${folder}/05-invoice.csv`]: strToU8(csv.invoice),
        [`${folder}/99-export-meta.json`]: strToU8(
          JSON.stringify(
            {
              generatedAt: res.generatedAt,
              parameters: res.parameters,
              rowCounts: res.rowCounts,
              archiveLayout: 'FIN1 auditor export — see 00-data-dictionary.json for column meanings.',
            },
            null,
            2,
          ),
        ),
      };

      const zipped = zipSync(files, { level: 4 });
      // Copy into a plain Uint8Array so `Blob` accepts it under strict TS (ArrayBufferLike vs ArrayBuffer).
      const zipBytes = new Uint8Array(zipped.byteLength);
      zipBytes.set(zipped);

      const blob = new Blob([zipBytes], { type: 'application/zip' });
      const url = URL.createObjectURL(blob);
      const link = document.createElement('a');
      link.href = url;
      link.download = zipName;
      link.click();
      URL.revokeObjectURL(url);
    } catch (err) {
      window.alert(err instanceof Error ? err.message : 'Prüfer-Export fehlgeschlagen.');
    } finally {
      setAuditorExporting(false);
    }
  }, [auditorBusinessCaseId, datePreset, dateFromInput, dateToInput]);

  const runFinancialReconciliation = useCallback(async () => {
    const range = resolveDateRange(datePreset, dateFromInput, dateToInput);
    if (!range.from || !range.to) {
      window.alert('Bitte einen Zeitraum wählen (gleicher Filter wie Prüferpaket).');
      return;
    }
    setReconciliationLoading(true);
    setReconciliationResult(null);
    try {
      const dateFrom = `${range.from}T00:00:00.000Z`;
      const dateTo = `${range.to}T23:59:59.999Z`;
      const trimmedOpening = reconciliationOpeningSnapshotId.trim();
      const res = await cloudFunction<FinancialReconciliationResult>('getFinancialReconciliationReport', {
        dateFrom,
        dateTo,
        maxRows: 50000,
        ...(trimmedOpening
          ? { openingSnapshotObjectId: trimmedOpening, useLatestOpeningBeforePeriod: false }
          : { useLatestOpeningBeforePeriod: true }),
      });
      setReconciliationResult(res);
    } catch (err) {
      window.alert(err instanceof Error ? err.message : 'Abstimmungs-Report fehlgeschlagen.');
    } finally {
      setReconciliationLoading(false);
    }
  }, [datePreset, dateFromInput, dateToInput, reconciliationOpeningSnapshotId]);

  const downloadReconciliationJson = useCallback(() => {
    if (!reconciliationResult) return;
    const stamp = safeExportSegment(new Date().toISOString().replace(/\.\d{3}Z$/, 'Z'), 28);
    const blob = new Blob([JSON.stringify(reconciliationResult, null, 2)], {
      type: 'application/json;charset=utf-8;',
    });
    const url = URL.createObjectURL(blob);
    const link = document.createElement('a');
    link.href = url;
    link.download = `FIN1-reconciliation_${stamp}.json`;
    link.click();
    URL.revokeObjectURL(url);
  }, [reconciliationResult]);

  const exportCSV = () => {
    if (entries.length === 0) return;
    const header = [
      'Datum',
      'Konto intern',
      'Konto extern',
      'Kontenrahmen',
      'VAT-Key',
      'Tax-Treatment',
      'Mapping-ID',
      'Mapping-Status',
      'Seite',
      'Betrag',
      'User',
      'Rolle',
      'Typ',
      'Business-Referenz',
      'Referenz',
      'Beschreibung',
    ].join(',');
    const rows = entries.map((e) =>
      [
        formatDateTime(e.createdAt),
        e.account,
        e.externalAccountNumberSnapshot || '',
        e.chartCodeSnapshot || '',
        e.vatKeySnapshot || '',
        e.taxTreatmentSnapshot || '',
        e.mappingIdSnapshot || '',
        e.mappingIdSnapshot ? 'mapped' : 'unmapped',
        e.side === 'credit' ? 'Haben' : 'Soll',
        e.amount.toFixed(2),
        e.userId,
        e.userRole,
        TRANSACTION_TYPE_LABELS[e.transactionType] || e.transactionType,
        e.metadata?.businessReference || '',
        e.referenceId,
        e.description,
      ]
        .map((v) => `"${v}"`)
        .join(','),
    );
    const csv = [header, ...rows].join('\n');
    const blob = new Blob([csv], { type: 'text/csv;charset=utf-8;' });
    const url = URL.createObjectURL(blob);
    const link = document.createElement('a');
    link.href = url;
    link.download = `app-ledger-${new Date().toISOString().slice(0, 10)}.csv`;
    link.click();
    URL.revokeObjectURL(url);
  };

  return {
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
  };
}
