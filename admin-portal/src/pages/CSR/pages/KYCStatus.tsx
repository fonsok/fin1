import { useState, useMemo, useEffect, useCallback } from 'react';
import { useQuery } from '@tanstack/react-query';
import { useNavigate } from 'react-router-dom';
import clsx from 'clsx';
import { Card, Badge, Button, PaginationBar } from '../../../components/ui';
import { useTheme } from '../../../context/ThemeContext';
import { formatDateTime } from '../../../utils/format';
import {
  listRowStripeClasses,
  tableBodyDivideClasses,
  tableHeaderCellTextClasses,
  tableTheadSurfaceClasses,
} from '../../../utils/tableStriping';
import { searchCustomers, getCustomerKYCStatus } from '../api';

const KYC_PAGE_SIZE = 50;

export function KYCStatusPage() {
  const { theme } = useTheme();
  const isDark = theme === 'dark';
  const navigate = useNavigate();
  const [statusFilter, setStatusFilter] = useState<'all' | 'verified' | 'pending' | 'rejected'>('all');
  const [searchQuery, setSearchQuery] = useState('');
  const [page, setPage] = useState(0);

  const { data: customers, isLoading } = useQuery({
    queryKey: ['customers-kyc', searchQuery],
    queryFn: () => searchCustomers(searchQuery),
    enabled: searchQuery.length >= 2,
  });

  // Fetch KYC status for each customer
  const userIds = customers?.map(c => c.objectId) || [];
  const { data: kycStatuses } = useQuery({
    queryKey: ['kyc-statuses', userIds],
    queryFn: async () => {
      const statuses = await Promise.all(
        userIds.map(async (id) => {
          try {
            const status = await getCustomerKYCStatus(id);
            return { userId: id, status };
          } catch {
            return { userId: id, status: null };
          }
        })
      );
      return statuses;
    },
    enabled: userIds.length > 0,
  });

  const getKYCStatus = useCallback(
    (uid: string) => kycStatuses?.find((s) => s.userId === uid)?.status,
    [kycStatuses],
  );

  const filteredCustomers = useMemo(
    () =>
      customers?.filter((customer) => {
        if (statusFilter === 'all') return true;
        const kyc = getKYCStatus(customer.objectId);
        if (!kyc) return statusFilter === 'pending';
        return kyc.status === statusFilter;
      }) || [],
    [customers, statusFilter, getKYCStatus],
  );

  const kycListTotal = filteredCustomers.length;
  const kycTotalPages = Math.max(1, Math.ceil(kycListTotal / KYC_PAGE_SIZE));
  const pagedFilteredCustomers = useMemo(
    () => filteredCustomers.slice(page * KYC_PAGE_SIZE, (page + 1) * KYC_PAGE_SIZE),
    [filteredCustomers, page]
  );

  useEffect(() => {
    setPage(0);
  }, [searchQuery, statusFilter]);

  useEffect(() => {
    if (page > 0 && page >= kycTotalPages) {
      setPage(Math.max(0, kycTotalPages - 1));
    }
  }, [page, kycTotalPages]);

  const getStatusBadge = (status: string | undefined) => {
    switch (status) {
      case 'verified':
        return <Badge variant="success">Verifiziert</Badge>;
      case 'pending':
        return <Badge variant="warning">Ausstehend</Badge>;
      case 'rejected':
        return <Badge variant="danger">Abgelehnt</Badge>;
      default:
        return <Badge variant="neutral">Unbekannt</Badge>;
    }
  };

  const getStatusColor = (status: string | undefined) => {
    switch (status) {
      case 'verified':
        return isDark ? 'text-emerald-400' : 'text-green-600';
      case 'pending':
        return isDark ? 'text-orange-400' : 'text-orange-600';
      case 'rejected':
        return isDark ? 'text-red-400' : 'text-red-600';
      default:
        return isDark ? 'text-slate-400' : 'text-gray-600';
    }
  };

  const filterInputClass = clsx(
    'px-4 py-2 border rounded-lg focus:ring-2 focus:ring-fin1-primary focus:border-transparent',
    isDark
      ? 'bg-slate-900/70 border-slate-600 text-slate-100 placeholder:text-slate-400'
      : 'bg-white border-gray-300 text-gray-900 placeholder:text-gray-400',
  );
  const filterSelectClass = clsx(
    'px-4 py-2 border rounded-lg focus:ring-2 focus:ring-fin1-primary focus:border-transparent',
    isDark ? 'bg-slate-900/70 border-slate-600 text-slate-100' : 'bg-white border-gray-300 text-gray-900',
  );

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between flex-wrap gap-3">
        <h1 className={clsx('text-2xl font-bold', isDark ? 'text-slate-100' : 'text-gray-900')}>
          KYC-Status Übersicht
        </h1>
        <div className="flex gap-2">
          <input
            type="text"
            value={searchQuery}
            onChange={(e) => setSearchQuery(e.target.value)}
            placeholder="Kunde suchen..."
            className={filterInputClass}
          />
          <select
            value={statusFilter}
            onChange={(e) =>
              setStatusFilter(e.target.value as 'all' | 'verified' | 'pending' | 'rejected')
            }
            className={filterSelectClass}
          >
            <option value="all">Alle Status</option>
            <option value="verified">Verifiziert</option>
            <option value="pending">Ausstehend</option>
            <option value="rejected">Abgelehnt</option>
          </select>
        </div>
      </div>

      {isLoading ? (
        <Card>
          <div className="text-center py-8">
            <div className="animate-spin w-8 h-8 border-4 border-fin1-primary border-t-transparent rounded-full mx-auto"></div>
          </div>
        </Card>
      ) : filteredCustomers.length === 0 ? (
        <Card>
          <div className="text-center py-8">
            <p className={clsx(isDark ? 'text-slate-400' : 'text-gray-500')}>
              {searchQuery.length < 2
                ? 'Geben Sie mindestens 2 Zeichen ein, um zu suchen'
                : 'Keine Kunden gefunden'}
            </p>
          </div>
        </Card>
      ) : (
        <Card padding="none">
          <>
            <div className="overflow-x-auto">
              <table className="w-full">
                <thead className={tableTheadSurfaceClasses(isDark)}>
                  <tr>
                    <th
                      className={clsx(
                        'px-6 py-3 text-left text-xs font-medium uppercase tracking-wider',
                        tableHeaderCellTextClasses(isDark),
                      )}
                    >
                      Kunde
                    </th>
                    <th
                      className={clsx(
                        'px-6 py-3 text-left text-xs font-medium uppercase tracking-wider',
                        tableHeaderCellTextClasses(isDark),
                      )}
                    >
                      E-Mail
                    </th>
                    <th
                      className={clsx(
                        'px-6 py-3 text-left text-xs font-medium uppercase tracking-wider',
                        tableHeaderCellTextClasses(isDark),
                      )}
                    >
                      KYC-Status
                    </th>
                    <th
                      className={clsx(
                        'px-6 py-3 text-left text-xs font-medium uppercase tracking-wider',
                        tableHeaderCellTextClasses(isDark),
                      )}
                    >
                      Level
                    </th>
                    <th
                      className={clsx(
                        'px-6 py-3 text-left text-xs font-medium uppercase tracking-wider',
                        tableHeaderCellTextClasses(isDark),
                      )}
                    >
                      Verifiziert
                    </th>
                    <th
                      className={clsx(
                        'px-6 py-3 text-left text-xs font-medium uppercase tracking-wider',
                        tableHeaderCellTextClasses(isDark),
                      )}
                    >
                      Aktionen
                    </th>
                  </tr>
                </thead>
                <tbody className={tableBodyDivideClasses(isDark)}>
                  {pagedFilteredCustomers.map((customer, index) => {
                    const kyc = getKYCStatus(customer.objectId);
                    return (
                      <tr key={customer.objectId} className={listRowStripeClasses(isDark, index)}>
                        <td
                          className={clsx(
                            'px-6 py-4 text-sm',
                            isDark ? 'text-slate-100' : 'text-gray-900',
                          )}
                        >
                          {customer.fullName || `${customer.firstName} ${customer.lastName}` || '-'}
                        </td>
                        <td
                          className={clsx(
                            'px-6 py-4 text-sm',
                            isDark ? 'text-slate-300' : 'text-gray-900',
                          )}
                        >
                          {customer.email}
                        </td>
                        <td className="px-6 py-4">{getStatusBadge(kyc?.status)}</td>
                        <td className="px-6 py-4">
                          <span className={getStatusColor(kyc?.status)}>
                            {kyc?.level || '-'}
                          </span>
                        </td>
                        <td
                          className={clsx(
                            'px-6 py-4 text-sm',
                            isDark ? 'text-slate-400' : 'text-gray-500',
                          )}
                        >
                          {kyc?.verifiedAt ? formatDateTime(kyc.verifiedAt) : '-'}
                        </td>
                        <td className="px-6 py-4">
                          <Button
                            variant="secondary"
                            size="sm"
                            onClick={() => navigate(`/csr/customers/${customer.objectId}`)}
                          >
                            Details
                          </Button>
                        </td>
                      </tr>
                    );
                  })}
                </tbody>
              </table>
            </div>
            <PaginationBar
              page={page}
              pageSize={KYC_PAGE_SIZE}
              total={kycListTotal}
              itemLabel="Einträge"
              isDark={isDark}
              onPageChange={setPage}
            />
          </>
        </Card>
      )}

      {/* Summary Stats */}
      {customers && customers.length > 0 && (
        <div className="grid grid-cols-1 md:grid-cols-4 gap-4">
          <Card>
            <div className="text-center">
              <div className={clsx('text-2xl font-bold', isDark ? 'text-slate-100' : 'text-gray-900')}>
                {customers.length}
              </div>
              <div className={clsx('text-sm', isDark ? 'text-slate-400' : 'text-gray-500')}>Gesamt Kunden</div>
            </div>
          </Card>
          <Card>
            <div className="text-center">
              <div className={clsx('text-2xl font-bold', isDark ? 'text-emerald-400' : 'text-green-600')}>
                {kycStatuses?.filter(s => s.status?.status === 'verified').length || 0}
              </div>
              <div className={clsx('text-sm', isDark ? 'text-slate-400' : 'text-gray-500')}>Verifiziert</div>
            </div>
          </Card>
          <Card>
            <div className="text-center">
              <div className={clsx('text-2xl font-bold', isDark ? 'text-orange-400' : 'text-orange-600')}>
                {kycStatuses?.filter(s => s.status?.status === 'pending' || !s.status).length || 0}
              </div>
              <div className={clsx('text-sm', isDark ? 'text-slate-400' : 'text-gray-500')}>Ausstehend</div>
            </div>
          </Card>
          <Card>
            <div className="text-center">
              <div className={clsx('text-2xl font-bold', isDark ? 'text-red-400' : 'text-red-600')}>
                {kycStatuses?.filter(s => s.status?.status === 'rejected').length || 0}
              </div>
              <div className={clsx('text-sm', isDark ? 'text-slate-400' : 'text-gray-500')}>Abgelehnt</div>
            </div>
          </Card>
        </div>
      )}
    </div>
  );
}
