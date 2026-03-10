import { useState, useEffect } from 'react';
import { Card } from '../../components/ui/Card';
import { Button } from '../../components/ui/Button';
import { TermsList } from './components/TermsList';
import { TermsEditor } from './components/TermsEditor';
import { listTermsContent, getTermsContent, setActiveTermsContent } from './api';
import type { TermsContentListItem, TermsContentFull, TermsSection } from './types';
import { DOCUMENT_TYPE_LABELS } from './types';

type DocumentTypeFilter = 'all' | 'terms' | 'privacy' | 'imprint';
type LanguageFilter = 'all' | 'de' | 'en';
type ListViewFilter = 'all' | 'active_only' | 'last_10' | 'last_20';

export function TermsPage() {
  const [items, setItems] = useState<TermsContentListItem[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [documentTypeFilter, setDocumentTypeFilter] = useState<DocumentTypeFilter>('terms');
  const [languageFilter, setLanguageFilter] = useState<LanguageFilter>('all');
  const [listViewFilter, setListViewFilter] = useState<ListViewFilter>('all');
  const [showEditor, setShowEditor] = useState(false);
  const [cloneFromId, setCloneFromId] = useState<string | null>(null);
  const [cloneFromFull, setCloneFromFull] = useState<TermsContentFull | null>(null);
  const [settingActiveId, setSettingActiveId] = useState<string | null>(null);
  const [initialSectionSearch, setInitialSectionSearch] = useState<string>('');

  useEffect(() => {
    loadList();
  }, [documentTypeFilter, languageFilter]);

  async function loadList() {
    setLoading(true);
    setError(null);
    try {
      const params: { documentType?: string; language?: string } = {};
      if (documentTypeFilter !== 'all') params.documentType = documentTypeFilter;
      if (languageFilter !== 'all') params.language = languageFilter;
      const list = await listTermsContent(params);
      setItems(list);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Fehler beim Laden der Rechtstexte');
      setItems([]);
    } finally {
      setLoading(false);
    }
  }

  useEffect(() => {
    if (!cloneFromId) {
      setCloneFromFull(null);
      return;
    }
    let cancelled = false;
    getTermsContent(cloneFromId).then((full) => {
      if (!cancelled) setCloneFromFull(full);
    }).catch(() => {
      if (!cancelled) setCloneFromFull(null);
    });
    return () => { cancelled = true; };
  }, [cloneFromId]);

  function handleClone(item: TermsContentListItem) {
    setInitialSectionSearch('');
    setCloneFromId(item.objectId);
    setShowEditor(true);
  }

  function handleEditSection(item: TermsContentListItem, section: TermsSection) {
    const search = section.id || section.title || '';
    setInitialSectionSearch(search);
    setCloneFromId(item.objectId);
    setShowEditor(true);
  }

  function handleCloseEditor() {
    setShowEditor(false);
    setCloneFromId(null);
    setCloneFromFull(null);
    setInitialSectionSearch('');
  }

  async function handleSetActive(objectId: string) {
    setSettingActiveId(objectId);
    try {
      await setActiveTermsContent(objectId);
      await loadList();
    } catch (err) {
      console.error('Set active failed:', err);
      alert(err instanceof Error ? err.message : 'Aktivieren fehlgeschlagen');
    } finally {
      setSettingActiveId(null);
    }
  }

  const showEditorNew = showEditor && !cloneFromId;
  const cloningLoading = showEditor && cloneFromId && !cloneFromFull;
  const showEditorWithClone = showEditor && cloneFromId && !!cloneFromFull;

  const sortedItems = [...items].sort((a, b) => {
    // 1) Aktive Versionen zuerst
    if (a.isActive !== b.isActive) {
      return a.isActive ? -1 : 1;
    }
    // 2) Nach Gültig-ab-Datum (effectiveDate) absteigend
    const aDate = a.effectiveDate ? Date.parse(a.effectiveDate) : 0;
    const bDate = b.effectiveDate ? Date.parse(b.effectiveDate) : 0;
    if (aDate !== bDate) {
      return bDate - aDate;
    }
    // 3) Nach UpdatedAt absteigend (neuere Änderungen oben)
    const aUpdated = a.updatedAt ? Date.parse(a.updatedAt) : 0;
    const bUpdated = b.updatedAt ? Date.parse(b.updatedAt) : 0;
    if (aUpdated !== bUpdated) {
      return bUpdated - aUpdated;
    }
    // 4) Fallback: alphabetisch nach Version
    return a.version.localeCompare(b.version);
  });

  const displayedItems =
    listViewFilter === 'active_only'
      ? sortedItems.filter((i) => i.isActive)
      : listViewFilter === 'last_10'
        ? sortedItems.slice(0, 10)
        : listViewFilter === 'last_20'
          ? sortedItems.slice(0, 20)
          : sortedItems;

  if (loading && items.length === 0) {
    return (
      <div className="flex items-center justify-center h-64">
        <div className="animate-spin w-8 h-8 border-4 border-fin1-primary border-t-transparent rounded-full" />
      </div>
    );
  }

  return (
    <div className="space-y-6">
      <div className="flex justify-between items-center">
        <div>
          <h1 className="text-2xl font-bold text-gray-900">AGB & Rechtstexte</h1>
          <p className="text-gray-500">Terms of Service, Datenschutz und Impressum versioniert verwalten</p>
        </div>
        <Button onClick={() => { setCloneFromId(null); setShowEditor(true); }}>
          + Neue Version (leer)
        </Button>
      </div>

      {error && (
        <div className="bg-red-50 text-red-600 p-4 rounded-lg">
          {error}
          <button type="button" className="ml-4 underline" onClick={loadList}>Erneut versuchen</button>
        </div>
      )}

      <div className="grid grid-cols-3 gap-4">
        <Card className="p-4">
          <div className="text-sm text-gray-500">Versionen (gefiltert)</div>
          <div className="text-2xl font-bold text-gray-900">{items.length}</div>
        </Card>
        <Card className="p-4">
          <div className="text-sm text-gray-500">Aktive</div>
          <div className="text-2xl font-bold text-gray-900">{items.filter((i) => i.isActive).length}</div>
        </Card>
        <Card className="p-4">
          <div className="text-sm text-gray-500">Dokumenttyp</div>
          <div className="text-2xl font-bold text-gray-900">
            {documentTypeFilter === 'all' ? 'Alle' : (DOCUMENT_TYPE_LABELS[documentTypeFilter] ?? documentTypeFilter)}
          </div>
        </Card>
      </div>

      <Card className="p-4">
        <div className="flex gap-4 flex-wrap items-center">
          <select
            value={documentTypeFilter}
            onChange={(e) => setDocumentTypeFilter(e.target.value as DocumentTypeFilter)}
            className="px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-fin1-primary focus:border-transparent"
          >
            <option value="all">Alle Typen</option>
            <option value="terms">AGB / Terms</option>
            <option value="privacy">Datenschutz</option>
            <option value="imprint">Impressum</option>
          </select>
          <select
            value={languageFilter}
            onChange={(e) => setLanguageFilter(e.target.value as LanguageFilter)}
            className="px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-fin1-primary focus:border-transparent"
          >
            <option value="all">Alle Sprachen</option>
            <option value="de">Deutsch</option>
            <option value="en">English</option>
          </select>
          <select
            value={listViewFilter}
            onChange={(e) => setListViewFilter(e.target.value as ListViewFilter)}
            className="px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-fin1-primary focus:border-transparent"
          >
            <option value="all">Alle Versionen</option>
            <option value="active_only">Nur aktive</option>
            <option value="last_10">Letzte 10 (nach Datum)</option>
            <option value="last_20">Letzte 20 (nach Datum)</option>
          </select>
        </div>
      </Card>

      <TermsList
        items={displayedItems}
        documentTypeFilter={documentTypeFilter}
        onClone={handleClone}
        onSetActive={handleSetActive}
        settingActiveId={settingActiveId}
        onEditSection={handleEditSection}
      />

      {cloningLoading && (
        <div className="fixed inset-0 bg-black/50 flex items-center justify-center z-50">
          <div className="bg-white rounded-xl shadow-xl px-8 py-6">
            <div className="animate-spin w-8 h-8 border-4 border-fin1-primary border-t-transparent rounded-full mx-auto mb-4" />
            <p className="text-gray-600">Lade Version zum Klonen…</p>
          </div>
        </div>
      )}
      {(showEditorNew || showEditorWithClone) && (
        <TermsEditor
          cloneFrom={showEditorWithClone ? cloneFromFull : null}
          initialSectionSearch={initialSectionSearch}
          onSaved={loadList}
          onClose={handleCloseEditor}
        />
      )}
    </div>
  );
}
