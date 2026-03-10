import { useNavigate } from 'react-router-dom';
import { useQuery } from '@tanstack/react-query';
import { Card } from '../../components/ui';
import {
  getSupportTickets,
  getTicketMetrics,
} from './api';
import type { CustomerSearchResult } from './types';
import { CustomerSearch } from './components/CustomerSearch';
import { QuickActions } from './components/QuickActions';
import { RecentTickets } from './components/RecentTickets';
import { PermissionsSection } from './components/PermissionsSection';
import { useAuth } from '../../context/AuthContext';

export function CSRDashboard() {
  const { user } = useAuth();
  const navigate = useNavigate();

  const handleSelectCustomer = (customer: CustomerSearchResult) => {
    // Navigate to customer details page
    navigate(`/csr/customers/${customer.objectId}`);
  };

  // Load recent tickets
  const { data: tickets, isLoading: ticketsLoading } = useQuery({
    queryKey: ['csr-tickets'],
    queryFn: () => getSupportTickets(),
  });

  // Load metrics
  const { data: metrics } = useQuery({
    queryKey: ['csr-metrics'],
    queryFn: () => {
      const now = new Date();
      const weekAgo = new Date(now.getTime() - 7 * 24 * 60 * 60 * 1000);
      return getTicketMetrics(weekAgo, now);
    },
  });

  const activeTickets = (tickets || []).filter(
    (t) => t.status !== 'resolved' && t.status !== 'closed' && t.status !== 'archived'
  );
  const unassignedCount = activeTickets.filter((t) => !t.assignedTo).length;

  return (
    <div className="space-y-6">
      {/* Header */}
      <Card>
        <div className="flex items-center gap-4">
          <div className="w-12 h-12 bg-fin1-primary/10 rounded-lg flex items-center justify-center">
            <svg
              className="w-6 h-6 text-fin1-primary"
              fill="none"
              stroke="currentColor"
              viewBox="0 0 24 24"
            >
              <path
                strokeLinecap="round"
                strokeLinejoin="round"
                strokeWidth={2}
                d="M18.364 5.636l-3.536 3.536m0 5.656l3.536 3.536M9.172 9.172L5.636 5.636m3.536 9.192l-3.536 3.536M21 12a9 9 0 11-18 0 9 9 0 0118 0zm-5 0a4 4 0 11-8 0 4 4 0 018 0z"
              />
            </svg>
          </div>
          <div>
            <h1 className="text-2xl font-bold text-gray-900">Kundenservice-Portal</h1>
            <p className="text-sm text-gray-500">Kundendaten anzeigen und Support verwalten</p>
          </div>
          <div className="ml-auto flex items-center gap-2">
            <div className="w-2 h-2 bg-green-500 rounded-full"></div>
            <span className="text-sm text-gray-600">
              Alle Aktionen werden für Compliance-Zwecke protokolliert
            </span>
          </div>
        </div>
      </Card>

      {/* Customer Search */}
      <CustomerSearch onSelectCustomer={handleSelectCustomer} />

      {/* Quick Actions */}
      <QuickActions unassignedTicketCount={unassignedCount} />

      {/* Recent Tickets */}
      <RecentTickets tickets={activeTickets.slice(0, 5)} isLoading={ticketsLoading} />

      {/* Metrics Summary */}
      {metrics && (
        <Card>
          <h2 className="text-lg font-semibold mb-4">Wochenstatistik</h2>
          <div className="grid grid-cols-1 md:grid-cols-4 gap-4">
            <div className="text-center">
              <div className="text-2xl font-bold text-gray-900">{metrics.totalTickets}</div>
              <div className="text-sm text-gray-500">Gesamt Tickets</div>
            </div>
            <div className="text-center">
              <div className="text-2xl font-bold text-orange-600">{metrics.openTickets}</div>
              <div className="text-sm text-gray-500">Offene Tickets</div>
            </div>
            <div className="text-center">
              <div className="text-2xl font-bold text-green-600">{metrics.resolvedTickets}</div>
              <div className="text-sm text-gray-500">Gelöste Tickets</div>
            </div>
            <div className="text-center">
              <div className="text-2xl font-bold text-blue-600">
                {Math.round(metrics.averageResolutionTime / 60)}h
              </div>
              <div className="text-sm text-gray-500">Ø Lösungszeit</div>
            </div>
          </div>
        </Card>
      )}

      {/* Permissions */}
      <PermissionsSection user={user} />
    </div>
  );
}
