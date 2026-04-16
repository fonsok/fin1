import { useState, useEffect, useCallback, useMemo } from 'react';
import { useQuery } from '@tanstack/react-query';
import clsx from 'clsx';
import { Card } from '../../components/ui/Card';
import { Link } from 'react-router-dom';
import { useTheme } from '../../context/ThemeContext';
import { TermsList } from './components/TermsList';
import { TermsEditor } from './components/TermsEditor';
import { DevMaintenanceCard } from './components/DevMaintenanceCard';
import { TermsHeaderActions } from './components/TermsHeaderActions';
import { TermsFiltersCard } from './components/TermsFiltersCard';
import { useTermsDerivedList } from './hooks/useTermsDerivedList';
import { downloadJsonFile, formatTimestampForFilename, pickJsonFile } from './utils/backupFiles';
import {
  listTermsContent,
  getTermsContent,
  setActiveTermsContent,
  exportLegalDocumentsBackup,
  exportActiveLegalDocumentsBackup,
  devResetLegalDocumentsBaseline,
  importLegalDocumentsBackup,
  importActiveLegalDocumentsBackup,
} from './api';
import type { TermsContentListItem, TermsContentFull, TermsSection } from './types';
import { DOCUMENT_TYPE_LABELS } from './types';
import { getConfiguration } from '../../api/admin/configuration';

type DocumentTypeFilter = 'all' | 'terms' | 'privacy' | 'imprint';
type LanguageFilter = 'all' | 'de' | 'en';
type ListViewFilter = 'all' | 'active_only' | 'last_10' | 'last_20';

export function TermsPage() {
  const { theme } = useTheme();
  const isDark = theme === 'dark';
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
  const [showArchived, setShowArchived] = useState(false);
  const [importing, setImporting] = useState(false);
  const [importingActive, setImportingActive] = useState(false);
  const [devResetting, setDevResetting] = useState(false);

  const { data: configuration } = useQuery({
    queryKey: ['configuration'],
    queryFn: getConfiguration,
    staleTime: 30_000,
  });

  const legalPreview = useMemo(() => {
    const cfg = configuration?.config;
    if (!cfg) return null;

    const appNameRaw = cfg.legalAppName ?? cfg.appName;
    const platformNameRaw = cfg.legalPlatformName;

    const appName = typeof appNameRaw === 'string' ? appNameRaw.trim() : String(appNameRaw ?? '').trim();
    const platformName =
      typeof platformNameRaw === 'string' ? platformNameRaw.trim() : String(platformNameRaw ?? '').trim();

    if (!appName && !platformName) return null;
    return {
      appName,
      ...(platformName ? { platformName } : {}),
    };
  }, [configuration]);

  const loadList = useCallback(async () => {
    setLoading(true);
    setError(null);
    try {
      const params: { documentType?: string; language?: string; includeArchived?: boolean } = {};
      if (documentTypeFilter !== 'all') params.documentType = documentTypeFilter;
      if (languageFilter !== 'all') params.language = languageFilter;
      if (showArchived) params.includeArchived = true;
      const list = await listTermsContent(params);
      setItems(list);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Fehler beim Laden der Rechtstexte');
      setItems([]);
    } finally {
      setLoading(false);
    }
  }, [documentTypeFilter, languageFilter, showArchived]);

  useEffect(() => {
    void loadList();
  }, [loadList]);

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

  async function handleExportBackup() {
    try {
      const payload = await exportLegalDocumentsBackup();
      const timestamp = formatTimestampForFilename();
      downloadJsonFile(`legal-documents-backup-${timestamp}.json`, payload);
      if (payload.warnings?.length) {
        alert(`Export abgeschlossen.\n\nHinweis:\n- ${payload.warnings.join('\n- ')}`);
      }
    } catch (err) {
      alert('Export fehlgeschlagen: ' + (err instanceof Error ? err.message : 'Unbekannter Fehler'));
    }
  }

  async function handleExportActiveBackup() {
    try {
      const docType = documentTypeFilter === 'all' ? undefined : documentTypeFilter;
      const lang = languageFilter === 'all' ? undefined : languageFilter;
      const payload = await exportActiveLegalDocumentsBackup({
        documentType: docType,
        language: lang,
      });
      const timestamp = formatTimestampForFilename();
      downloadJsonFile(`legal-documents-active-${docType ?? 'all'}-${lang ?? 'all'}-${timestamp}.json`, payload);
      if (payload.warnings?.length) {
        alert(`Export active abgeschlossen.\n\nHinweis:\n- ${payload.warnings.join('\n- ')}`);
      }
    } catch (err) {
      alert('Export active fehlgeschlagen: ' + (err instanceof Error ? err.message : 'Unbekannter Fehler'));
    }
  }

  async function handleImportBackupFile(file: File) {
    setImporting(true);
    try {
      const text = await file.text();
      const backup = JSON.parse(text) as unknown;

      const dryRun = await importLegalDocumentsBackup({ backup, archiveExisting: true, dryRun: true });
      const confirmText =
        `Restore-Preview (Dry-Run)\n\n` +
        `- würde archivieren/deaktivieren: ${dryRun.archivedCount}\n` +
        `- würde importieren: ${dryRun.importedCount}\n` +
        `- aktive Konflikte (würden automatisch gefixt): ${dryRun.fixedActiveConflicts}\n` +
        (dryRun.warnings?.length ? `\nHinweise / Warnungen:\n- ${dryRun.warnings.join('\n- ')}` : '') +
        `\n\nJetzt wirklich durchführen? (Dies archiviert bestehende Versionen und importiert die Backup-Versionen.)`;

      const ok = window.confirm(confirmText);
      if (!ok) return;

      const result = await importLegalDocumentsBackup({ backup, archiveExisting: true, dryRun: false });
      alert(
        `Restore abgeschlossen.\n\n` +
          `Archiviert/deaktiviert: ${result.archivedCount}\n` +
          `Importiert: ${result.importedCount}\n` +
          `Aktiv-Konflikte gefixt: ${result.fixedActiveConflicts}` +
          (result.warnings?.length ? `\n\nHinweise:\n- ${result.warnings.join('\n- ')}` : '')
      );
      await loadList();
    } catch (err) {
      alert('Import fehlgeschlagen: ' + (err instanceof Error ? err.message : 'Unbekannter Fehler'));
    } finally {
      setImporting(false);
    }
  }

  async function handleImportActiveBackupFile(file: File) {
    setImportingActive(true);
    try {
      const text = await file.text();
      const backup = JSON.parse(text) as unknown;

      const dryRun = await importActiveLegalDocumentsBackup({ backup, dryRun: true });
      const confirmText =
        `Active-Import Preview (Dry-Run)\n\n` +
        `- würde neue Versionen erstellen: ${dryRun.createdCount}\n` +
        `- würde aktiv setzen (Gruppen): ${dryRun.activatedCount}\n` +
        (dryRun.warnings?.length ? `\nHinweise / Warnungen:\n- ${dryRun.warnings.join('\n- ')}` : '') +
        `\n\nJetzt wirklich durchführen? (Bestehende Historie bleibt erhalten.)`;

      const ok = window.confirm(confirmText);
      if (!ok) return;

      const result = await importActiveLegalDocumentsBackup({ backup, dryRun: false });
      alert(
        `Active-Import abgeschlossen.\n\n` +
          `Neue Versionen: ${result.createdCount}\n` +
          `Aktiv gesetzt: ${result.activatedCount}` +
          (result.warnings?.length ? `\n\nHinweise:\n- ${result.warnings.join('\n- ')}` : '')
      );
      await loadList();
    } catch (err) {
      alert('Active-Import fehlgeschlagen: ' + (err instanceof Error ? err.message : 'Unbekannter Fehler'));
    } finally {
      setImportingActive(false);
    }
  }

  async function promptImportBackup() {
    const file = await pickJsonFile();
    if (file) void handleImportBackupFile(file);
  }

  async function promptImportActiveBackup() {
    const file = await pickJsonFile();
    if (file) void handleImportActiveBackupFile(file);
  }

  const showEditorNew = showEditor && !cloneFromId;
  const cloningLoading = showEditor && cloneFromId && !cloneFromFull;
  const showEditorWithClone = showEditor && cloneFromId && !!cloneFromFull;
  const { displayedItems, activeCount } = useTermsDerivedList(items, listViewFilter);

  async function handleDevReset() {
    setDevResetting(true);
    try {
      const preview = await devResetLegalDocumentsBaseline({ targetVersion: '1.0.0', dryRun: true });
      const ok = window.confirm(
        `DEV Reset Preview (Dry-Run)\n\n` +
          `Aktive gefunden: ${preview.activeFound}\n` +
          `Neue Baseline-Versionen: ${preview.clonesPlanned}\n\n` +
          `Fortfahren? Dies klont aktive Versionen (v${preview.targetVersion}) und löscht danach alle inaktiven Versionen.`
      );
      if (!ok) return;
      const result = await devResetLegalDocumentsBaseline({ targetVersion: '1.0.0', dryRun: false });
      alert(
        `DEV Reset abgeschlossen.\n\n` +
          `Neue Baseline-Versionen: ${result.clonesPlanned}\n` +
          `Aktiv gesetzt: ${result.activatedCount}\n` +
          `Gelöscht (inaktiv): ${result.deletedCount}`
      );
      await loadList();
    } catch (err) {
      const token = localStorage.getItem('parse_session');
      const tokenHint = token ? `${token.slice(0, 8)}…` : '(none)';
      alert(
        'DEV Reset fehlgeschlagen: ' +
          (err instanceof Error ? err.message : 'Unbekannter Fehler') +
          `\n\nDebug: parse_session=${tokenHint}`
      );
    } finally {
      setDevResetting(false);
    }
  }

  if (loading && items.length === 0) {
    return (
      <div className="flex items-center justify-center h-64">
        <div className="animate-spin w-8 h-8 border-4 border-fin1-primary border-t-transparent rounded-full" />
      </div>
    );
  }

  return (
    <div className="space-y-6">
      <Card className="p-4 border-blue-200 bg-blue-50">
        <div className="space-y-1">
          <h2 className="text-lg font-semibold text-blue-900">Legal Branding</h2>
          <p className="text-sm text-blue-800">
            Der kanonische <strong>App Name</strong> wird zentral unter <strong>Konfiguration</strong> gepflegt
            (4-Augen-Workflow) und in Rechtstexten als Platzhalter verwendet.
          </p>
          <Link to="/configuration" className="inline-flex text-sm font-medium text-blue-700 hover:text-blue-900">
            Zu Konfiguration wechseln
          </Link>
        </div>
      </Card>

      <DevMaintenanceCard
        devResetting={devResetting}
        onRunReset={handleDevReset}
      />

      <div className="flex justify-between items-center">
        <div>
          <h1 className="text-2xl font-bold text-gray-900">AGB & Rechtstexte</h1>
          <p className="text-gray-500">Terms of Service, Datenschutz und Impressum versioniert verwalten</p>
        </div>
        <TermsHeaderActions
          importing={importing}
          importingActive={importingActive}
          onExportBackup={handleExportBackup}
          onExportActiveBackup={handleExportActiveBackup}
          onPromptImportBackup={promptImportBackup}
          onPromptImportActiveBackup={promptImportActiveBackup}
          onCreateEmptyVersion={() => {
            setCloneFromId(null);
            setShowEditor(true);
          }}
        />
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
          <div className="text-2xl font-bold text-gray-900">{activeCount}</div>
        </Card>
        <Card className="p-4">
          <div className="text-sm text-gray-500">Dokumenttyp</div>
          <div className="text-2xl font-bold text-gray-900">
            {documentTypeFilter === 'all' ? 'Alle' : (DOCUMENT_TYPE_LABELS[documentTypeFilter] ?? documentTypeFilter)}
          </div>
        </Card>
      </div>

      <TermsFiltersCard
        documentTypeFilter={documentTypeFilter}
        languageFilter={languageFilter}
        listViewFilter={listViewFilter}
        showArchived={showArchived}
        onDocumentTypeChange={setDocumentTypeFilter}
        onLanguageChange={setLanguageFilter}
        onListViewChange={setListViewFilter}
        onShowArchivedChange={setShowArchived}
      />

      <TermsList
        items={displayedItems}
        documentTypeFilter={documentTypeFilter}
        onClone={handleClone}
        onSetActive={handleSetActive}
        settingActiveId={settingActiveId}
        onEditSection={handleEditSection}
        legalPreview={legalPreview}
      />

      {cloningLoading && (
        <div className="fixed inset-0 bg-black/50 flex items-center justify-center z-50">
          <div className={clsx('rounded-xl shadow-xl px-8 py-6 border', isDark ? 'bg-slate-800 border-slate-600' : 'bg-white border-gray-200')}>
            <div className="animate-spin w-8 h-8 border-4 border-fin1-primary border-t-transparent rounded-full mx-auto mb-4" />
            <p className={isDark ? 'text-slate-300' : 'text-gray-600'}>Lade Version zum Klonen…</p>
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
