import { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { useQuery } from '@tanstack/react-query';
import { Card, Button, Badge } from '../../../components/ui';
import { searchCustomers } from '../api';

export function CustomerListPage() {
  const navigate = useNavigate();
  const [searchQuery, setSearchQuery] = useState('');

  const { data: customers, isLoading } = useQuery({
    queryKey: ['customers-search', searchQuery],
    queryFn: () => searchCustomers(searchQuery),
    enabled: searchQuery.length >= 2,
  });

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <h1 className="text-2xl font-bold">Kunden</h1>
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
            className="w-full px-4 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-fin1-primary"
          />
        </div>

        {isLoading && (
          <div className="text-center py-8">
            <div className="animate-spin w-8 h-8 border-4 border-fin1-primary border-t-transparent rounded-full mx-auto"></div>
          </div>
        )}

        {customers && customers.length > 0 && (
          <div className="overflow-x-auto">
            <table className="w-full">
              <thead className="bg-gray-50 border-b">
                <tr>
                  <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">
                    Name
                  </th>
                  <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">
                    E-Mail
                  </th>
                  <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">
                    Status
                  </th>
                  <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">
                    KYC-Status
                  </th>
                  <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">
                    Aktionen
                  </th>
                </tr>
              </thead>
              <tbody className="divide-y">
                {customers.map((customer) => (
                  <tr key={customer.objectId} className="hover:bg-gray-50">
                    <td className="px-6 py-4">
                      {customer.fullName || `${customer.firstName} ${customer.lastName}` || '-'}
                    </td>
                    <td className="px-6 py-4">{customer.email}</td>
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
        )}

        {customers && customers.length === 0 && searchQuery.length >= 2 && (
          <div className="text-center py-8 text-gray-500">
            Keine Kunden gefunden
          </div>
        )}

        {!searchQuery && (
          <div className="text-center py-8 text-gray-500">
            Geben Sie mindestens 2 Zeichen ein, um zu suchen
          </div>
        )}
      </Card>
    </div>
  );
}
