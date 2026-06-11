import clsx from 'clsx';
import { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import { useSearchParams } from 'react-router-dom';
import { useInfiniteQuery, useQuery } from '@tanstack/react-query';
import { Card, Button, Input } from '../../components/ui';
import { useTheme } from '../../context/ThemeContext';
import {
  getDocumentByObjectId,
  getDocumentByLedgerReference,
  hasDocumentSearchPredicate,
  searchDocuments,
  type DocumentSearchItem,
} from '../../api/admin';
import { formatDateTime } from '../../utils/format';
import {
  listRowStripeClasses,
  tableBodyDivideClasses,
  tableBodyCellMutedClasses,
  tableBodyCellPrimaryClasses,
  tableHeaderCellTextClasses,
  tableTheadSurfaceClasses,
} from '../../utils/tableStriping';

import { DocumentBelegDetailPanel } from './DocumentBelegDetailPanel';
import { adminBorderChrome, adminEmphasisSoft, adminMonoHint, adminPrimary } from '../../utils/adminThemeClasses';
const DOCUMENT_TYPE_OPTIONS: { value: string; label: string }[] = [
  { value: 'invoice', label: 'Rechnung' },
  { value: 'investorCollectionBill', label: 'Investor Collection Bill' },
  { value: 'traderCollectionBill', label: 'Trader Collection Bill' },
  { value: 'traderCreditNote', label: 'Gutschrift' },
  { value: 'investmentReservationEigenbeleg', label: 'Eigenbeleg (Reservierung)' },
  { value: 'appCommissionEigenbeleg', label: 'Eigenbeleg (App-Erfolgsprovision)' },
  { value: 'poolMirrorExecutionEigenbeleg', label: 'Eigenbeleg (Pool-Mirror)' },
  { value: 'monthlyAccountStatement', label: 'Monatskontoauszug' },
  { value: 'financial', label: 'Financial' },
  { value: 'tax', label: 'Steuer' },
  { value: 'other', label: 'Sonstiges' },
];

function formatBytes(n: number): string {
  if (n < 1024) return `${n} B`;
  if (n < 1024 * 1024) return `${(n / 1024).toFixed(1)} KB`;
  return `${(n / (1024 * 1024)).toFixed(1)} MB`;
}

function formatPartyCell(row: DocumentSearchItem): string {
  const name = row.partyDisplayName?.trim();
  const id = (row.partyUserId || row.userId || '').trim();
  if (name && id) return `${name} · ${id}`;
  return name || id || '—';
}

type DraftFilters = {
  documentNumber: string;
  search: string;
  userId: string;
  investmentId: string;
  tradeId: string;
  dateFrom: string;
  dateTo: string;
  types: string[];
};

function emptyDraft(): DraftFilters {
  return {
    documentNumber: '',
    search: '',
    userId: '',
    investmentId: '',
    tradeId: '',
    dateFrom: '',
    dateTo: '',
    types: [],
  };
}

function buildParams(f: DraftFilters, skip: number): Record<string, unknown> {
  const p: Record<string, unknown> = {
    limit: 25,
    skip,
    sortBy: 'createdAt',
    sortOrder: 'desc',
  };
  if (f.documentNumber.trim()) p.documentNumber = f.documentNumber.trim();
  if (f.search.trim()) p.search = f.search.trim();
  if (f.userId.trim()) p.userId = f.userId.trim();
  if (f.investmentId.trim()) p.investmentId = f.investmentId.trim();
  if (f.tradeId.trim()) p.tradeId = f.tradeId.trim();
  if (f.types.length) p.type = f.types;
  if (f.dateFrom.trim()) p.dateFrom = `${f.dateFrom.trim()}T00:00:00.000Z`;
  if (f.dateTo.trim()) p.dateTo = `${f.dateTo.trim()}T23:59:59.999Z`;
  return p;
}

export function DocumentSearchPage(): JSX.Element {
  const { theme } = useTheme();
  const isDark = theme === 'dark';
  const [searchParams, setSearchParams] = useSearchParams();
  const [draft, setDraft] = useState<DraftFilters>(emptyDraft);
  const [applied, setApplied] = useState<DraftFilters | null>(null);
  const [detailId, setDetailId] = useState<string | null>(null);
  /** GoB: exakte Belegnummer wie `metadata.referenceDocumentNumber` am App-Ledger */
  const [detailLookupNumber, setDetailLookupNumber] = useState<string | null>(null);
  const detailPanelRef = useRef<HTMLDivElement>(null);

  const scrollToDetailPanel = useCallback(() => {
    requestAnimationFrame(() => {
      detailPanelRef.current?.scrollIntoView({ behavior: 'smooth', block: 'start' });
    });
  }, []);

  const openDocumentIdParam = searchParams.get('openDocumentId');
  const openDocumentNumberParam = searchParams.get('openDocumentNumber');
  const tradeIdParam = searchParams.get('tradeId');

  /** Deep link: Trade-Filter aus Summary Report o. ä. */
  useEffect(() => {
    const tid = String(tradeIdParam || '').trim();
    if (!tid) return;
    setDraft((d) => ({ ...d, tradeId: tid }));
    setApplied((prev) => (prev ? { ...prev, tradeId: tid } : { ...emptyDraft(), tradeId: tid }));
  }, [tradeIdParam]);

  /**
   * Deep link: Belegnummer ins Suchfeld + Suche starten (Summary Report, App-Ledger).
   * `openDocumentNumber` — Detail oben (exakt) und Listing per Substring.
   */
  useEffect(() => {
    const num = String(openDocumentNumberParam || '').trim();
    if (!num) return;
    const seeded = { ...emptyDraft(), documentNumber: num };
    setDraft(seeded);
    setApplied(seeded);
    setDetailLookupNumber(num);
    if (!openDocumentIdParam?.trim()) {
      setDetailId(null);
    }
  }, [openDocumentNumberParam, openDocumentIdParam]);

  /** Deep link: objectId — Detail oben; Belegnummer bleibt aus separatem Param. */
  useEffect(() => {
    const open = String(openDocumentIdParam || '').trim();
    if (!open) return;
    setDetailId(open);
    if (!openDocumentNumberParam?.trim()) {
      setDetailLookupNumber(null);
    }
  }, [openDocumentIdParam, openDocumentNumberParam]);

  useEffect(() => {
    if (detailId || detailLookupNumber) {
      scrollToDetailPanel();
    }
  }, [detailId, detailLookupNumber, scrollToDetailPanel]);

  const openRowDetail = useCallback(
    (row: DocumentSearchItem) => {
      const num = (row.accountingDocumentNumber || row.documentNumber || '').trim();
      setDetailId(row.objectId);
      setDetailLookupNumber(num || null);
      const next = new URLSearchParams(searchParams);
      next.set('openDocumentId', row.objectId);
      if (num) next.set('openDocumentNumber', num);
      else next.delete('openDocumentNumber');
      setSearchParams(next, { replace: true });
      scrollToDetailPanel();
    },
    [searchParams, setSearchParams, scrollToDetailPanel],
  );

  const appliedParams = useMemo(
    () => (applied ? buildParams(applied, 0) : null),
    [applied],
  );

  const canSearch = appliedParams ? hasDocumentSearchPredicate(appliedParams) : false;

  const infinite = useInfiniteQuery({
    queryKey: ['searchDocuments', applied],
    initialPageParam: 0,
    enabled: applied !== null && canSearch,
    queryFn: async ({ pageParam }) => {
      const base = buildParams(applied!, pageParam as number);
      return searchDocuments(base);
    },
    getNextPageParam: (last) => (last.hasMore ? last.skip + last.limit : undefined),
  });

  const rows: DocumentSearchItem[] = useMemo(
    () => infinite.data?.pages.flatMap((p) => p.items) ?? [],
    [infinite.data?.pages],
  );

  const {
    data: detail,
    isFetching: detailLoading,
    error: detailError,
  } = useQuery({
    queryKey: ['documentLedgerDetail', detailId, detailLookupNumber],
    queryFn: async () => {
      if (detailId) return getDocumentByObjectId(detailId);
      if (detailLookupNumber) {
        return getDocumentByLedgerReference({ referenceDocumentNumber: detailLookupNumber });
      }
      throw new Error('Kein Beleg-Kontext');
    },
    enabled: !!(detailId || detailLookupNumber),
  });

  const clearOpenDocumentQuery = () => {
    const next = new URLSearchParams(searchParams);
    let changed = false;
    if (next.has('openDocumentId')) {
      next.delete('openDocumentId');
      changed = true;
    }
    if (next.has('openDocumentNumber')) {
      next.delete('openDocumentNumber');
      changed = true;
    }
    if (changed) setSearchParams(next, { replace: true });
  };

  const closeDocumentDetail = () => {
    setDetailId(null);
    setDetailLookupNumber(null);
    clearOpenDocumentQuery();
  };

  const runSearch = () => {
    const probe = buildParams(draft, 0);
    if (!hasDocumentSearchPredicate(probe)) {
      return;
    }
    setApplied({ ...draft });
    setDetailId(null);
    setDetailLookupNumber(null);
    clearOpenDocumentQuery();
  };

  const toggleType = (value: string) => {
    setDraft((d) => {
      const has = d.types.includes(value);
      return {
        ...d,
        types: has ? d.types.filter((t) => t !== value) : [...d.types, value],
      };
    });
  };

  return (
    <div className="space-y-6">
      <div>
        <h1 className={clsx('text-2xl font-bold', adminPrimary(isDark))}>Beleg-Suche</h1>
        <p className={clsx('mt-1 text-sm', adminMonoHint(isDark))}>
          Serverseitige Suche über <code className="text-xs">searchDocuments</code> (Filter Pflicht). Aus dem
          App-Ledger: „Beleg ansehen“ lädt den Beleg per objectId oder exakter Belegnummer (
          <code className="text-xs">getDocumentByLedgerReference</code>
          ) — GoB-nachvollziehbar.
        </p>
      </div>

      {(detailId || detailLookupNumber) && (
        <div ref={detailPanelRef} className="scroll-mt-4">
        <Card className="p-4 space-y-3">
          <div className="flex justify-between items-center">
            <h2 className={clsx('text-lg font-semibold', adminPrimary(isDark))}>
              Beleg-Details
            </h2>
            <Button variant="secondary" size="sm" onClick={closeDocumentDetail}>
              Schließen
            </Button>
          </div>
          {detailLoading && (
            <p className={clsx('text-sm', tableBodyCellMutedClasses(isDark))}>Lade Beleg…</p>
          )}
          {detailError && (
            <p className={clsx('text-sm', isDark ? 'text-red-400' : 'text-red-600')}>
              {detailError instanceof Error ? detailError.message : String(detailError)}
            </p>
          )}
          {detail && <DocumentBelegDetailPanel detail={detail} isDark={isDark} />}
        </Card>
        </div>
      )}

      <Card className="p-4 space-y-4">
        <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
          <Input
            label="Belegnummer (Substring)"
            value={draft.documentNumber}
            onChange={(e) => setDraft((d) => ({ ...d, documentNumber: e.target.value }))}
          />
          <Input
            label="Volltext (Name / Nr.)"
            value={draft.search}
            onChange={(e) => setDraft((d) => ({ ...d, search: e.target.value }))}
          />
          <Input
            label="User-ID"
            value={draft.userId}
            onChange={(e) => setDraft((d) => ({ ...d, userId: e.target.value }))}
          />
          <Input
            label="Investment-ID"
            value={draft.investmentId}
            onChange={(e) => setDraft((d) => ({ ...d, investmentId: e.target.value }))}
          />
          <Input
            label="Trade-ID"
            value={draft.tradeId}
            onChange={(e) => setDraft((d) => ({ ...d, tradeId: e.target.value }))}
          />
          <div className="grid grid-cols-2 gap-2">
            <Input
              label="Datum von"
              type="date"
              value={draft.dateFrom}
              onChange={(e) => setDraft((d) => ({ ...d, dateFrom: e.target.value }))}
            />
            <Input
              label="Datum bis"
              type="date"
              value={draft.dateTo}
              onChange={(e) => setDraft((d) => ({ ...d, dateTo: e.target.value }))}
            />
          </div>
        </div>

        <div>
          <p className={clsx('text-sm font-medium mb-2', adminEmphasisSoft(isDark))}>Belegtypen</p>
          <div className="flex flex-wrap gap-2">
            {DOCUMENT_TYPE_OPTIONS.map((opt) => {
              const on = draft.types.includes(opt.value);
              return (
                <button
                  key={opt.value}
                  type="button"
                  onClick={() => toggleType(opt.value)}
                  className={clsx(
                    'rounded-lg border px-3 py-1.5 text-xs font-medium transition-colors',
                    on
                      ? 'border-fin1-primary bg-fin1-primary/15 text-fin1-primary'
                      : isDark
                        ? 'border-slate-600 text-slate-300 hover:bg-slate-700'
                        : 'border-gray-300 text-gray-700 hover:bg-gray-50',
                  )}
                >
                  {opt.label}
                </button>
              );
            })}
          </div>
        </div>

        <div className="flex flex-wrap gap-2">
          <Button onClick={runSearch} disabled={!hasDocumentSearchPredicate(buildParams(draft, 0))}>
            Suchen
          </Button>
          <Button
            variant="secondary"
            onClick={() => {
              setDraft(emptyDraft());
              setApplied(null);
              setDetailId(null);
            }}
          >
            Zurücksetzen
          </Button>
        </div>
      </Card>

      {infinite.error && (
        <Card
          className={clsx(
            'p-4 text-sm border',
            isDark ? 'border-red-500/50 bg-red-950/40 text-red-200' : 'border-red-200 bg-red-50 text-red-800',
          )}
        >
          {(infinite.error as Error).message}
        </Card>
      )}

      {applied && canSearch && (
        <Card className="p-0 overflow-hidden">
          <div className={clsx('px-4 py-3 border-b', adminBorderChrome(isDark))}>
            <span className={clsx('text-sm font-medium', adminEmphasisSoft(isDark))}>
              {infinite.isFetching && !infinite.data ? 'Lade…' : `${rows.length} Treffer${infinite.hasNextPage ? ' (weitere verfügbar)' : ''}`}
            </span>
          </div>
          <div className="overflow-x-auto">
            <table className="min-w-full text-sm">
              <thead className={tableTheadSurfaceClasses(isDark)}>
                <tr>
                  {['Belegnr.', 'Typ', 'Inhaber', 'Investment', 'Trade', 'Datum', 'Größe', 'Aktion'].map((h) => (
                    <th
                      key={h}
                      className={clsx(
                        'px-3 py-2 text-left font-semibold whitespace-nowrap text-xs uppercase tracking-wider',
                        tableHeaderCellTextClasses(isDark),
                      )}
                    >
                      {h}
                    </th>
                  ))}
                </tr>
              </thead>
              <tbody className={tableBodyDivideClasses(isDark)}>
                {infinite.isFetching && rows.length === 0 ? (
                  <tr>
                    <td colSpan={8} className={clsx('px-3 py-8 text-center text-sm', tableBodyCellMutedClasses(isDark))}>
                      Lade…
                    </td>
                  </tr>
                ) : rows.length === 0 ? (
                  <tr>
                    <td colSpan={8} className={clsx('px-3 py-8 text-center text-sm', tableBodyCellMutedClasses(isDark))}>
                      Keine Treffer für diese Filter.
                    </td>
                  </tr>
                ) : (
                  rows.map((r, i) => (
                  <tr key={r.objectId} className={listRowStripeClasses(isDark, i)}>
                    <td className={clsx('px-3 py-2 font-mono text-xs', tableBodyCellPrimaryClasses(isDark))}>
                      {r.accountingDocumentNumber || r.documentNumber || '—'}
                    </td>
                    <td className={clsx('px-3 py-2', tableBodyCellPrimaryClasses(isDark))}>{r.type}</td>
                    <td
                      className={clsx('px-3 py-2 text-xs max-w-[14rem]', tableBodyCellMutedClasses(isDark))}
                      title={formatPartyCell(r)}
                    >
                      <span className="block truncate">{formatPartyCell(r)}</span>
                      {r.partyRole && r.partyRole !== 'other' && (
                        <span className="block text-[10px] uppercase tracking-wide opacity-70">
                          {r.partyRole === 'trader' ? 'Trader' : 'Investor'}
                        </span>
                      )}
                    </td>
                    <td className={clsx('px-3 py-2 font-mono text-xs', tableBodyCellMutedClasses(isDark))}>
                      {r.investmentId || '—'}
                    </td>
                    <td className={clsx('px-3 py-2 font-mono text-xs', tableBodyCellMutedClasses(isDark))}>
                      {r.tradeId || '—'}
                    </td>
                    <td className={clsx('px-3 py-2 whitespace-nowrap', tableBodyCellMutedClasses(isDark))}>
                      {r.uploadedAt ? formatDateTime(new Date(r.uploadedAt)) : '—'}
                    </td>
                    <td className={clsx('px-3 py-2', tableBodyCellPrimaryClasses(isDark))}>{formatBytes(r.size)}</td>
                    <td className="px-3 py-2">
                      <Button
                        size="sm"
                        variant="secondary"
                        onClick={() => openRowDetail(r)}
                      >
                        Details
                      </Button>
                    </td>
                  </tr>
                  ))
                )}
              </tbody>
            </table>
          </div>
          {infinite.hasNextPage && (
            <div className={clsx('p-4 border-t', adminBorderChrome(isDark))}>
              <Button
                variant="secondary"
                onClick={() => void infinite.fetchNextPage()}
                disabled={infinite.isFetchingNextPage}
              >
                {infinite.isFetchingNextPage ? 'Lade…' : 'Mehr laden'}
              </Button>
            </div>
          )}
        </Card>
      )}
    </div>
  );
}
