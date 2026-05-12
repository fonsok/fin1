import { Card, Button, Badge } from '../../../components/ui';
import type { CustomerSearchResult } from '../types';

// ============================================================================
// CustomerInfoSidebar Component
// ============================================================================
// Sidebar component displaying customer information and recent tickets
// in the ticket creation page.

interface CustomerInfoSidebarProps {
  selectedCustomer: CustomerSearchResult | null;
  customerProfile?: { fullName?: string } | null;
  recentTickets?: Array<{ objectId: string; subject: string; status: string; createdAt: string }>;
  onNavigate: (path: string) => void;
  getKYCBadgeVariant: (status?: string) => 'success' | 'warning' | 'danger' | 'neutral';
  getKYCLabel: (status?: string) => string;
}

export function CustomerInfoSidebar({
  selectedCustomer,
  customerProfile,
  recentTickets,
  onNavigate,
  getKYCBadgeVariant,
  getKYCLabel,
}: CustomerInfoSidebarProps): JSX.Element {
  if (!selectedCustomer) {
    return (
      <Card>
        <div className="text-center py-8">
          <div className="w-16 h-16 bg-gray-100 rounded-full flex items-center justify-center mx-auto mb-4">
            <svg className="w-8 h-8 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path
                strokeLinecap="round"
                strokeLinejoin="round"
                strokeWidth={2}
                d="M16 7a4 4 0 11-8 0 4 4 0 018 0zM12 14a7 7 0 00-7 7h14a7 7 0 00-7-7z"
              />
            </svg>
          </div>
          <h3 className="font-medium text-gray-900 mb-1">Kein Kunde ausgewählt</h3>
          <p className="text-sm text-gray-500">Wählen Sie zuerst einen Kunden aus, um das Ticket zu erstellen</p>
        </div>
      </Card>
    );
  }

  return (
    <div className="space-y-6">
      {/* Customer Profile Preview */}
      <Card>
        <h3 className="font-semibold text-gray-900 mb-4">Kundeninformationen</h3>
        <div className="space-y-3">
          <div>
            <p className="text-xs text-gray-500 uppercase tracking-wide">Kunde</p>
            <p className="font-medium">{customerProfile?.fullName || selectedCustomer.email}</p>
          </div>
          <div>
            <p className="text-xs text-gray-500 uppercase tracking-wide">E-Mail</p>
            <p className="text-sm">{selectedCustomer.email}</p>
          </div>
          <div>
            <p className="text-xs text-gray-500 uppercase tracking-wide">Kunden-ID</p>
            <p className="text-sm font-mono">{selectedCustomer.customerNumber || '—'}</p>
          </div>
          <div>
            <p className="text-xs text-gray-500 uppercase tracking-wide">KYC-Status</p>
            <Badge variant={getKYCBadgeVariant(selectedCustomer.kycStatus)}>
              {getKYCLabel(selectedCustomer.kycStatus)}
            </Badge>
          </div>
          <div>
            <p className="text-xs text-gray-500 uppercase tracking-wide">Konto-Status</p>
            <Badge variant={selectedCustomer.status === 'active' ? 'success' : 'neutral'}>
              {selectedCustomer.status === 'active' ? 'Aktiv' : selectedCustomer.status}
            </Badge>
          </div>
          <div className="pt-2">
            <Button
              variant="secondary"
              size="sm"
              className="w-full"
              onClick={() => onNavigate(`/csr/customers/${selectedCustomer.objectId}`)}
            >
              Vollständiges Profil anzeigen
            </Button>
          </div>
        </div>
      </Card>

      {/* Recent Tickets */}
      <Card>
        <h3 className="font-semibold text-gray-900 mb-4">
          Letzte Tickets
          {recentTickets && recentTickets.length > 0 && (
            <span className="ml-2 text-sm font-normal text-gray-500">({recentTickets.length})</span>
          )}
        </h3>
        {recentTickets && recentTickets.length > 0 ? (
          <div className="space-y-3">
            {recentTickets.slice(0, 5).map((ticket) => (
              <button
                key={ticket.objectId}
                onClick={() => onNavigate(`/csr/tickets/${ticket.objectId}`)}
                className="w-full text-left p-3 bg-gray-50 rounded-lg hover:bg-gray-100 transition-colors"
              >
                <p className="font-medium text-sm text-gray-900 truncate">{ticket.subject}</p>
                <div className="flex items-center gap-2 mt-1">
                  <Badge
                    variant={
                      ticket.status === 'open' ? 'warning' : ticket.status === 'resolved' ? 'success' : 'neutral'
                    }
                    size="sm"
                  >
                    {ticket.status}
                  </Badge>
                  <span className="text-xs text-gray-500">{new Date(ticket.createdAt).toLocaleDateString('de-DE')}</span>
                </div>
              </button>
            ))}
          </div>
        ) : (
          <p className="text-sm text-gray-500">Keine vorherigen Tickets</p>
        )}
      </Card>
    </div>
  );
}
