import { useState } from 'react';
import { useQuery } from '@tanstack/react-query';
import { useNavigate } from 'react-router-dom';
import { Card, Badge, Button } from '../../../components/ui';
import { formatDateTime } from '../../../utils/format';
import { searchCustomers, getCustomerKYCStatus } from '../api';

export function KYCStatusPage() {
  const navigate = useNavigate();
  const [statusFilter, setStatusFilter] = useState<'all' | 'verified' | 'pending' | 'rejected'>('all');
  const [searchQuery, setSearchQuery] = useState('');

  const { data: customers, isLoading } = useQuery({
    queryKey: ['customers-kyc', searchQuery],
    queryFn: () => searchCustomers(searchQuery),
    enabled: searchQuery.length >= 2,
  });

  // Fetch KYC status for each customer
  const customerIds = customers?.map(c => c.objectId) || [];
  const { data: kycStatuses } = useQuery({
    queryKey: ['kyc-statuses', customerIds],
    queryFn: async () => {
      const statuses = await Promise.all(
        customerIds.map(async (id) => {
          try {
            const status = await getCustomerKYCStatus(id);
            return { customerId: id, status };
          } catch {
            return { customerId: id, status: null };
          }
        })
      );
      return statuses;
    },
    enabled: customerIds.length > 0,
  });

  const getKYCStatus = (customerId: string) => {
    return kycStatuses?.find(s => s.customerId === customerId)?.status;
  };

  const filteredCustomers = customers?.filter(customer => {
    if (statusFilter === 'all') return true;
    const kyc = getKYCStatus(customer.objectId);
    if (!kyc) return statusFilter === 'pending';
    return kyc.status === statusFilter;
  }) || [];

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
      case 'verified': return 'text-green-600';
      case 'pending': return 'text-orange-600';
      case 'rejected': return 'text-red-600';
      default: return 'text-gray-600';
    }
  };

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <h1 className="text-2xl font-bold">KYC-Status Übersicht</h1>
        <div className="flex gap-2">
          <input
            type="text"
            value={searchQuery}
            onChange={(e) => setSearchQuery(e.target.value)}
            placeholder="Kunde suchen..."
            className="px-4 py-2 border rounded-lg"
          />
          <select
            value={statusFilter}
            onChange={(e) => setStatusFilter(e.target.value as any)}
            className="px-4 py-2 border rounded-lg"
          >
            <option value="all">Alle Status</option>
            <option value="verified">Verifiziert</option>
            <option value="pending">Ausstehend</option>
            <option value="rejected">Abgelehnt</option>
          </select>
        </div>
      </div>

      <Card>
        {isLoading ? (
          <div className="text-center py-8">
            <div className="animate-spin w-8 h-8 border-4 border-fin1-primary border-t-transparent rounded-full mx-auto"></div>
          </div>
        ) : filteredCustomers.length === 0 ? (
          <div className="text-center py-8">
            <p className="text-gray-500">
              {searchQuery.length < 2
                ? 'Geben Sie mindestens 2 Zeichen ein, um zu suchen'
                : 'Keine Kunden gefunden'}
            </p>
          </div>
        ) : (
          <div className="overflow-x-auto">
            <table className="w-full">
              <thead className="bg-gray-50 border-b">
                <tr>
                  <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Kunde</th>
                  <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">E-Mail</th>
                  <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">KYC-Status</th>
                  <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Level</th>
                  <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Verifiziert</th>
                  <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Aktionen</th>
                </tr>
              </thead>
              <tbody className="divide-y">
                {filteredCustomers.map((customer) => {
                  const kyc = getKYCStatus(customer.objectId);
                  return (
                    <tr key={customer.objectId} className="hover:bg-gray-50">
                      <td className="px-6 py-4">
                        {customer.fullName || `${customer.firstName} ${customer.lastName}` || '-'}
                      </td>
                      <td className="px-6 py-4">{customer.email}</td>
                      <td className="px-6 py-4">{getStatusBadge(kyc?.status)}</td>
                      <td className="px-6 py-4">
                        <span className={getStatusColor(kyc?.status)}>
                          {kyc?.level || '-'}
                        </span>
                      </td>
                      <td className="px-6 py-4 text-sm text-gray-500">
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
        )}
      </Card>

      {/* Summary Stats */}
      {customers && customers.length > 0 && (
        <div className="grid grid-cols-1 md:grid-cols-4 gap-4">
          <Card>
            <div className="text-center">
              <div className="text-2xl font-bold text-gray-900">{customers.length}</div>
              <div className="text-sm text-gray-500">Gesamt Kunden</div>
            </div>
          </Card>
          <Card>
            <div className="text-center">
              <div className="text-2xl font-bold text-green-600">
                {kycStatuses?.filter(s => s.status?.status === 'verified').length || 0}
              </div>
              <div className="text-sm text-gray-500">Verifiziert</div>
            </div>
          </Card>
          <Card>
            <div className="text-center">
              <div className="text-2xl font-bold text-orange-600">
                {kycStatuses?.filter(s => s.status?.status === 'pending' || !s.status).length || 0}
              </div>
              <div className="text-sm text-gray-500">Ausstehend</div>
            </div>
          </Card>
          <Card>
            <div className="text-center">
              <div className="text-2xl font-bold text-red-600">
                {kycStatuses?.filter(s => s.status?.status === 'rejected').length || 0}
              </div>
              <div className="text-sm text-gray-500">Abgelehnt</div>
            </div>
          </Card>
        </div>
      )}
    </div>
  );
}
