import { useState, useEffect } from 'react';
import { useParams, useNavigate } from 'react-router-dom';
import { useQuery } from '@tanstack/react-query';
import { Card, Button, Badge, getStatusVariant } from '../../../components/ui';
import { formatDateTime } from '../../../utils/format';
import {
  getCustomerProfile,
  getCustomerInvestments,
  getCustomerTrades,
  getCustomerDocuments,
  getCustomerKYCStatus,
  getSupportTickets,
} from '../api';

export function CustomerDetailPage() {
  const { userId } = useParams<{ userId: string }>();
  const navigate = useNavigate();

  const { data: customer, isLoading: customerLoading } = useQuery({
    queryKey: ['customer', userId],
    queryFn: () => getCustomerProfile(userId!),
    enabled: !!userId,
  });

  // Determine available tabs based on customer role
  const isTrader = customer?.role === 'trader';
  const isInvestor = customer?.role === 'investor';

  // Define tabs based on role
  const availableTabs = [
    { id: 'overview' as const, label: 'Übersicht' },
    ...(isTrader ? [{ id: 'trades' as const, label: 'Trades' }] : []),
    ...(isInvestor ? [{ id: 'investments' as const, label: 'Investments' }] : []),
    { id: 'documents' as const, label: 'Dokumente' },
    { id: 'tickets' as const, label: 'Tickets' },
  ];

  // Set initial tab based on role
  const getInitialTab = (): 'overview' | 'investments' | 'trades' | 'documents' | 'tickets' => {
    if (!customer) return 'overview';
    if (isTrader) return 'overview';
    if (isInvestor) return 'overview';
    return 'overview';
  };

  const [activeTab, setActiveTab] = useState<'overview' | 'investments' | 'trades' | 'documents' | 'tickets'>(getInitialTab());

  // Reset tab when customer changes or ensure active tab is valid for current role
  useEffect(() => {
    if (customer) {
      const isTrader = customer.role === 'trader';
      const isInvestor = customer.role === 'investor';

      // Check if current active tab is valid for this role
      const isValidTab =
        activeTab === 'overview' ||
        activeTab === 'documents' ||
        activeTab === 'tickets' ||
        (isTrader && activeTab === 'trades') ||
        (isInvestor && activeTab === 'investments');

      if (!isValidTab) {
        // If current tab is not valid, switch to overview
        setActiveTab('overview');
      }
    }
  }, [customer?.role, customer, activeTab]);

  const { data: investments } = useQuery({
    queryKey: ['customer-investments', userId],
    queryFn: () => getCustomerInvestments(userId!),
    enabled: !!userId && activeTab === 'investments',
  });

  const { data: trades } = useQuery({
    queryKey: ['customer-trades', userId],
    queryFn: () => getCustomerTrades(userId!),
    enabled: !!userId && activeTab === 'trades',
  });

  const { data: documents } = useQuery({
    queryKey: ['customer-documents', userId],
    queryFn: () => getCustomerDocuments(userId!),
    enabled: !!userId && activeTab === 'documents',
  });

  const { data: kycStatus } = useQuery({
    queryKey: ['customer-kyc', userId],
    queryFn: () => getCustomerKYCStatus(userId!),
    enabled: !!userId && activeTab === 'overview',
  });

  const { data: tickets } = useQuery({
    queryKey: ['customer-tickets', userId],
    queryFn: () => getSupportTickets(userId),
    enabled: !!userId && activeTab === 'tickets',
  });

  if (customerLoading) {
    return (
      <div className="flex items-center justify-center min-h-screen">
        <div className="animate-spin w-8 h-8 border-4 border-fin1-primary border-t-transparent rounded-full"></div>
      </div>
    );
  }

  if (!customer) {
    return (
      <Card>
        <div className="text-center py-8">
          <p className="text-gray-500">Kunde nicht gefunden</p>
          <Button onClick={() => navigate('/csr/customers')} className="mt-4">
            Zurück zur Liste
          </Button>
        </div>
      </Card>
    );
  }

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex items-center justify-between">
        <div>
          <button
            onClick={() => navigate('/csr/customers')}
            className="text-fin1-primary hover:underline mb-2"
          >
            ← Zurück zur Liste
          </button>
          <h1 className="text-2xl font-bold">
            {customer.fullName || `${customer.firstName} ${customer.lastName}` || customer.email}
          </h1>
          <div className="flex gap-2 mt-2">
            <Badge variant={customer.status === 'active' ? 'success' : 'neutral'}>
              {customer.status}
            </Badge>
            {customer.kycStatus && (
              <Badge variant={customer.kycStatus === 'verified' ? 'success' : 'warning'}>
                KYC: {customer.kycStatus}
              </Badge>
            )}
          </div>
        </div>
        <div className="flex gap-2">
          <Button
            variant="primary"
            onClick={() => navigate(`/csr/tickets/new?userId=${userId}`)}
          >
            <svg className="w-4 h-4 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 4v16m8-8H4" />
            </svg>
            Neues Ticket
          </Button>
        </div>
      </div>

      {/* Tabs */}
      <div className="border-b">
        <nav className="flex gap-4">
          {availableTabs.map((tab) => (
            <button
              key={tab.id}
              onClick={() => setActiveTab(tab.id)}
              className={`px-4 py-2 border-b-2 font-medium ${
                activeTab === tab.id
                  ? 'border-fin1-primary text-fin1-primary'
                  : 'border-transparent text-gray-500 hover:text-gray-700'
              }`}
            >
              {tab.label}
            </button>
          ))}
        </nav>
      </div>

      {/* Overview Tab */}
      {activeTab === 'overview' && (
        <div className="space-y-6">
          <Card>
            <h2 className="text-lg font-semibold mb-4">Kundendaten</h2>
            <div className="grid grid-cols-2 gap-4">
              <div>
                <div className="text-sm text-gray-500">E-Mail</div>
                <div className="font-medium">{customer.email}</div>
              </div>
              <div>
                <div className="text-sm text-gray-500">Kundennummer</div>
                <div className="font-medium">{customer.customerNumber}</div>
              </div>
              <div>
                <div className="text-sm text-gray-500">Rolle</div>
                <div className="font-medium">{customer.role}</div>
              </div>
              <div>
                <div className="text-sm text-gray-500">Registriert</div>
                <div className="font-medium">{formatDateTime(customer.createdAt)}</div>
              </div>
              {customer.lastLoginAt && (
                <div>
                  <div className="text-sm text-gray-500">Letzter Login</div>
                  <div className="font-medium">{formatDateTime(customer.lastLoginAt)}</div>
                </div>
              )}
            </div>
          </Card>

          {kycStatus && (
            <Card>
              <h2 className="text-lg font-semibold mb-4">KYC-Status</h2>
              <div className="space-y-2">
                <div className="flex items-center justify-between">
                  <span>Status</span>
                  <Badge variant={kycStatus.status === 'verified' ? 'success' : 'warning'}>
                    {kycStatus.status}
                  </Badge>
                </div>
                <div className="flex items-center justify-between">
                  <span>Level</span>
                  <span className="font-medium">{kycStatus.level}</span>
                </div>
                {kycStatus.verifiedAt && (
                  <div className="flex items-center justify-between">
                    <span>Verifiziert am</span>
                    <span className="font-medium">{formatDateTime(kycStatus.verifiedAt)}</span>
                  </div>
                )}
              </div>
            </Card>
          )}
        </div>
      )}

      {/* Investments Tab */}
      {activeTab === 'investments' && (
        <Card>
          <h2 className="text-lg font-semibold mb-4">Investments</h2>
          {investments && investments.length > 0 ? (
            <div className="overflow-x-auto">
              <table className="w-full">
                <thead className="bg-gray-50">
                  <tr>
                    <th className="px-4 py-2 text-left">Trader</th>
                    <th className="px-4 py-2 text-left">Betrag</th>
                    <th className="px-4 py-2 text-left">Status</th>
                    <th className="px-4 py-2 text-left">Datum</th>
                  </tr>
                </thead>
                <tbody className="divide-y">
                  {investments.map((inv) => (
                    <tr key={inv.objectId}>
                      <td className="px-4 py-2">{inv.traderName}</td>
                      <td className="px-4 py-2">{inv.amount.toFixed(2)} €</td>
                      <td className="px-4 py-2">
                        <Badge variant={inv.status === 'active' ? 'success' : 'neutral'}>
                          {inv.status}
                        </Badge>
                      </td>
                      <td className="px-4 py-2">{formatDateTime(inv.investedAt)}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          ) : (
            <p className="text-gray-500 text-center py-4">Keine Investments gefunden</p>
          )}
        </Card>
      )}

      {/* Trades Tab */}
      {activeTab === 'trades' && (
        <Card>
          <h2 className="text-lg font-semibold mb-4">Trades</h2>
          {trades && trades.length > 0 ? (
            <div className="overflow-x-auto">
              <table className="w-full">
                <thead className="bg-gray-50">
                  <tr>
                    <th className="px-4 py-2 text-left">Trader</th>
                    <th className="px-4 py-2 text-left">Typ</th>
                    <th className="px-4 py-2 text-left">Betrag</th>
                    <th className="px-4 py-2 text-left">Status</th>
                    <th className="px-4 py-2 text-left">Datum</th>
                  </tr>
                </thead>
                <tbody className="divide-y">
                  {trades.map((trade) => (
                    <tr key={trade.objectId}>
                      <td className="px-4 py-2">{trade.traderName}</td>
                      <td className="px-4 py-2">{trade.tradeType}</td>
                      <td className="px-4 py-2">{trade.amount.toFixed(2)} €</td>
                      <td className="px-4 py-2">
                        <Badge variant={trade.status === 'completed' ? 'success' : 'neutral'}>
                          {trade.status}
                        </Badge>
                      </td>
                      <td className="px-4 py-2">{formatDateTime(trade.executedAt)}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          ) : (
            <p className="text-gray-500 text-center py-4">Keine Trades gefunden</p>
          )}
        </Card>
      )}

      {/* Documents Tab */}
      {activeTab === 'documents' && (
        <Card>
          <h2 className="text-lg font-semibold mb-4">Dokumente</h2>
          {documents && documents.length > 0 ? (
            <div className="space-y-2">
              {documents.map((doc) => (
                <div
                  key={doc.objectId}
                  className="flex items-center justify-between p-3 border rounded-lg"
                >
                  <div>
                    <div className="font-medium">{doc.fileName}</div>
                    <div className="text-sm text-gray-500">{doc.documentType}</div>
                  </div>
                  <div className="flex items-center gap-4">
                    <Badge variant={doc.status === 'verified' ? 'success' : 'neutral'}>
                      {doc.status}
                    </Badge>
                    <span className="text-sm text-gray-500">{formatDateTime(doc.uploadedAt)}</span>
                  </div>
                </div>
              ))}
            </div>
          ) : (
            <p className="text-gray-500 text-center py-4">Keine Dokumente gefunden</p>
          )}
        </Card>
      )}

      {/* Tickets Tab */}
      {activeTab === 'tickets' && (
        <Card>
          <h2 className="text-lg font-semibold mb-4">Tickets</h2>
          {tickets && tickets.length > 0 ? (
            <div className="space-y-2">
              {tickets.map((ticket) => (
                <div
                  key={ticket.objectId}
                  onClick={() => navigate(`/csr/tickets/${ticket.objectId}`)}
                  className="flex items-center justify-between p-3 border rounded-lg hover:bg-gray-50 cursor-pointer"
                >
                  <div>
                    <div className="font-medium">
                      #{ticket.ticketNumber || ticket.objectId.slice(0, 8)} - {ticket.subject}
                    </div>
                    <div className="text-sm text-gray-500">{ticket.category}</div>
                  </div>
                  <Badge variant={getStatusVariant(ticket.status)}>
                    {ticket.status}
                  </Badge>
                </div>
              ))}
            </div>
          ) : (
            <p className="text-gray-500 text-center py-4">Keine Tickets gefunden</p>
          )}
        </Card>
      )}
    </div>
  );
}
