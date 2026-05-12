import clsx from 'clsx';
import { useEffect, useMemo, useState } from 'react';
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
import { listRowStripeClasses, tableBodyDivideClasses } from '../../utils/tableStriping';

const DOCUMENT_TYPE_OPTIONS: { value: string; label: string }[] = [
  { value: 'invoice', label: 'Rechnung' },
  { value: 'investorCollectionBill', label: 'Investor Collection Bill' },
  { value: 'traderCollectionBill', label: 'Trader Collection Bill' },
  { value: 'traderCreditNote', label: 'Gutschrift' },
  { value: 'investmentReservationEigenbeleg', label: 'Eigenbeleg (Reservierung)' },
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
    sortBy: 'uploadedAt',
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

  const openDocumentIdParam = searchParams.get('openDocumentId');
  const openDocumentNumberParam = searchParams.get('openDocumentNumber');

  /** Deep link aus App-Ledger: `openDocumentId` oder `openDocumentNumber` (exakt, serverseitig aufgelöst). */
  useEffect(() => {
    const open = String(openDocumentIdParam || '').trim();
    const num = String(openDocumentNumberParam || '').trim();
    if (open) {
      setDetailId(open);
      setDetailLookupNumber(null);
    } else if (num) {
      setDetailLookupNumber(num);
      setDetailId(null);
    }
  }, [openDocumentIdParam, openDocumentNumberParam]);

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
        <h1 className={clsx('text-2xl font-bold', isDark ? 'text-slate-100' : 'text-gray-900')}>Beleg-Suche</h1>
        <p className={clsx('mt-1 text-sm', isDark ? 'text-slate-400' : 'text-gray-600')}>
          Serverseitige Suche über <code className="text-xs">searchDocuments</code> (Filter Pflicht). Aus dem
          App-Ledger: „Beleg ansehen“ lädt den Beleg per objectId oder exakter Belegnummer (
          <code className="text-xs">getDocumentByLedgerReference</code>
          ) — GoB-nachvollziehbar.
        </p>
      </div>

      {(detailId || detailLookupNumber) && (
        <Card className="p-4 space-y-3">
          <div className="flex justify-between items-center">
            <h2 className={clsx('text-lg font-semibold', isDark ? 'text-slate-100' : 'text-gray-900')}>
              Beleg-Details
            </h2>
            <Button variant="secondary" size="sm" onClick={closeDocumentDetail}>
              Schließen
            </Button>
          </div>
          {detailLoading && <p className="text-sm text-slate-400">Lade Beleg…</p>}
          {detailError && (
            <p className={clsx('text-sm', isDark ? 'text-red-400' : 'text-red-600')}>
              {detailError instanceof Error ? detailError.message : String(detailError)}
            </p>
          )}
          {detail && (
            <div className="space-y-2 text-sm">
              <p>
                <span className="text-slate-400">objectId:</span>{' '}
                <code className="text-xs">{detail.objectId}</code>
              </p>
              <p>
                <span className="text-slate-400">Name:</span> {detail.name}
              </p>
              <p>
                <span className="text-slate-400">fileURL:</span>{' '}
                <code className="text-xs break-all">{detail.fileURL}</code>
              </p>
              {detail.accountingSummaryText ? (
                <pre
                  className={clsx(
                    'mt-2 max-h-96 overflow-auto rounded-lg p-3 text-xs whitespace-pre-wrap',
                    isDark ? 'bg-slate-900 text-slate-200' : 'bg-gray-100 text-gray-800',
                  )}
                >
                  {detail.accountingSummaryText}
                </pre>
              ) : (
                <p className="text-slate-500 text-xs">Kein accountingSummaryText (z. B. PDF-Beleg).</p>
              )}
            </div>
          )}
        </Card>
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
          <p className={clsx('text-sm font-medium mb-2', isDark ? 'text-slate-200' : 'text-gray-800')}>Belegtypen</p>
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
        <Card className="p-4 border-red-500/50 bg-red-500/10 text-red-200 text-sm">
          {(infinite.error as Error).message}
        </Card>
      )}

      {applied && canSearch && (
        <Card className="p-0 overflow-hidden">
          <div className={clsx('px-4 py-3 border-b', isDark ? 'border-slate-600' : 'border-gray-200')}>
            <span className={clsx('text-sm font-medium', isDark ? 'text-slate-200' : 'text-gray-800')}>
              {infinite.isFetching && !infinite.data ? 'Lade…' : `${rows.length} Treffer${infinite.hasNextPage ? ' (weitere verfügbar)' : ''}`}
            </span>
          </div>
          <div className="overflow-x-auto">
            <table className="min-w-full text-sm">
              <thead className={isDark ? 'bg-slate-700/80' : 'bg-gray-100'}>
                <tr>
                  {['Belegnr.', 'Typ', 'User', 'Investment', 'Trade', 'Datum', 'Größe', 'Aktion'].map((h) => (
                    <th key={h} className="px-3 py-2 text-left font-semibold whitespace-nowrap">
                      {h}
                    </th>
                  ))}
                </tr>
              </thead>
              <tbody className={tableBodyDivideClasses(isDark)}>
                {infinite.isFetching && rows.length === 0 ? (
                  <tr>
                    <td colSpan={8} className="px-3 py-8 text-center text-slate-400">
                      Lade…
                    </td>
                  </tr>
                ) : rows.length === 0 ? (
                  <tr>
                    <td colSpan={8} className="px-3 py-8 text-center text-slate-500">
                      Keine Treffer für diese Filter.
                    </td>
                  </tr>
                ) : (
                  rows.map((r, i) => (
                  <tr key={r.objectId} className={listRowStripeClasses(isDark, i)}>
                    <td className="px-3 py-2 font-mono text-xs">
                      {r.accountingDocumentNumber || r.documentNumber || '—'}
                    </td>
                    <td className="px-3 py-2">{r.type}</td>
                    <td className="px-3 py-2 font-mono text-xs">{r.userId || '—'}</td>
                    <td className="px-3 py-2 font-mono text-xs">{r.investmentId || '—'}</td>
                    <td className="px-3 py-2 font-mono text-xs">{r.tradeId || '—'}</td>
                    <td className="px-3 py-2 whitespace-nowrap">
                      {r.uploadedAt ? formatDateTime(new Date(r.uploadedAt)) : '—'}
                    </td>
                    <td className="px-3 py-2">{formatBytes(r.size)}</td>
                    <td className="px-3 py-2">
                      <Button
                        size="sm"
                        variant="secondary"
                        onClick={() => {
                          setDetailLookupNumber(null);
                          setDetailId(r.objectId);
                        }}
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
            <div className="p-4 border-t border-slate-600/30">
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
