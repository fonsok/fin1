import { useState } from 'react';
import clsx from 'clsx';
import { useQuery } from '@tanstack/react-query';
import { Card, Button } from '../../../components/ui';
import { useTheme } from '../../../context/ThemeContext';
import { searchCustomers } from '../api';
import type { CustomerSearchResult } from '../types';

import { adminCaption, adminControlFieldPh400, adminMuted, adminPrimary, adminSearchGlyphInteractive } from '../../../utils/adminThemeClasses';
interface CustomerSearchProps {
  onSelectCustomer: (customer: CustomerSearchResult) => void;
}

export function CustomerSearch({ onSelectCustomer }: CustomerSearchProps) {
  const { theme } = useTheme();
  const isDark = theme === 'dark';
  const [searchQuery, setSearchQuery] = useState('');

  const { data: results, isLoading, refetch } = useQuery({
    queryKey: ['customer-search', searchQuery],
    queryFn: () => searchCustomers(searchQuery),
    enabled: searchQuery.length >= 2,
  });

  const handleSearch = () => {
    if (searchQuery.length >= 2) {
      refetch();
    }
  };

  return (
    <Card>
      <h2 className={clsx('text-lg font-semibold mb-4', adminPrimary(isDark))}>
        Kundensuche
      </h2>
      <div className="space-y-4">
        <div className="flex gap-2">
          <div className="flex-1 relative">
            <input
              type="text"
              value={searchQuery}
              onChange={(e) => setSearchQuery(e.target.value)}
              onKeyPress={(e) => e.key === 'Enter' && handleSearch()}
              placeholder="Name, E-Mail oder Kundennummer..."
              className={clsx(
                'w-full px-4 py-2 border rounded-lg focus:outline-none focus:ring-2 focus:ring-fin1-primary',
                adminControlFieldPh400(isDark),
              )}
            />
            {searchQuery && (
              <button
                type="button"
                onClick={() => setSearchQuery('')}
                className={clsx(
                  'absolute right-3 top-1/2 -translate-y-1/2',
                  adminSearchGlyphInteractive(isDark),
                )}
              >
                <svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path
                    strokeLinecap="round"
                    strokeLinejoin="round"
                    strokeWidth={2}
                    d="M6 18L18 6M6 6l12 12"
                  />
                </svg>
              </button>
            )}
          </div>
          <Button onClick={handleSearch} disabled={searchQuery.length < 2 || isLoading}>
            {isLoading ? 'Suche...' : 'Suchen'}
          </Button>
        </div>

        {isLoading && (
          <div className="text-center py-4">
            <div className="animate-spin w-6 h-6 border-2 border-fin1-primary border-t-transparent rounded-full mx-auto"></div>
          </div>
        )}

        {results && results.length > 0 && (
          <div className="space-y-2">
            {results.map((customer) => (
              <div
                key={customer.objectId}
                onClick={() => onSelectCustomer(customer)}
                className={clsx(
                  'p-3 border rounded-lg cursor-pointer transition-colors',
                  isDark
                    ? 'border-slate-600 bg-slate-900/30 hover:bg-slate-800/80'
                    : 'border-gray-200 hover:bg-gray-50',
                )}
              >
                <div className="flex items-center justify-between">
                  <div>
                    <div className={clsx('font-medium', adminPrimary(isDark))}>
                      {customer.fullName || `${customer.firstName} ${customer.lastName}` || customer.email}
                    </div>
                    <div className={clsx('text-sm', adminMuted(isDark))}>{customer.email}</div>
                    {customer.customerNumber && (
                      <div className={clsx('text-xs', adminCaption(isDark))}>
                        Nr.: {customer.customerNumber}
                      </div>
                    )}
                  </div>
                  <div className="flex items-center gap-2">
                    {customer.status && (
                      <span
                        className={clsx(
                          'px-2 py-1 text-xs rounded',
                          customer.status === 'active'
                            ? isDark
                              ? 'bg-emerald-950/60 text-emerald-300 border border-emerald-800/60'
                              : 'bg-green-100 text-green-800'
                            : isDark
                              ? 'bg-slate-700 text-slate-200 border border-slate-500'
                              : 'bg-gray-100 text-gray-800',
                        )}
                      >
                        {customer.status}
                      </span>
                    )}
                    <svg
                      className={clsx('w-5 h-5', adminCaption(isDark))}
                      fill="none"
                      stroke="currentColor"
                      viewBox="0 0 24 24"
                    >
                      <path
                        strokeLinecap="round"
                        strokeLinejoin="round"
                        strokeWidth={2}
                        d="M9 5l7 7-7 7"
                      />
                    </svg>
                  </div>
                </div>
              </div>
            ))}
          </div>
        )}

        {results && results.length === 0 && searchQuery.length >= 2 && !isLoading && (
          <div className={clsx('text-center py-4', adminMuted(isDark))}>
            Keine Kunden gefunden
          </div>
        )}
      </div>
    </Card>
  );
}
