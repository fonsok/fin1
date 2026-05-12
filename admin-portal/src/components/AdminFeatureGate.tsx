import { Link, useLocation } from 'react-router-dom';
import { matchNavItemForPath, type NavItem } from '../hooks/usePermissions';
import clsx from 'clsx';
import { useTheme } from '../context/ThemeContext';

export function AdminFeatureGate({
  navItems,
  children,
}: {
  navItems: NavItem[];
  children: React.ReactNode;
}) {
  const location = useLocation();
  const { theme } = useTheme();
  const isDark = theme === 'dark';
  const gate = matchNavItemForPath(location.pathname, navItems);

  if (gate && !gate.enabled) {
    return (
      <div
        className={clsx(
          'max-w-lg mx-auto mt-16 rounded-xl border p-8 text-center shadow-sm',
          isDark ? 'border-slate-600 bg-slate-700/50 text-slate-100' : 'border-gray-200 bg-white text-gray-900',
        )}
      >
        <div className="text-4xl mb-3" aria-hidden>
          🔒
        </div>
        <h2 className="text-xl font-semibold mb-2">Kein Zugriff auf „{gate.label}“</h2>
        <p
          className={clsx('text-sm mb-6', isDark ? 'text-slate-300' : 'text-gray-600')}
        >
          Dieser Bereich ist Teil des Admin-Portals, für Ihr Konto aber nicht freigeschaltet. Wenden Sie sich
          bei Bedarf an einen Administrator mit höheren Rechten.
        </p>
        <Link
          to="/"
          className="inline-flex items-center justify-center rounded-lg bg-fin1-primary px-4 py-2 text-sm font-medium text-white hover:opacity-90"
        >
          Zum Dashboard
        </Link>
      </div>
    );
  }

  return <>{children}</>;
}
