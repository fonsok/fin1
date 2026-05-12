import clsx from 'clsx';
import { Badge, Button } from '../../../components/ui';
import { useTheme } from '../../../context/ThemeContext';
import type { CustomerSearchResult } from '../types';

// ============================================================================
// Customer Selection Components
// ============================================================================
// Components for selecting and displaying customers in ticket creation.

interface SelectedCustomerCardProps {
  customer: CustomerSearchResult;
  onClear: () => void;
  getKYCBadgeVariant: (status?: string) => 'success' | 'warning' | 'danger' | 'neutral';
  getKYCLabel: (status?: string) => string;
}

export function SelectedCustomerCard({
  customer,
  onClear,
  getKYCBadgeVariant,
  getKYCLabel,
}: SelectedCustomerCardProps): JSX.Element {
  const { theme } = useTheme();
  const isDark = theme === 'dark';

  return (
    <div
      className={clsx(
        'flex items-center justify-between p-4 rounded-lg border',
        isDark
          ? 'bg-emerald-950/35 border-emerald-600/40'
          : 'bg-green-50 border-green-200',
      )}
    >
      <div className="flex items-center gap-4">
        <div
          className={clsx(
            'w-12 h-12 rounded-full flex items-center justify-center',
            isDark ? 'bg-emerald-900/50' : 'bg-green-100',
          )}
        >
          <span
            className={clsx(
              'font-semibold text-lg',
              isDark ? 'text-emerald-200' : 'text-green-700',
            )}
          >
            {customer.firstName?.[0] || customer.email[0].toUpperCase()}
          </span>
        </div>
        <div>
          <p className={clsx('font-medium', isDark ? 'text-slate-100' : 'text-gray-900')}>
            {customer.fullName || customer.firstName || customer.email}
          </p>
          <p className={clsx('text-sm', isDark ? 'text-slate-400' : 'text-gray-500')}>{customer.email}</p>
          <div className="flex items-center gap-2 mt-1">
            <Badge variant={getKYCBadgeVariant(customer.kycStatus)} size="sm">
              KYC: {getKYCLabel(customer.kycStatus)}
            </Badge>
            <span className={clsx('text-xs', isDark ? 'text-slate-500' : 'text-gray-400')}>
              Nr.: {customer.customerNumber || '—'} · User: {customer.objectId}
            </span>
          </div>
        </div>
      </div>
      <Button variant="secondary" size="sm" onClick={onClear}>
        Ändern
      </Button>
    </div>
  );
}

interface CustomerSearchInputProps {
  value: string;
  onChange: (value: string) => void;
  onFocus: () => void;
  showDropdown: boolean;
  isSearching: boolean;
  searchResults?: CustomerSearchResult[];
  onSelect: (customer: CustomerSearchResult) => void;
  getKYCBadgeVariant: (status?: string) => 'success' | 'warning' | 'danger' | 'neutral';
  getKYCLabel: (status?: string) => string;
}

export function CustomerSearchInput({
  value,
  onChange,
  onFocus,
  showDropdown,
  isSearching,
  searchResults,
  onSelect,
  getKYCBadgeVariant,
  getKYCLabel,
}: CustomerSearchInputProps): JSX.Element {
  const { theme } = useTheme();
  const isDark = theme === 'dark';

  return (
    <div className="relative">
      <input
        type="text"
        value={value}
        onChange={(e) => onChange(e.target.value)}
        onFocus={onFocus}
        placeholder="Kundenname, E-Mail oder ID eingeben..."
        className={clsx(
          'w-full px-4 py-3 rounded-lg focus:outline-none focus:ring-2 focus:ring-fin1-primary focus:border-transparent',
          isDark
            ? 'bg-slate-800/80 border border-slate-500 text-slate-100 placeholder:text-slate-500'
            : 'border border-gray-300',
        )}
      />

      {/* Search Results Dropdown */}
      {showDropdown && value.length >= 2 && (
        <div
          className={clsx(
            'absolute z-10 w-full mt-1 rounded-lg shadow-lg max-h-64 overflow-auto border',
            isDark
              ? 'bg-slate-900 border-slate-600 shadow-black/50'
              : 'bg-white border-gray-200',
          )}
        >
          {isSearching ? (
            <div className={clsx('p-4 text-center', isDark ? 'text-slate-400' : 'text-gray-500')}>
              <div className="animate-spin w-5 h-5 border-2 border-fin1-primary border-t-transparent rounded-full mx-auto mb-2"></div>
              Suche...
            </div>
          ) : searchResults && searchResults.length > 0 ? (
            searchResults.map((customer) => (
              <button
                key={customer.objectId}
                type="button"
                onClick={() => onSelect(customer)}
                className={clsx(
                  'w-full px-4 py-3 text-left border-b last:border-b-0 transition-colors',
                  isDark
                    ? 'border-slate-700 hover:bg-slate-800/90'
                    : 'border-gray-100 hover:bg-gray-50',
                )}
              >
                <div className="flex items-center justify-between gap-3">
                  <div className="min-w-0">
                    <p className={clsx('font-medium truncate', isDark ? 'text-slate-100' : 'text-gray-900')}>
                      {customer.fullName || customer.firstName || customer.email}
                    </p>
                    <p className={clsx('text-sm truncate', isDark ? 'text-slate-400' : 'text-gray-500')}>
                      {customer.email}
                    </p>
                  </div>
                  <Badge variant={getKYCBadgeVariant(customer.kycStatus)} size="sm" className="flex-shrink-0">
                    {getKYCLabel(customer.kycStatus)}
                  </Badge>
                </div>
              </button>
            ))
          ) : (
            <div className={clsx('p-4 text-center', isDark ? 'text-slate-400' : 'text-gray-500')}>
              Keine Kunden gefunden
            </div>
          )}
        </div>
      )}

      <p className={clsx('text-sm mt-2', isDark ? 'text-slate-400' : 'text-gray-500')}>
        Mindestens 2 Zeichen eingeben, um zu suchen
      </p>
    </div>
  );
}
