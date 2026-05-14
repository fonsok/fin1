import clsx from 'clsx';
import { Card } from '../../../components/ui/Card';
import { useTheme } from '../../../context/ThemeContext';

type DocumentTypeFilter = 'all' | 'terms' | 'privacy' | 'imprint';
type LanguageFilter = 'all' | 'de' | 'en';
type ListViewFilter = 'all' | 'active_only' | 'last_10' | 'last_20';

interface TermsFiltersCardProps {
  documentTypeFilter: DocumentTypeFilter;
  languageFilter: LanguageFilter;
  listViewFilter: ListViewFilter;
  showArchived: boolean;
  onDocumentTypeChange: (value: DocumentTypeFilter) => void;
  onLanguageChange: (value: LanguageFilter) => void;
  onListViewChange: (value: ListViewFilter) => void;
  onShowArchivedChange: (value: boolean) => void;
}

export function TermsFiltersCard({
  documentTypeFilter,
  languageFilter,
  listViewFilter,
  showArchived,
  onDocumentTypeChange,
  onLanguageChange,
  onListViewChange,
  onShowArchivedChange,
}: TermsFiltersCardProps) {
  const { theme } = useTheme();
  const isDark = theme === 'dark';
  const selectClass = clsx(
    'terms-select px-4 py-2 border rounded-lg focus:ring-2 focus:ring-fin1-primary focus:border-transparent',
    isDark ? 'bg-slate-900/70 border-slate-600 text-slate-100' : 'bg-white border-gray-300 text-gray-900',
  );

  return (
    <Card className="p-4">
      <div className="flex gap-4 flex-wrap items-center">
        <select
          value={documentTypeFilter}
          onChange={(e) => onDocumentTypeChange(e.target.value as DocumentTypeFilter)}
          className={selectClass}
        >
          <option value="all">Alle Typen</option>
          <option value="terms">AGB / Terms</option>
          <option value="privacy">Datenschutz</option>
          <option value="imprint">Impressum</option>
        </select>
        <select
          value={languageFilter}
          onChange={(e) => onLanguageChange(e.target.value as LanguageFilter)}
          className={selectClass}
        >
          <option value="all">Alle Sprachen</option>
          <option value="de">Deutsch</option>
          <option value="en">English</option>
        </select>
        <select
          value={listViewFilter}
          onChange={(e) => onListViewChange(e.target.value as ListViewFilter)}
          className={selectClass}
        >
          <option value="all">Alle Versionen</option>
          <option value="active_only">Nur aktive</option>
          <option value="last_10">Letzte 10 (nach Datum)</option>
          <option value="last_20">Letzte 20 (nach Datum)</option>
        </select>
        <label
          className={clsx(
            'flex items-center gap-2 text-sm',
            isDark ? 'text-slate-200' : 'text-gray-700',
          )}
        >
          <input
            type="checkbox"
            checked={showArchived}
            onChange={(e) => onShowArchivedChange(e.target.checked)}
            className={clsx(
              'rounded border',
              isDark ? 'border-slate-500 bg-slate-900 text-fin1-primary' : 'border-gray-300 bg-white',
            )}
          />
          Archivierte anzeigen
        </label>
      </div>
    </Card>
  );
}
