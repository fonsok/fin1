import { useState } from 'react';
import { useQuery } from '@tanstack/react-query';
import { Card, Button } from '../../../components/ui';
import { searchCustomers } from '../api';
import type { CustomerSearchResult } from '../types';

interface CustomerSearchProps {
  onSelectCustomer: (customer: CustomerSearchResult) => void;
}

export function CustomerSearch({ onSelectCustomer }: CustomerSearchProps) {
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
      <h2 className="text-lg font-semibold mb-4">Kundensuche</h2>
      <div className="space-y-4">
        <div className="flex gap-2">
          <div className="flex-1 relative">
            <input
              type="text"
              value={searchQuery}
              onChange={(e) => setSearchQuery(e.target.value)}
              onKeyPress={(e) => e.key === 'Enter' && handleSearch()}
              placeholder="Name, E-Mail oder Kundennummer..."
              className="w-full px-4 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-fin1-primary"
            />
            {searchQuery && (
              <button
                onClick={() => setSearchQuery('')}
                className="absolute right-3 top-1/2 -translate-y-1/2 text-gray-400 hover:text-gray-600"
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
                className="p-3 border border-gray-200 rounded-lg hover:bg-gray-50 cursor-pointer transition-colors"
              >
                <div className="flex items-center justify-between">
                  <div>
                    <div className="font-medium text-gray-900">
                      {customer.fullName || `${customer.firstName} ${customer.lastName}` || customer.email}
                    </div>
                    <div className="text-sm text-gray-500">{customer.email}</div>
                    {customer.customerId && (
                      <div className="text-xs text-gray-400">ID: {customer.customerId}</div>
                    )}
                  </div>
                  <div className="flex items-center gap-2">
                    {customer.status && (
                      <span
                        className={`px-2 py-1 text-xs rounded ${
                          customer.status === 'active'
                            ? 'bg-green-100 text-green-800'
                            : 'bg-gray-100 text-gray-800'
                        }`}
                      >
                        {customer.status}
                      </span>
                    )}
                    <svg
                      className="w-5 h-5 text-gray-400"
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
          <div className="text-center py-4 text-gray-500">Keine Kunden gefunden</div>
        )}
      </div>
    </Card>
  );
}
