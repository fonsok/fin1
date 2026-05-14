import { useCallback, useState } from 'react';
import { useQuery } from '@tanstack/react-query';
import { getCompanyKybSubmissions, type KybSubmission } from '../../api/admin';
import { nextSortState, type SortOrder } from '../../components/table/SortableTh';
import { Card, Button, Badge, PaginationBar } from '../../components/ui';
import { useAuth } from '../../context/AuthContext';
import { useTheme } from '../../context/ThemeContext';
import clsx from 'clsx';
import { KYBSubmissionTable } from './components/KYBSubmissionTable';
import { KYBDetailModal } from './components/KYBDetailModal';
import { KYBDecisionModal } from './components/KYBDecisionModal';

type TabId = 'pending_review' | 'more_info_requested' | 'approved' | 'rejected' | 'all';

const TABS: { id: TabId; label: string; icon: string }[] = [
  { id: 'pending_review', label: 'Ausstehend', icon: '⏳' },
  { id: 'more_info_requested', label: 'Nachbesserung', icon: '📋' },
  { id: 'approved', label: 'Genehmigt', icon: '✅' },
  { id: 'rejected', label: 'Abgelehnt', icon: '❌' },
  { id: 'all', label: 'Alle', icon: '📋' },
];

export function KYBReviewPage() {
  const { hasPermission } = useAuth();
  const canReviewKyb = hasPermission('reviewCompanyKyb');
  const { theme } = useTheme();
  const isDark = theme === 'dark';
  const [activeTab, setActiveTab] = useState<TabId>('pending_review');
  const [page, setPage] = useState(0);
  const [pageSize, setPageSize] = useState(50);
  const [detailUserId, setDetailUserId] = useState<string | null>(null);
  const [decisionTarget, setDecisionTarget] = useState<KybSubmission | null>(null);
  const [sortBy, setSortBy] = useState('companyKybCompletedAt');
  const [sortOrder, setSortOrder] = useState<SortOrder>('desc');

  const { data, isLoading, error, refetch } = useQuery({
    queryKey: ['kybSubmissions', activeTab, page, pageSize, sortBy, sortOrder],
    queryFn: () =>
      getCompanyKybSubmissions({
        status: activeTab,
        limit: pageSize,
        skip: page * pageSize,
        sortBy,
        sortOrder,
      }),
    staleTime: 30_000,
    refetchInterval: 30_000,
  });

  const onKybSort = useCallback(
    (field: string) => {
      const next = nextSortState(field, sortBy, sortOrder);
      setSortBy(next.sortBy);
      setSortOrder(next.sortOrder);
      setPage(0);
    },
    [sortBy, sortOrder],
  );

  const submissions = data?.submissions ?? [];
  const total = data?.total ?? 0;

  function handleReview(submission: KybSubmission) {
    setDecisionTarget(submission);
  }

  function handleViewDetail(userId: string) {
    setDetailUserId(userId);
  }

  function handleDecisionComplete() {
    setDecisionTarget(null);
    setDetailUserId(null);
    refetch();
  }

  return (
    <div className="space-y-6">
      <Card>
        <div className="flex items-center justify-between">
          <div>
            <h1 className={clsx('text-2xl font-bold', isDark ? 'text-slate-100' : 'text-gray-900')}>
              KYB-Status
            </h1>
            <p className={clsx('text-sm mt-1', isDark ? 'text-slate-400' : 'text-gray-500')}>
              {canReviewKyb
                ? 'Firmenkonten-Identitätsprüfung verwalten'
                : 'Übersicht eingereichter Firmen-KYB (Ansicht)'}
            </p>
          </div>
          <div className="flex items-center gap-3">
            {activeTab === 'pending_review' && total > 0 && (
              <Badge variant="warning" size="md">{total} ausstehend</Badge>
            )}
            {activeTab === 'more_info_requested' && total > 0 && (
              <Badge variant="warning" size="md">{total} Nachbesserung</Badge>
            )}
            <Button variant="secondary" size="sm" onClick={() => refetch()}>
              Aktualisieren
            </Button>
          </div>
        </div>
      </Card>

      <Card padding="none">
        <div className={clsx(
          'flex border-b overflow-x-auto',
          isDark ? 'border-slate-600' : 'border-gray-200',
        )}>
          {TABS.map((tab) => (
            <button
              key={tab.id}
              type="button"
              onClick={() => {
                setActiveTab(tab.id);
                setPage(0);
              }}
              className={clsx(
                'flex items-center gap-2 px-5 py-3 text-sm font-medium border-b-2 transition-colors whitespace-nowrap',
                activeTab === tab.id
                  ? 'border-fin1-primary text-fin1-primary'
                  : isDark
                    ? 'border-transparent text-slate-400 hover:text-slate-200 hover:border-slate-500'
                    : 'border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300',
              )}
            >
              <span>{tab.icon}</span>
              <span>{tab.label}</span>
              {activeTab === tab.id && total > 0 && (
                <span className="ml-1 px-2 py-0.5 text-xs font-semibold rounded-full bg-fin1-primary text-white">
                  {total}
                </span>
              )}
            </button>
          ))}
          <div className="ml-auto px-4 py-2">
            <select
              value={pageSize}
              onChange={(e) => {
                setPageSize(Number(e.target.value));
                setPage(0);
              }}
              className={clsx(
                'px-3 py-1.5 text-sm border rounded-lg',
                isDark ? 'bg-slate-900/70 border-slate-600 text-slate-100' : 'bg-white border-gray-300 text-gray-900',
              )}
            >
              <option value={50}>50 / Seite</option>
              <option value={100}>100 / Seite</option>
              <option value={250}>250 / Seite</option>
            </select>
          </div>
        </div>

        <div className="p-6">
          {isLoading ? (
            <div className="flex items-center justify-center py-12">
              <div className="animate-spin w-8 h-8 border-4 border-fin1-primary border-t-transparent rounded-full" />
            </div>
          ) : error ? (
            <div className="text-center py-12">
              <p className={clsx('text-sm', isDark ? 'text-red-400' : 'text-red-600')}>
                Fehler beim Laden der KYB-Einreichungen.
              </p>
              <Button variant="secondary" size="sm" className="mt-4" onClick={() => refetch()}>
                Erneut versuchen
              </Button>
            </div>
          ) : submissions.length === 0 ? (
            <div className="text-center py-12">
              <div className="text-4xl mb-3">🏢</div>
              <p className={clsx('text-lg font-medium', isDark ? 'text-slate-300' : 'text-gray-700')}>
                Keine Einreichungen
              </p>
              <p className={clsx('text-sm mt-1', isDark ? 'text-slate-400' : 'text-gray-500')}>
                {activeTab === 'pending_review'
                  ? 'Derzeit liegen keine ausstehenden Firmen-KYB-Einreichungen vor.'
                  : 'Keine Einreichungen in dieser Kategorie.'}
              </p>
            </div>
          ) : (
            <>
              <KYBSubmissionTable
                submissions={submissions}
                onViewDetail={handleViewDetail}
                onReview={handleReview}
                showActions={activeTab === 'pending_review'}
                canReview={canReviewKyb}
                sortBy={sortBy}
                sortOrder={sortOrder}
                onSort={onKybSort}
              />
              <div className="mt-4">
                <PaginationBar
                  page={page}
                  pageSize={pageSize}
                  total={total}
                  itemLabel="Einträgen"
                  isDark={isDark}
                  onPageChange={setPage}
                />
              </div>
            </>
          )}
        </div>
      </Card>

      {detailUserId && (
        <KYBDetailModal
          userId={detailUserId}
          onClose={() => setDetailUserId(null)}
          onReview={(submission) => {
            setDetailUserId(null);
            setDecisionTarget(submission);
          }}
        />
      )}

      {decisionTarget && (
        <KYBDecisionModal
          submission={decisionTarget}
          onClose={() => setDecisionTarget(null)}
          onComplete={handleDecisionComplete}
        />
      )}
    </div>
  );
}
