import React, { useCallback, useEffect, useState } from 'react';
import { useQuery } from '@tanstack/react-query';
import { Link } from 'react-router-dom';
import clsx from 'clsx';
import { searchUsers, type AdminUser } from '../../api/admin';
import { Card, Input, Button, Badge, PaginationBar, getStatusVariant } from '../../components/ui';
import { SortableTh, nextSortState, type SortOrder } from '../../components/table/SortableTh';
import { formatDateTime, getRoleDisplay, getStatusDisplay } from '../../utils/format';
import { useTheme } from '../../context/ThemeContext';
import { listRowStripeClasses, tableBodyDivideClasses, tableBodyCellMutedClasses, tableHeaderCellTextClasses, tableTheadSurfaceClasses } from '../../utils/tableStriping';
import { useDebounce } from '../../hooks/useDebounce';

import { adminEmptyIcon, adminMuted, adminPrimary, adminPrimaryBrand } from '../../utils/adminThemeClasses';
export function UserListPage() {
  const { theme } = useTheme();
  const isDark = theme === 'dark';
  const [searchQuery, setSearchQuery] = useState('');
  const debouncedSearch = useDebounce(searchQuery);
  const [statusFilter, setStatusFilter] = useState<string>('');
  const [page, setPage] = useState(0);
  const [pageSize, setPageSize] = useState(20);
  const [sortBy, setSortBy] = useState('createdAt');
  const [sortOrder, setSortOrder] = useState<SortOrder>('desc');

  useEffect(() => { setPage(0); }, [debouncedSearch]);

  const { data, isLoading, error } = useQuery({
    queryKey: ['users', debouncedSearch, statusFilter, page, pageSize, sortBy, sortOrder],
    queryFn: () =>
      searchUsers({
        query: debouncedSearch || undefined,
        status: statusFilter || undefined,
        limit: pageSize,
        skip: page * pageSize,
        sortBy,
        sortOrder,
      }),
    staleTime: 30_000,
  });
  const total = data?.total ?? 0;

  const onSort = useCallback((field: string) => {
    const next = nextSortState(field, sortBy, sortOrder);
    setSortBy(next.sortBy);
    setSortOrder(next.sortOrder);
    setPage(0);
  }, [sortBy, sortOrder]);

  const handleSearch = (e: React.FormEvent) => {
    e.preventDefault();
    setPage(0); // Reset to first page on new search
  };

  return (
    <div className="space-y-6">
      {/* Search & Filters */}
      <Card>
        <form onSubmit={handleSearch} className="flex flex-col sm:flex-row gap-4">
          <div className="flex-1">
            <Input
              placeholder="Suche nach Name, E-Mail oder Kunden-ID..."
              value={searchQuery}
              onChange={(e) => setSearchQuery(e.target.value)}
              icon={
                <svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z" />
                </svg>
              }
            />
          </div>
          <select
            value={statusFilter}
            onChange={(e) => {
              setStatusFilter(e.target.value);
              setPage(0);
            }}
            className={clsx(
              'px-4 py-2 border rounded-lg focus:outline-none focus:ring-2 focus:ring-fin1-primary',
              isDark ? 'bg-slate-900/70 border-slate-600 text-slate-100' : 'bg-white border-gray-300 text-gray-900'
            )}
          >
            <option value="">Alle Status</option>
            <option value="active">Aktiv</option>
            <option value="pending">Ausstehend</option>
            <option value="suspended">Gesperrt</option>
            <option value="locked">Gesperrt (locked)</option>
          </select>
          <Button type="submit">
            Suchen
          </Button>
          <select
            value={pageSize}
            onChange={(e) => {
              setPageSize(Number(e.target.value));
              setPage(0);
            }}
            className={clsx(
              'px-4 py-2 border rounded-lg focus:outline-none focus:ring-2 focus:ring-fin1-primary',
              isDark ? 'bg-slate-900/70 border-slate-600 text-slate-100' : 'bg-white border-gray-300 text-gray-900'
            )}
          >
            <option value={20}>20 / Seite</option>
            <option value={50}>50 / Seite</option>
            <option value={100}>100 / Seite</option>
          </select>
        </form>
      </Card>

      {/* Results */}
      <Card padding="none">
        {isLoading ? (
          <div className="p-8 text-center">
            <div className="animate-spin w-8 h-8 border-4 border-fin1-primary border-t-transparent rounded-full mx-auto"></div>
            <p className={clsx('mt-4', adminMuted(isDark))}>Laden...</p>
          </div>
        ) : error ? (
          <div className="p-8 text-center">
            <p className={clsx(isDark ? 'text-red-400' : 'text-red-500')}>Fehler beim Laden der Benutzer</p>
          </div>
        ) : !data?.users?.length ? (
          <div className="p-8 text-center">
            <svg
              className={clsx('w-12 h-12 mx-auto mb-4', adminEmptyIcon(isDark))}
              fill="none"
              stroke="currentColor"
              viewBox="0 0 24 24"
            >
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M17 20h5v-2a3 3 0 00-5.356-1.857M17 20H7m10 0v-2c0-.656-.126-1.283-.356-1.857M7 20H2v-2a3 3 0 015.356-1.857M7 20v-2c0-.656.126-1.283.356-1.857m0 0a5.002 5.002 0 019.288 0M15 7a3 3 0 11-6 0 3 3 0 016 0zm6 3a2 2 0 11-4 0 2 2 0 014 0zM7 10a2 2 0 11-4 0 2 2 0 014 0z" />
            </svg>
            <p className={clsx(adminMuted(isDark))}>Keine Benutzer gefunden</p>
          </div>
        ) : (
          <>
            {/* Table */}
            <div className="overflow-x-auto">
              <table className="w-full">
                <thead className={tableTheadSurfaceClasses(isDark)}>
                  <tr>
                    <SortableTh
                      label="Benutzer"
                      field="lastName"
                      sortBy={sortBy}
                      sortOrder={sortOrder}
                      onSort={onSort}
                      className={clsx('px-6 py-3', tableHeaderCellTextClasses(isDark))}
                    />
                    <th className={clsx('px-6 py-3 text-left text-xs font-medium uppercase tracking-wider', tableHeaderCellTextClasses(isDark))}>
                      Kunden-ID
                    </th>
                    <th className={clsx('px-6 py-3 text-left text-xs font-medium uppercase tracking-wider', tableHeaderCellTextClasses(isDark))}>
                      Rolle
                    </th>
                    <th className={clsx('px-6 py-3 text-left text-xs font-medium uppercase tracking-wider', tableHeaderCellTextClasses(isDark))}>
                      Status
                    </th>
                    <th className={clsx('px-6 py-3 text-left text-xs font-medium uppercase tracking-wider', tableHeaderCellTextClasses(isDark))}>
                      KYC
                    </th>
                    <SortableTh
                      label="Registriert"
                      field="createdAt"
                      sortBy={sortBy}
                      sortOrder={sortOrder}
                      onSort={onSort}
                      className={clsx('px-6 py-3', tableHeaderCellTextClasses(isDark))}
                    />
                    <th className={clsx('px-6 py-3 text-right text-xs font-medium uppercase tracking-wider', tableHeaderCellTextClasses(isDark))}>
                      Aktionen
                    </th>
                  </tr>
                </thead>
                <tbody className={tableBodyDivideClasses(isDark)}>
                  {data.users.map((user: AdminUser, index: number) => (
                    <tr key={user.objectId} className={listRowStripeClasses(isDark, index)}>
                      <td className="px-6 py-4 whitespace-nowrap">
                        <div className="flex items-center">
                          <div
                            className={clsx(
                              'w-10 h-10 rounded-full flex items-center justify-center',
                              isDark ? 'bg-slate-800 border border-slate-600' : 'bg-fin1-light'
                            )}
                          >
                            <span className={clsx('font-medium', adminPrimaryBrand(isDark))}>
                              {user.firstName?.[0] || user.email?.[0]?.toUpperCase() || '?'}
                            </span>
                          </div>
                          <div className="ml-4">
                            <p className={clsx('text-sm font-medium', adminPrimary(isDark))}>
                              {user.firstName && user.lastName
                                ? `${user.firstName} ${user.lastName}`
                                : user.username || 'Unbekannt'}
                            </p>
                            <p className={clsx('text-sm', tableBodyCellMutedClasses(isDark))}>{user.email}</p>
                          </div>
                        </div>
                      </td>
                      <td className="px-6 py-4 whitespace-nowrap">
                        <span className={clsx('text-sm font-mono', adminPrimary(isDark))}>
                          {user.customerNumber || '-'}
                        </span>
                      </td>
                      <td className="px-6 py-4 whitespace-nowrap">
                        <span className={clsx('text-sm', adminPrimary(isDark))}>
                          {getRoleDisplay(user.role)}
                        </span>
                      </td>
                      <td className="px-6 py-4 whitespace-nowrap">
                        <Badge variant={getStatusVariant(user.status)}>
                          {getStatusDisplay(user.status)}
                        </Badge>
                      </td>
                      <td className="px-6 py-4 whitespace-nowrap">
                        <Badge variant={getStatusVariant(user.kycStatus)}>
                          {getStatusDisplay(user.kycStatus)}
                        </Badge>
                      </td>
                      <td className={clsx('px-6 py-4 whitespace-nowrap text-sm', tableBodyCellMutedClasses(isDark))}>
                        {formatDateTime(user.createdAt)}
                      </td>
                      <td className="px-6 py-4 whitespace-nowrap text-right text-sm">
                        <Link
                          to={`/users/${user.objectId}`}
                          className={clsx(
                            'font-medium',
                            isDark ? 'text-sky-400 hover:text-sky-300' : 'text-fin1-primary hover:text-fin1-secondary',
                          )}
                        >
                          Details →
                        </Link>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>

            {/* Pagination */}
            <PaginationBar
              page={page}
              pageSize={pageSize}
              total={total}
              itemLabel="Benutzern"
              isDark={isDark}
              onPageChange={setPage}
            />
          </>
        )}
      </Card>
    </div>
  );
}
