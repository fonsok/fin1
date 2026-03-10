import { Badge, Button } from '../../../components/ui';
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
  return (
    <div className="flex items-center justify-between p-4 bg-green-50 border border-green-200 rounded-lg">
      <div className="flex items-center gap-4">
        <div className="w-12 h-12 bg-green-100 rounded-full flex items-center justify-center">
          <span className="text-green-700 font-semibold text-lg">
            {customer.firstName?.[0] || customer.email[0].toUpperCase()}
          </span>
        </div>
        <div>
          <p className="font-medium text-gray-900">
            {customer.fullName || customer.firstName || customer.email}
          </p>
          <p className="text-sm text-gray-500">{customer.email}</p>
          <div className="flex items-center gap-2 mt-1">
            <Badge variant={getKYCBadgeVariant(customer.kycStatus)} size="sm">
              KYC: {getKYCLabel(customer.kycStatus)}
            </Badge>
            <span className="text-xs text-gray-400">ID: {customer.customerId || customer.objectId}</span>
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
  return (
    <div className="relative">
      <input
        type="text"
        value={value}
        onChange={(e) => onChange(e.target.value)}
        onFocus={onFocus}
        placeholder="Kundenname, E-Mail oder ID eingeben..."
        className="w-full px-4 py-3 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-fin1-primary focus:border-transparent"
      />

      {/* Search Results Dropdown */}
      {showDropdown && value.length >= 2 && (
        <div className="absolute z-10 w-full mt-1 bg-white border border-gray-200 rounded-lg shadow-lg max-h-64 overflow-auto">
          {isSearching ? (
            <div className="p-4 text-center text-gray-500">
              <div className="animate-spin w-5 h-5 border-2 border-fin1-primary border-t-transparent rounded-full mx-auto mb-2"></div>
              Suche...
            </div>
          ) : searchResults && searchResults.length > 0 ? (
            searchResults.map((customer) => (
              <button
                key={customer.objectId}
                onClick={() => onSelect(customer)}
                className="w-full px-4 py-3 text-left hover:bg-gray-50 border-b border-gray-100 last:border-b-0"
              >
                <div className="flex items-center justify-between">
                  <div>
                    <p className="font-medium text-gray-900">
                      {customer.fullName || customer.firstName || customer.email}
                    </p>
                    <p className="text-sm text-gray-500">{customer.email}</p>
                  </div>
                  <Badge variant={getKYCBadgeVariant(customer.kycStatus)} size="sm">
                    {getKYCLabel(customer.kycStatus)}
                  </Badge>
                </div>
              </button>
            ))
          ) : (
            <div className="p-4 text-center text-gray-500">Keine Kunden gefunden</div>
          )}
        </div>
      )}

      <p className="text-sm text-gray-500 mt-2">Mindestens 2 Zeichen eingeben, um zu suchen</p>
    </div>
  );
}
