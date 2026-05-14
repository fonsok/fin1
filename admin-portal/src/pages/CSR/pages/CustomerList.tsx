import { useState, useMemo, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import { useQuery } from '@tanstack/react-query';
import clsx from 'clsx';
import { Card, Button, Badge, PaginationBar } from '../../../components/ui';
import { useTheme } from '../../../context/ThemeContext';
import {
  listRowStripeClasses,
  tableBodyDivideClasses,
  tableHeaderCellTextClasses,
  tableTheadSurfaceClasses,
} from '../../../utils/tableStriping';
import { searchCustomers } from '../api';

import { adminMuted, adminPrimary } from '../../../utils/adminThemeClasses';
const CUSTOMER_PAGE_SIZE = 50;

export function CustomerListPage() {
  const { theme } = useTheme();
  const isDark = theme === 'dark';
  const navigate = useNavigate();
  const [searchQuery, setSearchQuery] = useState('');
  const [page, setPage] = useState(0);

  const { data: customers, isLoading } = useQuery({
    queryKey: ['customers-search', searchQuery],
    queryFn: () => searchCustomers(searchQuery),
    enabled: searchQuery.length >= 2,
  });

  const customerTotal = customers?.length ?? 0;
  const customerTotalPages = Math.max(1, Math.ceil(customerTotal / CUSTOMER_PAGE_SIZE));
  const pagedCustomers = useMemo(
    () => (customers ?? []).slice(page * CUSTOMER_PAGE_SIZE, (page + 1) * CUSTOMER_PAGE_SIZE),
    [customers, page]
  );

  useEffect(() => {
    setPage(0);
  }, [searchQuery]);

  useEffect(() => {
    if (page > 0 && page >= customerTotalPages) {
      setPage(Math.max(0, customerTotalPages - 1));
    }
  }, [page, customerTotalPages]);

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <h1 className={clsx('text-2xl font-bold', adminPrimary(isDark))}>Kunden</h1>
        <Button onClick={() => navigate('/csr/tickets/new')}>
          Neues Ticket
        </Button>
      </div>

      <Card>
        <div className="mb-4">
          <input
            type="text"
            value={searchQuery}
            onChange={(e) => setSearchQuery(e.target.value)}
            placeholder="Kunde suchen (Name, E-Mail, ID)..."
            className={clsx(
              'w-full px-4 py-2 border rounded-lg focus:outline-none focus:ring-2 focus:ring-fin1-primary',
              isDark
                ? 'bg-slate-900/70 border-slate-600 text-slate-100 placeholder:text-slate-400'
                : 'bg-white border-gray-300 text-gray-900',
            )}
          />
        </div>

        {isLoading && (
          <div className="text-center py-8">
            <div className="animate-spin w-8 h-8 border-4 border-fin1-primary border-t-transparent rounded-full mx-auto"></div>
          </div>
        )}

        {customers && customers.length > 0 && (
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
                    Name
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
                    Status
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
                    Aktionen
                  </th>
                </tr>
              </thead>
              <tbody className={tableBodyDivideClasses(isDark)}>
                {pagedCustomers.map((customer, index) => (
                  <tr key={customer.objectId} className={listRowStripeClasses(isDark, index)}>
                    <td
                      className={clsx(
                        'px-6 py-4 text-sm',
                        adminPrimary(isDark),
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
                    <td className="px-6 py-4">
                      <Badge variant={customer.status === 'active' ? 'success' : 'neutral'}>
                        {customer.status}
                      </Badge>
                    </td>
                    <td className="px-6 py-4">
                      {customer.kycStatus && (
                        <Badge variant={customer.kycStatus === 'verified' ? 'success' : 'warning'}>
                          {customer.kycStatus}
                        </Badge>
                      )}
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
                ))}
              </tbody>
            </table>
          </div>
            <PaginationBar
              page={page}
              pageSize={CUSTOMER_PAGE_SIZE}
              total={customerTotal}
              itemLabel="Kunden"
              isDark={isDark}
              onPageChange={setPage}
            />
          </>
        )}

        {customers && customers.length === 0 && searchQuery.length >= 2 && (
          <div className={clsx('text-center py-8', adminMuted(isDark))}>
            Keine Kunden gefunden
          </div>
        )}

        {!searchQuery && (
          <div className={clsx('text-center py-8', adminMuted(isDark))}>
            Geben Sie mindestens 2 Zeichen ein, um zu suchen
          </div>
        )}
      </Card>
    </div>
  );
}
