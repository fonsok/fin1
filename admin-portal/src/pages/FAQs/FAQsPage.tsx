import { useState, useEffect, useMemo, useCallback } from 'react';
import { Card } from '../../components/ui/Card';
import { Button } from '../../components/ui/Button';
import { PaginationBar } from '../../components/ui';
import { FAQList } from './components/FAQList';
import { FAQEditor } from './components/FAQEditor';
import {
  getFAQs,
  getFAQCategories,
  createFAQ,
  updateFAQ,
  deleteFAQ,
  exportFAQBackup,
  importFAQBackup,
  devResetFAQsBaseline,
  type FAQBackupPayload,
} from './api';
import type {
  FAQ,
  FAQCategory,
  CreateFAQRequest,
  UpdateFAQRequest,
} from './types';
import { useTheme } from '../../context/ThemeContext';
import clsx from 'clsx';
import { formatNumber } from '../../utils/format';
import { FAQDevMaintenanceCard } from './components/FAQDevMaintenanceCard';
import { isRetiredFaqCategorySlug } from './retiredFaqCategories';

type LocationFilter = 'all' | 'landing' | 'help_center' | 'investor' | 'trader';

const INVESTOR_CATEGORY_SLUGS = [
  'investments',
  'invoices',
  'notifications',
  'portfolio',
  'security',
  'technical',
];

const TRADER_CATEGORY_SLUGS = [
  'invoices',
  'notifications',
  'portfolio',
  'security',
  'technical',
  'trading',
];

export function FAQsPage() {
  const { theme } = useTheme();
  const isDark = theme === 'dark';

  const [faqs, setFaqs] = useState<FAQ[]>([]);
  const [categories, setCategories] = useState<FAQCategory[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const [showEditor, setShowEditor] = useState(false);
  const [editingFAQ, setEditingFAQ] = useState<FAQ | null>(null);
  const [importing, setImporting] = useState(false);
  const [faqDevResetting, setFaqDevResetting] = useState(false);

  const [locationFilter, setLocationFilter] = useState<LocationFilter>('all');
  const [categoryFilter, setCategoryFilter] = useState<string>('');
  const [searchQuery, setSearchQuery] = useState('');
  const [debouncedSearch, setDebouncedSearch] = useState('');

  const [page, setPage] = useState(0);
  const [pageSize, setPageSize] = useState(50);

  useEffect(() => {
    const t = window.setTimeout(() => setDebouncedSearch(searchQuery), 350);
    return () => window.clearTimeout(t);
  }, [searchQuery]);

  useEffect(() => {
    setPage(0);
  }, [locationFilter, categoryFilter, debouncedSearch]);

  useEffect(() => {
    if (!categoryFilter) return;
    const selected = categories.find((c) => c.objectId === categoryFilter);
    if (selected && isRetiredFaqCategorySlug(selected.slug)) {
      setCategoryFilter('');
    }
  }, [categories, categoryFilter]);

  const loadData = useCallback(async () => {
    setLoading(true);
    setError(null);
    try {
      const [faqsData, categoriesData] = await Promise.all([
        getFAQs(true),
        getFAQCategories(),
      ]);
      setFaqs(faqsData.faqs);
      setCategories(categoriesData.categories);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Fehler beim Laden der FAQs');
      console.error('Error loading FAQs:', err);
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    void loadData();
  }, [loadData]);

  const filteredFAQs = useMemo(() => {
    const filtered = faqs.filter((faq) => {
      const faqCategoryIds =
        faq.categoryIds && faq.categoryIds.length > 0 ? faq.categoryIds : [faq.categoryId].filter(Boolean);
      const faqCategories = faqCategoryIds
        .map((id) => categories.find((c) => c.objectId === id))
        .filter((c): c is FAQCategory => Boolean(c));

      if (locationFilter !== 'all') {
        if (faqCategories.length === 0) return false;

        const matchesAnyCategory = faqCategories.some((category) => {
          if (locationFilter === 'landing') return category.showOnLanding;
          if (locationFilter === 'help_center') return category.showInHelpCenter;
          const categorySlug = (category.slug || '').toLowerCase();
          if (locationFilter === 'investor') return INVESTOR_CATEGORY_SLUGS.includes(categorySlug);
          if (locationFilter === 'trader') return TRADER_CATEGORY_SLUGS.includes(categorySlug);
          return true;
        });

        if (!matchesAnyCategory) return false;
      }

      if (categoryFilter) {
        if (!faqCategoryIds.includes(categoryFilter)) return false;
      }

      if (debouncedSearch) {
        const q = debouncedSearch.toLowerCase();
        return (
          faq.question.toLowerCase().includes(q) ||
          faq.answer.toLowerCase().includes(q) ||
          (faq.questionEn?.toLowerCase().includes(q) ?? false) ||
          (faq.answerEn?.toLowerCase().includes(q) ?? false) ||
          (faq.questionDe?.toLowerCase().includes(q) ?? false) ||
          (faq.answerDe?.toLowerCase().includes(q) ?? false)
        );
      }

      return true;
    });
    return [...filtered].sort((a, b) =>
      (a.question || '').localeCompare(b.question || '', 'de', { sensitivity: 'base' }),
    );
  }, [faqs, categories, locationFilter, categoryFilter, debouncedSearch]);

  const totalFiltered = filteredFAQs.length;

  const pagedFAQs = useMemo(() => {
    return filteredFAQs.slice(page * pageSize, page * pageSize + pageSize);
  }, [filteredFAQs, page, pageSize]);

  const adminVisibleCategories = useMemo(
    () => categories.filter((c) => !isRetiredFaqCategorySlug(c.slug)),
    [categories],
  );

  const stats = useMemo(
    () => ({
      totalAll: faqs.length,
      publishedAll: faqs.filter((f) => f.isPublished).length,
    }),
    [faqs],
  );

  async function handleCreate(data: CreateFAQRequest) {
    const newFAQ = await createFAQ(data);
    setFaqs((prev) => [...prev, newFAQ]);
    setShowEditor(false);
    setEditingFAQ(null);
  }

  async function handleUpdate(objectId: string, data: UpdateFAQRequest) {
    const updated = await updateFAQ(objectId, data);
    setFaqs((prev) => prev.map((f) => (f.objectId === objectId ? updated : f)));
    setShowEditor(false);
    setEditingFAQ(null);
  }

  async function handleDelete(objectId: string) {
    if (!confirm('FAQ wirklich löschen?')) return;

    try {
      await deleteFAQ(objectId);
      setFaqs((prev) => prev.filter((f) => f.objectId !== objectId));
    } catch (err) {
      console.error('Error deleting FAQ:', err);
      alert('Fehler beim Löschen der FAQ');
    }
  }

  function handleEdit(faq: FAQ) {
    setEditingFAQ(faq);
    setShowEditor(true);
  }

  async function handleExportBackup() {
    try {
      const payload = await exportFAQBackup();
      const blob = new Blob([JSON.stringify(payload, null, 2)], { type: 'application/json' });
      const url = URL.createObjectURL(blob);
      const a = document.createElement('a');
      a.href = url;
      a.download = `faq-backup-${new Date().toISOString().slice(0, 10)}.json`;
      a.click();
      URL.revokeObjectURL(url);
    } catch (err) {
      alert('Export fehlgeschlagen: ' + (err instanceof Error ? err.message : 'Unbekannter Fehler'));
    }
  }

  async function handleImportBackupFile(file: File) {
    setImporting(true);
    try {
      const raw = await file.text();
      const backup = JSON.parse(raw) as FAQBackupPayload;
      const preview = await importFAQBackup({ backup, dryRun: true });
      const proceed = confirm(
        `Import-Preview (Dry-Run)\n\n` +
          `Kategorien: ${preview.counts.categoriesInput}\n` +
          `- Neu: ${preview.counts.categoriesCreated}\n` +
          `- Update: ${preview.counts.categoriesUpdated}\n\n` +
          `FAQs: ${preview.counts.faqsInput}\n` +
          `- Neu: ${preview.counts.faqsCreated}\n` +
          `- Update: ${preview.counts.faqsUpdated}\n` +
          `- Übersprungen: ${preview.counts.faqsSkipped}\n\n` +
          `${preview.warnings.length > 0 ? `Warnungen: ${preview.warnings.length}\n\n` : ''}` +
          `Jetzt wirklich importieren?`,
      );
      if (!proceed) return;

      const result = await importFAQBackup({ backup, dryRun: false });
      alert(
        `FAQ-Import abgeschlossen.\n\n` +
          `Kategorien: +${result.counts.categoriesCreated} / ~${result.counts.categoriesUpdated}\n` +
          `FAQs: +${result.counts.faqsCreated} / ~${result.counts.faqsUpdated}\n` +
          `Übersprungen: ${result.counts.faqsSkipped}` +
          `${result.warnings.length > 0 ? `\nWarnungen: ${result.warnings.length}` : ''}`,
      );
      await loadData();
    } catch (err) {
      alert('Import fehlgeschlagen: ' + (err instanceof Error ? err.message : 'Ungueltiges Backup'));
    } finally {
      setImporting(false);
    }
  }

  async function handleDevResetFAQsBaseline() {
    setFaqDevResetting(true);
    try {
      const preview = await devResetFAQsBaseline({ dryRun: true });
      const ok = window.confirm(
        `DEV FAQ Reset Preview (Dry-Run)\n\n` +
          `Aktive FAQs: ${preview.activeFound}\n` +
          `Geplante Klone: ${preview.clonesPlanned ?? preview.activeFound}\n` +
          `Inaktive FAQs (Hard-Delete geplant): ${preview.inactiveFaqsPlanned ?? 0}\n\n` +
          `Fortfahren? Klont veröffentlichte FAQs, löscht alte aktive Zeilen und alle inaktiven FAQs.`,
      );
      if (!ok) return;
      const result = await devResetFAQsBaseline({ dryRun: false });
      alert(
        `DEV FAQ Reset abgeschlossen.\n\n` +
          `Klone erstellt: ${result.clonesCreated ?? 0}\n` +
          `Inaktive FAQs gelöscht: ${result.deletedInactiveFaqs ?? 0}`,
      );
      await loadData();
    } catch (err) {
      const token = localStorage.getItem('parse_session');
      const tokenHint = token ? `${token.slice(0, 8)}…` : '(none)';
      alert(
        'DEV FAQ Reset fehlgeschlagen: ' +
          (err instanceof Error ? err.message : 'Unbekannter Fehler') +
          `\n\nDebug: parse_session=${tokenHint}\nHinweis: Auf dem Parse-Host ALLOW_FAQ_HARD_DELETE=true setzen (siehe AGB DEV-LEGAL analog).`,
      );
    } finally {
      setFaqDevResetting(false);
    }
  }

  function promptImportBackup() {
    const input = document.createElement('input');
    input.type = 'file';
    input.accept = 'application/json,.json';
    input.onchange = () => {
      const file = input.files?.[0];
      if (file) void handleImportBackupFile(file);
    };
    input.click();
  }

  if (loading) {
    return (
      <div className="flex items-center justify-center h-64">
        <div className="animate-spin w-8 h-8 border-4 border-fin1-primary border-t-transparent rounded-full"></div>
      </div>
    );
  }

  return (
    <div className="space-y-6">
      <FAQDevMaintenanceCard devResetting={faqDevResetting} onRunReset={handleDevResetFAQsBaseline} />

      <div className="flex justify-between items-center flex-wrap gap-2">
        <div>
          <h1 className="text-2xl font-bold text-gray-900">Hilfe & Anleitung</h1>
          <p className="text-gray-500">Häufig gestellte Fragen verwalten</p>
        </div>
        <div className="flex gap-2">
          <Button
            variant="secondary"
            onClick={handleExportBackup}
            title="Exportiert alle FAQ-Kategorien und FAQs als JSON-Backup (inkl. Frage-/Antworttexte, Sichtbarkeit, Sortierung und Zuordnungen). Empfohlen vor groesseren Aenderungen, Reseed oder Restore."
          >
            Export (Backup)
          </Button>
          <Button
            variant="secondary"
            onClick={promptImportBackup}
            disabled={importing}
            title="Importiert ein FAQ-JSON-Backup mit Sicherheitsstufe: zuerst Dry-Run-Vorschau (nur Analyse), danach bestaetigter Restore. Kategorien werden per slug und FAQs per faqId angelegt/aktualisiert; nicht aufloesbare Eintraege werden als Warnung ausgegeben."
          >
            {importing ? 'Importiere…' : 'Import (Restore)'}
          </Button>
          <Button onClick={() => setShowEditor(true)}>+ Neue FAQ</Button>
        </div>
      </div>

      {error && (
        <div className="bg-red-50 text-red-600 p-4 rounded-lg">
          {error}
          <button type="button" className="ml-4 underline" onClick={() => void loadData()}>
            Erneut versuchen
          </button>
        </div>
      )}

      <div className="grid grid-cols-3 gap-4">
        <Card className="p-4">
          <div className="text-sm text-gray-500">Gesamt Einträge</div>
          <div className="text-2xl font-bold text-gray-900">{formatNumber(stats.totalAll)}</div>
        </Card>
        <Card className="p-4">
          <div className="text-sm text-gray-500">Veröffentlicht</div>
          <div className="text-2xl font-bold text-gray-900">{formatNumber(stats.publishedAll)}</div>
        </Card>
        <Card className="p-4">
          <div className="text-sm text-gray-500">Kategorien</div>
          <div className="text-2xl font-bold text-gray-900">{formatNumber(adminVisibleCategories.length)}</div>
        </Card>
      </div>

      <Card className="p-4">
        <div className="flex gap-4 flex-wrap">
          <div className="flex-1 min-w-[200px]">
            <input
              type="text"
              placeholder="Suchen..."
              value={searchQuery}
              onChange={(e) => setSearchQuery(e.target.value)}
              className="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-fin1-primary focus:border-transparent"
            />
          </div>
          <select
            value={locationFilter}
            onChange={(e) => setLocationFilter(e.target.value as LocationFilter)}
            className="px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-fin1-primary focus:border-transparent"
          >
            <option value="all">Alle Kontexte</option>
            <option value="landing">Landing Page</option>
            <option value="help_center">Help Center</option>
            <option value="investor">Investor</option>
            <option value="trader">Trader</option>
          </select>
          <select
            value={categoryFilter}
            onChange={(e) => setCategoryFilter(e.target.value)}
            className="px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-fin1-primary focus:border-transparent"
          >
            <option value="">Alle Kategorien</option>
            {(() => {
              let availableCategories = categories;

              if (locationFilter === 'investor') {
                availableCategories = categories.filter((cat) => {
                  const slug = (cat.slug || '').toLowerCase();
                  return INVESTOR_CATEGORY_SLUGS.includes(slug);
                });
              } else if (locationFilter === 'trader') {
                availableCategories = categories.filter((cat) => {
                  const slug = (cat.slug || '').toLowerCase();
                  return TRADER_CATEGORY_SLUGS.includes(slug);
                });
              } else if (locationFilter === 'help_center') {
                availableCategories = categories.filter((cat) => cat.showInHelpCenter);
              } else if (locationFilter === 'landing') {
                availableCategories = categories.filter((cat) => cat.showOnLanding);
              }

              availableCategories = availableCategories.filter((cat) => !isRetiredFaqCategorySlug(cat.slug));

              return availableCategories.map((cat) => (
                <option key={cat.objectId} value={cat.objectId}>
                  {cat.displayName || cat.title || cat.slug}
                </option>
              ));
            })()}
          </select>
        </div>
      </Card>

      <div className="space-y-3">
        <div
          className={clsx(
            'flex flex-wrap items-center gap-3 justify-between rounded-lg border px-3 py-2',
            isDark ? 'border-slate-600 bg-slate-900/40' : 'border-gray-200 bg-gray-50',
          )}
        >
          <select
            value={pageSize}
            onChange={(e) => {
              setPageSize(Number(e.target.value));
              setPage(0);
            }}
            className={clsx(
              'border rounded-lg px-3 py-2 text-sm',
              isDark ? 'bg-slate-900/70 border-slate-600 text-slate-100' : 'bg-white border-gray-300 text-gray-900',
            )}
          >
            <option value={25}>25 / Seite</option>
            <option value={50}>50 / Seite</option>
            <option value={100}>100 / Seite</option>
          </select>
          <p className={clsx('text-sm', isDark ? 'text-slate-400' : 'text-gray-500')}>
            {formatNumber(totalFiltered)} Treffer nach Filter · bis zu {formatNumber(stats.totalAll)} aus Server (
            {formatNumber(pageSize)} pro Seite, lokal)
          </p>
        </div>

        <FAQList faqs={pagedFAQs} categories={categories} onEdit={handleEdit} onDelete={handleDelete} />

        {totalFiltered > 0 && (
          <PaginationBar
            page={page}
            pageSize={pageSize}
            total={totalFiltered}
            itemLabel="FAQs"
            isDark={isDark}
            onPageChange={setPage}
          />
        )}
      </div>

      {showEditor && (
        <FAQEditor
          faq={editingFAQ}
          categories={categories}
          onSave={async (data) => {
            if (editingFAQ) {
              await handleUpdate(editingFAQ.objectId, data as UpdateFAQRequest);
            } else {
              await handleCreate(data as CreateFAQRequest);
            }
          }}
          onClose={() => {
            setShowEditor(false);
            setEditingFAQ(null);
          }}
        />
      )}
    </div>
  );
}
