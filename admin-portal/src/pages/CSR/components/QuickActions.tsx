import { Card } from '../../../components/ui';
import { useNavigate } from 'react-router-dom';

interface QuickActionsProps {
  unassignedTicketCount: number;
}

export function QuickActions({ unassignedTicketCount }: QuickActionsProps) {
  const navigate = useNavigate();

  const actions = [
    {
      icon: (
        <svg className="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path
            strokeLinecap="round"
            strokeLinejoin="round"
            strokeWidth={2}
            d="M15 5v2m0 4v2m0 4v2M5 5a2 2 0 00-2 2v3a2 2 0 110 4v3a2 2 0 002 2h14a2 2 0 002-2v-3a2 2 0 110-4V7a2 2 0 00-2-2H5z"
          />
        </svg>
      ),
      title: 'Neues Ticket',
      subtitle: 'Support-Anfrage',
      color: 'bg-blue-100 text-blue-600',
      onClick: () => navigate('/csr/tickets/new'),
    },
    {
      icon: (
        <svg className="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path
            strokeLinecap="round"
            strokeLinejoin="round"
            strokeWidth={2}
            d="M9 12l2 2 4-4m5.618-4.016A11.955 11.955 0 0112 2.944a11.955 11.955 0 01-8.618 3.04A12.02 12.02 0 003 9c0 5.591 3.824 10.29 9 11.622 5.176-1.332 9-6.03 9-11.622 0-1.042-.133-2.052-.382-3.016z"
          />
        </svg>
      ),
      title: 'KYC-Prüfung',
      subtitle: 'Status anzeigen',
      color: 'bg-green-100 text-green-600',
      onClick: () => navigate('/csr/kyc'),
    },
    {
      icon: (
        <svg className="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path
            strokeLinecap="round"
            strokeLinejoin="round"
            strokeWidth={2}
            d="M9 5H7a2 2 0 00-2 2v12a2 2 0 002 2h10a2 2 0 002-2V7a2 2 0 00-2-2h-2M9 5a2 2 0 002 2h2a2 2 0 002-2M9 5a2 2 0 012-2h2a2 2 0 012 2"
          />
        </svg>
      ),
      title: 'Warteschlange',
      subtitle: 'Ticket-Zuweisung',
      color: 'bg-orange-100 text-orange-600',
      badge: unassignedTicketCount > 0 ? unassignedTicketCount.toString() : undefined,
      onClick: () => navigate('/csr/tickets/queue'),
    },
    {
      icon: (
        <svg className="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path
            strokeLinecap="round"
            strokeLinejoin="round"
            strokeWidth={2}
            d="M9 19v-6a2 2 0 00-2-2H5a2 2 0 00-2 2v6a2 2 0 002 2h2a2 2 0 002-2zm0 0V9a2 2 0 012-2h2a2 2 0 012 2v10m-6 0a2 2 0 002 2h2a2 2 0 002-2m0 0V5a2 2 0 012-2h2a2 2 0 012 2v14a2 2 0 01-2 2h-2a2 2 0 01-2-2z"
          />
        </svg>
      ),
      title: 'Analytics',
      subtitle: 'Metriken & Berichte',
      color: 'bg-purple-100 text-purple-600',
      onClick: () => navigate('/csr/analytics'),
    },
    {
      icon: (
        <svg className="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path
            strokeLinecap="round"
            strokeLinejoin="round"
            strokeWidth={2}
            d="M5 8h14M5 8a2 2 0 110-4h14a2 2 0 110 4M5 8v10a2 2 0 002 2h10a2 2 0 002-2V8m-9 4h4"
          />
        </svg>
      ),
      title: 'Archiv',
      subtitle: 'Geschlossene Tickets',
      color: 'bg-gray-100 text-gray-600',
      onClick: () => navigate('/csr/tickets/archive'),
    },
    {
      icon: (
        <svg className="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path
            strokeLinecap="round"
            strokeLinejoin="round"
            strokeWidth={2}
            d="M13 7h8m0 0v8m0-8l-8 8-4-4-6 6"
          />
        </svg>
      ),
      title: 'Trends',
      subtitle: 'Muster & Alerts',
      color: 'bg-red-100 text-red-600',
      onClick: () => navigate('/csr/trends'),
    },
    {
      icon: (
        <svg className="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path
            strokeLinecap="round"
            strokeLinejoin="round"
            strokeWidth={2}
            d="M17 20h5v-2a3 3 0 00-5.356-1.857M17 20H7m10 0v-2c0-.656-.126-1.283-.356-1.857M7 20H2v-2a3 3 0 015.356-1.857M7 20v-2c0-.656.126-1.283.356-1.857m0 0a5.002 5.002 0 019.288 0M15 7a3 3 0 11-6 0 3 3 0 016 0zm6 3a2 2 0 11-4 0 2 2 0 014 0zM7 10a2 2 0 11-4 0 2 2 0 014 0z"
          />
        </svg>
      ),
      title: 'Agent-Performance',
      subtitle: 'Team-Statistiken',
      color: 'bg-cyan-100 text-cyan-600',
      onClick: () => navigate('/csr/analytics'),
    },
    {
      icon: (
        <svg className="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path
            strokeLinecap="round"
            strokeLinejoin="round"
            strokeWidth={2}
            d="M4 6h16M4 12h16M4 18h16"
          />
        </svg>
      ),
      title: 'Massenbearbeitung',
      subtitle: 'Mehrere Tickets',
      color: 'bg-indigo-100 text-indigo-600',
      onClick: () => navigate('/csr/tickets/bulk'),
    },
    {
      icon: (
        <svg className="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path
            strokeLinecap="round"
            strokeLinejoin="round"
            strokeWidth={2}
            d="M12 6.253v13m0-13C10.832 5.477 9.246 5 7.5 5S4.168 5.477 3 6.253v13C4.168 18.477 5.754 18 7.5 18s3.332.477 4.5 1.253m0-13C13.168 5.477 14.754 5 16.5 5c1.747 0 3.332.477 4.5 1.253v13C19.832 18.477 18.247 18 16.5 18c-1.746 0-3.332.477-4.5 1.253"
          />
        </svg>
      ),
      title: 'FAQ Wissensdatenbank',
      subtitle: 'Artikel & Lösungen',
      color: 'bg-emerald-100 text-emerald-600',
      onClick: () => navigate('/csr/faqs'),
    },
  ];

  return (
    <Card>
      <h2 className="text-lg font-semibold mb-4">Schnellaktionen</h2>
      <div className="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-4 gap-4">
        {actions.map((action, index) => (
          <button
            key={index}
            onClick={action.onClick}
            className={`p-4 rounded-lg border-2 border-transparent hover:border-fin1-primary transition-all ${action.color} hover:shadow-md`}
          >
            <div className="flex items-center justify-between mb-2">
              {action.icon}
              {action.badge && (
                <span className="bg-red-500 text-white text-xs font-bold rounded-full w-5 h-5 flex items-center justify-center">
                  {action.badge}
                </span>
              )}
            </div>
            <div className="text-left">
              <div className="font-semibold text-sm">{action.title}</div>
              <div className="text-xs opacity-75">{action.subtitle}</div>
            </div>
          </button>
        ))}
      </div>
    </Card>
  );
}
