import clsx from 'clsx';
import { Card, Button, Badge } from '../../../components/ui';
import { useTheme } from '../../../context/ThemeContext';
import type { CustomerSearchResult } from '../types';

// ============================================================================
// CustomerInfoSidebar Component
// ============================================================================
// Sidebar component displaying customer information and recent tickets
// in the ticket creation page.

import { adminCaption, adminMuted, adminPrimary } from '../../../utils/adminThemeClasses';
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
  const { theme } = useTheme();
  const isDark = theme === 'dark';

  if (!selectedCustomer) {
    return (
      <Card>
        <div className="text-center py-8">
          <div
            className={clsx(
              'w-16 h-16 rounded-full flex items-center justify-center mx-auto mb-4',
              isDark ? 'bg-slate-800' : 'bg-gray-100',
            )}
          >
            <svg
              className={clsx('w-8 h-8', adminCaption(isDark))}
              fill="none"
              stroke="currentColor"
              viewBox="0 0 24 24"
            >
              <path
                strokeLinecap="round"
                strokeLinejoin="round"
                strokeWidth={2}
                d="M16 7a4 4 0 11-8 0 4 4 0 018 0zM12 14a7 7 0 00-7 7h14a7 7 0 00-7-7z"
              />
            </svg>
          </div>
          <h3 className={clsx('font-medium mb-1', adminPrimary(isDark))}>
            Kein Kunde ausgewählt
          </h3>
          <p className={clsx('text-sm', adminMuted(isDark))}>
            Wählen Sie zuerst einen Kunden aus, um das Ticket zu erstellen
          </p>
        </div>
      </Card>
    );
  }

  return (
    <div className="space-y-6">
      {/* Customer Profile Preview */}
      <Card>
        <h3 className={clsx('font-semibold mb-4', adminPrimary(isDark))}>
          Kundeninformationen
        </h3>
        <div className="space-y-3">
          <div>
            <p className={clsx('text-xs uppercase tracking-wide', adminMuted(isDark))}>
              Kunde
            </p>
            <p className={clsx('font-medium', adminPrimary(isDark))}>
              {customerProfile?.fullName || selectedCustomer.email}
            </p>
          </div>
          <div>
            <p className={clsx('text-xs uppercase tracking-wide', adminMuted(isDark))}>
              E-Mail
            </p>
            <p className={clsx('text-sm', isDark ? 'text-slate-200' : 'text-gray-900')}>{selectedCustomer.email}</p>
          </div>
          <div>
            <p className={clsx('text-xs uppercase tracking-wide', adminMuted(isDark))}>
              Kunden-ID
            </p>
            <p className={clsx('text-sm font-mono', isDark ? 'text-slate-200' : 'text-gray-900')}>
              {selectedCustomer.customerNumber || '—'}
            </p>
          </div>
          <div>
            <p className={clsx('text-xs uppercase tracking-wide', adminMuted(isDark))}>
              KYC-Status
            </p>
            <Badge variant={getKYCBadgeVariant(selectedCustomer.kycStatus)}>
              {getKYCLabel(selectedCustomer.kycStatus)}
            </Badge>
          </div>
          <div>
            <p className={clsx('text-xs uppercase tracking-wide', adminMuted(isDark))}>
              Konto-Status
            </p>
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
        <h3 className={clsx('font-semibold mb-4', adminPrimary(isDark))}>
          Letzte Tickets
          {recentTickets && recentTickets.length > 0 && (
            <span className={clsx('ml-2 text-sm font-normal', adminMuted(isDark))}>
              ({recentTickets.length})
            </span>
          )}
        </h3>
        {recentTickets && recentTickets.length > 0 ? (
          <div className="space-y-3">
            {recentTickets.slice(0, 5).map((ticket) => (
              <button
                key={ticket.objectId}
                type="button"
                onClick={() => onNavigate(`/csr/tickets/${ticket.objectId}`)}
                className={clsx(
                  'w-full text-left p-3 rounded-lg transition-colors',
                  isDark
                    ? 'bg-slate-800/60 hover:bg-slate-800 border border-slate-600'
                    : 'bg-gray-50 hover:bg-gray-100',
                )}
              >
                <p className={clsx('font-medium text-sm truncate', adminPrimary(isDark))}>
                  {ticket.subject}
                </p>
                <div className="flex items-center gap-2 mt-1">
                  <Badge
                    variant={
                      ticket.status === 'open' ? 'warning' : ticket.status === 'resolved' ? 'success' : 'neutral'
                    }
                    size="sm"
                  >
                    {ticket.status}
                  </Badge>
                  <span className={clsx('text-xs', adminMuted(isDark))}>
                    {new Date(ticket.createdAt).toLocaleDateString('de-DE')}
                  </span>
                </div>
              </button>
            ))}
          </div>
        ) : (
          <p className={clsx('text-sm', adminMuted(isDark))}>Keine vorherigen Tickets</p>
        )}
      </Card>
    </div>
  );
}
