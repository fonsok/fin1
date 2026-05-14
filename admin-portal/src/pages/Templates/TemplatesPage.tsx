import { useState, useMemo, useEffect } from 'react';
import clsx from 'clsx';
import { Card, PaginationBar } from '../../components/ui';
import { useTheme } from '../../context/ThemeContext';
import { formatNumber } from '../../utils/format';
import { TemplateEditor } from './components/TemplateEditor';
import { TemplateList } from './components/TemplateList';
import { EmailTemplateList } from './components/EmailTemplateList';
import { EmailTemplateCreateEditor } from './components/EmailTemplateCreateEditor';
import { TemplatesHeaderActions } from './components/TemplatesHeaderActions';
import { TemplatesTabs } from './components/TemplatesTabs';
import { UsageStats } from './components/UsageStats';
import { useTemplatesData } from './hooks/useTemplatesData';
import {
  downloadJson,
  buildFilteredTemplatesExportPayload,
  getFilteredExportFilename,
  importFilteredTemplatesAsNew,
} from './utils/templatesImportExport';
import {
  createResponseTemplate,
  updateResponseTemplate,
  deleteResponseTemplate,
  seedCSRTemplates,
  exportCSRTemplatesBackup,
  backfillCSRTemplateShortcuts,
} from './api';
import { sortByTitleDe } from './utils/templateDisplayOrder';
import type {
  ResponseTemplate,
  CreateTemplateRequest,
  UpdateTemplateRequest,
} from './types';

import { adminControlField, adminControlFieldPh400, adminMuted, adminPrimary } from '../../utils/adminThemeClasses';
type TabType = 'response' | 'email' | 'stats';

export function TemplatesPage() {
  const { theme } = useTheme();
  const isDark = theme === 'dark';

  // State
  const [activeTab, setActiveTab] = useState<TabType>('response');
  const [responsePage, setResponsePage] = useState(0);
  const [responsePageSize, setResponsePageSize] = useState(25);
  const [emailPage, setEmailPage] = useState(0);
  const [emailPageSize, setEmailPageSize] = useState(25);

  // Editor state
  const [showEditor, setShowEditor] = useState(false);
  const [editingTemplate, setEditingTemplate] = useState<ResponseTemplate | null>(null);
  const [showEmailCreateEditor, setShowEmailCreateEditor] = useState(false);

  // Filter state
  const [categoryFilter, setCategoryFilter] = useState<string>('');
  const [searchQuery, setSearchQuery] = useState('');
  const {
    templates,
    setTemplates,
    emailTemplates,
    categories,
    loading,
    error,
    loadData,
    filteredTemplates,
    uniqueCategories,
  } = useTemplatesData(categoryFilter, searchQuery);

  const responseTotal = filteredTemplates.length;
  const responseTotalPages = Math.max(1, Math.ceil(responseTotal / responsePageSize));
  const pagedResponseTemplates = useMemo(
    () =>
      filteredTemplates.slice(
        responsePage * responsePageSize,
        (responsePage + 1) * responsePageSize
      ),
    [filteredTemplates, responsePage, responsePageSize]
  );

  const emailTotal = emailTemplates.length;
  const emailTotalPages = Math.max(1, Math.ceil(emailTotal / emailPageSize));
  const pagedEmailTemplates = useMemo(
    () =>
      emailTemplates.slice(emailPage * emailPageSize, (emailPage + 1) * emailPageSize),
    [emailTemplates, emailPage, emailPageSize]
  );

  useEffect(() => {
    setResponsePage(0);
  }, [categoryFilter, searchQuery, responsePageSize]);

  useEffect(() => {
    if (responsePage > 0 && responsePage >= responseTotalPages) {
      setResponsePage(Math.max(0, responseTotalPages - 1));
    }
  }, [responsePage, responseTotalPages]);

  useEffect(() => {
    setEmailPage(0);
  }, [emailTemplates.length, emailPageSize]);

  useEffect(() => {
    if (emailPage > 0 && emailPage >= emailTotalPages) {
      setEmailPage(Math.max(0, emailTotalPages - 1));
    }
  }, [emailPage, emailTotalPages]);

  // Handlers
  async function handleCreate(data: CreateTemplateRequest) {
    const newTemplate = await createResponseTemplate(data);
    setTemplates((prev) => sortByTitleDe([...prev, newTemplate]));
    setShowEditor(false);
    setEditingTemplate(null);
  }

  async function handleUpdate(templateId: string, data: UpdateTemplateRequest) {
    const updated = await updateResponseTemplate(templateId, data);
    setTemplates((prev) => sortByTitleDe(prev.map((t) => (t.id === templateId ? updated : t))));
    setShowEditor(false);
    setEditingTemplate(null);
  }

  async function handleDelete(templateId: string) {
    if (!confirm('Template wirklich löschen?')) return;

    try {
      await deleteResponseTemplate(templateId);
      setTemplates((prev) => prev.filter((t) => t.id !== templateId));
    } catch (err) {
      console.error('Error deleting template:', err);
      alert('Fehler beim Löschen des Templates: ' + (err instanceof Error ? err.message : 'Unbekannter Fehler'));
    }
  }

  function handleEdit(template: ResponseTemplate) {
    setEditingTemplate(template);
    setShowEditor(true);
  }

  // Seed templates
  async function handleSeedTemplates() {
    if (!confirm('Standard-Templates importieren? Dies ist nur einmalig möglich.')) return;

    try {
      const result = await seedCSRTemplates();
      alert(`Seed erfolgreich!\n\nKategorien: ${result.categories?.created || 0}\nTextbausteine: ${result.responseTemplates?.created || 0}\nE-Mail Vorlagen: ${result.emailTemplates?.created || 0}`);
      loadData();
    } catch (err) {
      alert('Fehler beim Seeden: ' + (err instanceof Error ? err.message : 'Unbekannter Fehler'));
    }
  }

  // Export backup (from backend)
  async function handleExportBackup() {
    try {
      const payload = await exportCSRTemplatesBackup();
      downloadJson(`csr-templates-backup-${new Date().toISOString().slice(0, 10)}.json`, payload);
    } catch (err) {
      alert('Export fehlgeschlagen: ' + (err instanceof Error ? err.message : 'Unbekannter Fehler'));
    }
  }

  async function handleExportFiltered() {
    try {
      const payload = buildFilteredTemplatesExportPayload(
        filteredTemplates,
        categoryFilter,
        searchQuery
      );
      downloadJson(getFilteredExportFilename(categoryFilter), payload);
    } catch (err) {
      alert('Export filtered fehlgeschlagen: ' + (err instanceof Error ? err.message : 'Unbekannter Fehler'));
    }
  }

  async function handleImportFilteredAsNew() {
    const input = document.createElement('input');
    input.type = 'file';
    input.accept = '.json,application/json';
    input.onchange = async () => {
      const file = input.files?.[0];
      if (!file) return;
      try {
        const text = await file.text();
        const parsed = JSON.parse(text);
        const list = Array.isArray(parsed?.templates) ? parsed.templates : [];
        if (!list.length) {
          alert('Keine Templates im Import gefunden.');
          return;
        }

        const proceed = confirm(
          `Import filtered (as new): ${list.length} Templates werden als neue Einträge angelegt. Fortfahren?`
        );
        if (!proceed) return;

        const { created, failed } = await importFilteredTemplatesAsNew(parsed);

        alert(`Import abgeschlossen.\nErstellt: ${created}\nFehlgeschlagen: ${failed}`);
        await loadData();
      } catch (err) {
        alert('Import filtered fehlgeschlagen: ' + (err instanceof Error ? err.message : 'Unbekannter Fehler'));
      }
    };
    input.click();
  }

  async function handleBackfillShortcuts() {
    try {
      const preview = await backfillCSRTemplateShortcuts({ dryRun: true });
      const lines = (preview.candidates || []).slice(0, 20).map(
        (c) => `- ${c.templateKey}: "${c.title}" -> /${c.suggestedShortcut}`
      );
      const proceed = confirm(
        [
          'Shortcut Backfill (Dry-Run)',
          '',
          `Aktive Templates gescannt: ${preview.activeTemplatesScanned ?? 0}`,
          `Kandidaten ohne Shortcut: ${preview.candidateCount ?? 0}`,
          '',
          ...lines,
          preview.candidates && preview.candidates.length > 20
            ? `... +${preview.candidates.length - 20} weitere`
            : '',
          '',
          'Jetzt anwenden?',
        ].filter(Boolean).join('\n')
      );
      if (!proceed) return;

      const applied = await backfillCSRTemplateShortcuts({ dryRun: false });
      alert(`Shortcut Backfill abgeschlossen. Aktualisiert: ${applied.updatedCount ?? 0}`);
      await loadData();
    } catch (err) {
      alert('Shortcut Backfill fehlgeschlagen: ' + (err instanceof Error ? err.message : 'Unbekannter Fehler'));
    }
  }

  const filterInputClass = clsx(
    'w-full px-4 py-2 border rounded-lg focus:ring-2 focus:ring-fin1-primary focus:border-transparent',
    adminControlFieldPh400(isDark),
  );
  const filterSelectClass = clsx(
    'px-4 py-2 border rounded-lg focus:ring-2 focus:ring-fin1-primary focus:border-transparent',
    adminControlField(isDark),
  );

  // Render
  if (loading) {
    return (
      <div className="flex items-center justify-center h-64">
        <div className="animate-spin w-8 h-8 border-4 border-fin1-primary border-t-transparent rounded-full"></div>
      </div>
    );
  }

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex justify-between items-center">
        <div>
          <h1 className={clsx('text-2xl font-bold', adminPrimary(isDark))}>CSR Templates</h1>
          <p className={clsx(adminMuted(isDark))}>
            Textbausteine und E-Mail-Vorlagen verwalten
          </p>
        </div>
        <TemplatesHeaderActions
          activeTab={activeTab}
          hasAnyTemplate={templates.length > 0 || emailTemplates.length > 0}
          onExportFiltered={handleExportFiltered}
          onImportFilteredAsNew={handleImportFilteredAsNew}
          onBackfillShortcuts={handleBackfillShortcuts}
          onExportBackup={handleExportBackup}
          onSeedTemplates={handleSeedTemplates}
          onCreateResponseTemplate={() => setShowEditor(true)}
          onCreateEmailTemplate={() => setShowEmailCreateEditor(true)}
        />
      </div>

      {/* Error */}
      {error && (
        <div
          className={clsx(
            'p-4 rounded-lg border',
            isDark
              ? 'bg-red-950/40 border-red-800 text-red-200'
              : 'bg-red-50 border-red-100 text-red-600',
          )}
        >
          {error}
          <button type="button" className="ml-4 underline" onClick={loadData}>
            Erneut versuchen
          </button>
        </div>
      )}

      {/* Tabs */}
      <TemplatesTabs
        activeTab={activeTab}
        responseCount={templates.length}
        emailCount={emailTemplates.length}
        onChangeTab={setActiveTab}
      />

      {/* Tab Content */}
      {activeTab === 'response' && (
        <div className="space-y-4">
          {/* Filters */}
          <Card className="p-4">
            <div className="flex gap-4 flex-wrap">
              <div className="flex-1 min-w-[200px]">
                <input
                  type="text"
                  placeholder="Suchen..."
                  value={searchQuery}
                  onChange={(e) => setSearchQuery(e.target.value)}
                  className={filterInputClass}
                />
              </div>
              <select
                value={categoryFilter}
                onChange={(e) => setCategoryFilter(e.target.value)}
                className={filterSelectClass}
              >
                <option value="">Alle Kategorien</option>
                {uniqueCategories.map((cat) => (
                  <option key={cat.key} value={cat.key}>
                    {cat.displayName}
                  </option>
                ))}
              </select>
            </div>
          </Card>

          {/* Template List */}
          {filteredTemplates.length === 0 ? (
            <TemplateList
              templates={filteredTemplates}
              categories={categories}
              onEdit={handleEdit}
              onDelete={handleDelete}
            />
          ) : (
            <div className="space-y-3">
              <div
                className={clsx(
                  'flex flex-wrap items-center gap-3 justify-between rounded-lg border px-3 py-2',
                  isDark ? 'border-slate-600 bg-slate-900/40' : 'border-gray-200 bg-gray-50',
                )}
              >
                <select
                  value={responsePageSize}
                  onChange={(e) => {
                    setResponsePageSize(Number(e.target.value));
                    setResponsePage(0);
                  }}
                  className={clsx(
                    'border rounded-lg px-3 py-2 text-sm',
                    adminControlField(isDark),
                  )}
                >
                  <option value={25}>25 / Seite</option>
                  <option value={50}>50 / Seite</option>
                  <option value={100}>100 / Seite</option>
                </select>
                <p className={clsx('text-sm', adminMuted(isDark))}>
                  {formatNumber(responseTotal)} Treffer nach Filter · bis zu {formatNumber(templates.length)} aus
                  Server ({formatNumber(responsePageSize)} pro Seite, lokal)
                </p>
              </div>
              <TemplateList
                templates={pagedResponseTemplates}
                categories={categories}
                onEdit={handleEdit}
                onDelete={handleDelete}
              />
              <PaginationBar
                page={responsePage}
                pageSize={responsePageSize}
                total={responseTotal}
                itemLabel="Templates"
                isDark={isDark}
                onPageChange={setResponsePage}
              />
            </div>
          )}
        </div>
      )}

      {activeTab === 'email' &&
        (emailTemplates.length === 0 ? (
          <EmailTemplateList templates={emailTemplates} onRefresh={loadData} />
        ) : (
          <div className="space-y-3">
            <div
              className={clsx(
                'flex flex-wrap items-center gap-3 justify-between rounded-lg border px-3 py-2',
                isDark ? 'border-slate-600 bg-slate-900/40' : 'border-gray-200 bg-gray-50',
              )}
            >
              <select
                value={emailPageSize}
                onChange={(e) => {
                  setEmailPageSize(Number(e.target.value));
                  setEmailPage(0);
                }}
                className={clsx(
                  'border rounded-lg px-3 py-2 text-sm',
                  adminControlField(isDark),
                )}
              >
                <option value={25}>25 / Seite</option>
                <option value={50}>50 / Seite</option>
                <option value={100}>100 / Seite</option>
              </select>
              <p className={clsx('text-sm', adminMuted(isDark))}>
                {formatNumber(emailTotal)} Treffer nach Filter · bis zu {formatNumber(emailTemplates.length)} aus Server
                ({formatNumber(emailPageSize)} pro Seite, lokal)
              </p>
            </div>
            <EmailTemplateList templates={pagedEmailTemplates} onRefresh={loadData} />
            <PaginationBar
              page={emailPage}
              pageSize={emailPageSize}
              total={emailTotal}
              itemLabel="E-Mail-Vorlagen"
              isDark={isDark}
              onPageChange={setEmailPage}
            />
          </div>
        ))}

      {activeTab === 'stats' && <UsageStats />}

      {/* Editor Modal */}
      {showEditor && (
        <TemplateEditor
          template={editingTemplate}
          categories={categories}
          onSave={async (data) => {
            if (editingTemplate) {
              await handleUpdate(editingTemplate.id, data as UpdateTemplateRequest);
            } else {
              await handleCreate(data as CreateTemplateRequest);
            }
          }}
          onClose={() => {
            setShowEditor(false);
            setEditingTemplate(null);
          }}
        />
      )}

      {showEmailCreateEditor && (
        <EmailTemplateCreateEditor
          onSave={async () => {
            setShowEmailCreateEditor(false);
            await loadData();
            setActiveTab('email');
            alert('Neue E-Mail Vorlage erstellt.');
          }}
          onClose={() => setShowEmailCreateEditor(false)}
        />
      )}
    </div>
  );
}
