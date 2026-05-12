import { Card } from '../../../components/ui/Card';

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
  return (
    <Card className="p-4">
      <div className="flex gap-4 flex-wrap items-center">
        <select
          value={documentTypeFilter}
          onChange={(e) => onDocumentTypeChange(e.target.value as DocumentTypeFilter)}
          className="terms-select px-4 py-2 bg-slate-200 text-gray-900 border border-slate-400 rounded-lg focus:ring-2 focus:ring-fin1-primary focus:border-transparent"
        >
          <option value="all">Alle Typen</option>
          <option value="terms">AGB / Terms</option>
          <option value="privacy">Datenschutz</option>
          <option value="imprint">Impressum</option>
        </select>
        <select
          value={languageFilter}
          onChange={(e) => onLanguageChange(e.target.value as LanguageFilter)}
          className="terms-select px-4 py-2 bg-slate-200 text-gray-900 border border-slate-400 rounded-lg focus:ring-2 focus:ring-fin1-primary focus:border-transparent"
        >
          <option value="all">Alle Sprachen</option>
          <option value="de">Deutsch</option>
          <option value="en">English</option>
        </select>
        <select
          value={listViewFilter}
          onChange={(e) => onListViewChange(e.target.value as ListViewFilter)}
          className="terms-select px-4 py-2 bg-slate-200 text-gray-900 border border-slate-400 rounded-lg focus:ring-2 focus:ring-fin1-primary focus:border-transparent"
        >
          <option value="all">Alle Versionen</option>
          <option value="active_only">Nur aktive</option>
          <option value="last_10">Letzte 10 (nach Datum)</option>
          <option value="last_20">Letzte 20 (nach Datum)</option>
        </select>
        <label className="flex items-center gap-2 text-sm text-gray-700">
          <input
            type="checkbox"
            checked={showArchived}
            onChange={(e) => onShowArchivedChange(e.target.checked)}
          />
          Archivierte anzeigen
        </label>
      </div>
    </Card>
  );
}
