import { useState, useEffect } from 'react';
import { Card } from '../../components/ui/Card';
import { Button } from '../../components/ui/Button';
import { FAQList } from './components/FAQList';
import { FAQEditor } from './components/FAQEditor';
import {
  getFAQs,
  getFAQCategories,
  createFAQ,
  updateFAQ,
  deleteFAQ,
} from './api';
import type {
  FAQ,
  FAQCategory,
  CreateFAQRequest,
  UpdateFAQRequest,
} from './types';

type LocationFilter = 'all' | 'landing' | 'help_center' | 'investor' | 'trader';

export function FAQsPage() {
  // State
  const [faqs, setFaqs] = useState<FAQ[]>([]);
  const [categories, setCategories] = useState<FAQCategory[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  // Editor state
  const [showEditor, setShowEditor] = useState(false);
  const [editingFAQ, setEditingFAQ] = useState<FAQ | null>(null);

  // Filter state
  const [locationFilter, setLocationFilter] = useState<LocationFilter>('all');
  const [categoryFilter, setCategoryFilter] = useState<string>('');
  const [searchQuery, setSearchQuery] = useState('');

  // Load data
  useEffect(() => {
    loadData();
  }, []);

  async function loadData() {
    setLoading(true);
    setError(null);

    try {
      // Load all categories (not filtered by location) so we can filter by Investor/Trader contexts
      const [faqsData, categoriesData] = await Promise.all([
        getFAQs(true),
        getFAQCategories(), // Load all categories, not just help_center
      ]);

      setFaqs(faqsData.faqs);
      setCategories(categoriesData.categories);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Fehler beim Laden der FAQs');
      console.error('Error loading FAQs:', err);
    } finally {
      setLoading(false);
    }
  }

  // Define category slugs for each context
  const investorCategorySlugs = [
    'investments',
    'invoices',
    'notifications',
    'portfolio',
    'security',
    'technical',
  ];

  const traderCategorySlugs = [
    'invoices',
    'notifications',
    'portfolio',
    'security',
    'technical',
    'trading',
  ];

  // Filter FAQs
  const filteredFAQs = faqs.filter((faq) => {
    // Collect all categories this FAQ is assigned to (multi-category aware)
    const faqCategoryIds = faq.categoryIds && faq.categoryIds.length > 0 ? faq.categoryIds : [faq.categoryId];
    const faqCategories = faqCategoryIds
      .map((id) => categories.find((c) => c.objectId === id))
      .filter((c): c is FAQCategory => Boolean(c));

    // Location filter
    if (locationFilter !== 'all') {
      if (faqCategories.length === 0) return false;

      const matchesAnyCategory = faqCategories.some((category) => {
        if (locationFilter === 'landing') {
          return category.showOnLanding;
        }
        if (locationFilter === 'help_center') {
          return category.showInHelpCenter;
        }

        const categorySlug = (category.slug || '').toLowerCase();

        // Investor context: filter by category slugs
        if (locationFilter === 'investor') {
          return investorCategorySlugs.includes(categorySlug);
        }

        // Trader context: filter by category slugs
        if (locationFilter === 'trader') {
          return traderCategorySlugs.includes(categorySlug);
        }

        return true;
      });

      if (!matchesAnyCategory) return false;
    }

    // Category filter
    if (categoryFilter) {
      if (!faqCategoryIds.includes(categoryFilter)) return false;
    }

    // Search filter
    if (searchQuery) {
      const query = searchQuery.toLowerCase();
      return (
        faq.question.toLowerCase().includes(query) ||
        faq.answer.toLowerCase().includes(query) ||
        (faq.questionDe?.toLowerCase().includes(query) ?? false) ||
        (faq.answerDe?.toLowerCase().includes(query) ?? false)
      );
    }

    return true;
  });

  // Handlers
  async function handleCreate(data: CreateFAQRequest) {
    try {
      const newFAQ = await createFAQ(data);
      setFaqs((prev) => [...prev, newFAQ]);
      setShowEditor(false);
      setEditingFAQ(null);
    } catch (err) {
      throw err;
    }
  }

  async function handleUpdate(objectId: string, data: UpdateFAQRequest) {
    try {
      const updated = await updateFAQ(objectId, data);
      setFaqs((prev) => prev.map((f) => (f.objectId === objectId ? updated : f)));
      setShowEditor(false);
      setEditingFAQ(null);
    } catch (err) {
      throw err;
    }
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
          <h1 className="text-2xl font-bold text-gray-900">Hilfe & Anleitung</h1>
          <p className="text-gray-500">Häufig gestellte Fragen verwalten</p>
        </div>
        <Button onClick={() => setShowEditor(true)}>+ Neue FAQ</Button>
      </div>

      {/* Error */}
      {error && (
        <div className="bg-red-50 text-red-600 p-4 rounded-lg">
          {error}
          <button className="ml-4 underline" onClick={loadData}>
            Erneut versuchen
          </button>
        </div>
      )}

      {/* Stats */}
      <div className="grid grid-cols-3 gap-4">
        <Card className="p-4">
          <div className="text-sm text-gray-500">Gesamt Einträge</div>
          <div className="text-2xl font-bold text-gray-900">{faqs.length}</div>
        </Card>
        <Card className="p-4">
          <div className="text-sm text-gray-500">Veröffentlicht</div>
          <div className="text-2xl font-bold text-gray-900">
            {faqs.filter((f) => f.isPublished).length}
          </div>
        </Card>
        <Card className="p-4">
          <div className="text-sm text-gray-500">Kategorien</div>
          <div className="text-2xl font-bold text-gray-900">{categories.length}</div>
        </Card>
      </div>

      {/* Filters */}
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
              // Filter categories based on location filter
              let availableCategories = categories;

              if (locationFilter === 'investor') {
                availableCategories = categories.filter((cat) => {
                  const slug = (cat.slug || '').toLowerCase();
                  return investorCategorySlugs.includes(slug);
                });
              } else if (locationFilter === 'trader') {
                availableCategories = categories.filter((cat) => {
                  const slug = (cat.slug || '').toLowerCase();
                  return traderCategorySlugs.includes(slug);
                });
              } else if (locationFilter === 'help_center') {
                availableCategories = categories.filter((cat) => cat.showInHelpCenter);
              } else if (locationFilter === 'landing') {
                availableCategories = categories.filter((cat) => cat.showOnLanding);
              }

              return availableCategories.map((cat) => (
                <option key={cat.objectId} value={cat.objectId}>
                  {cat.icon || '📁'} {cat.displayName || cat.title || cat.slug}
                </option>
              ));
            })()}
          </select>
        </div>
      </Card>

      {/* FAQ List */}
      <FAQList
        faqs={filteredFAQs}
        categories={categories}
        onEdit={handleEdit}
        onDelete={handleDelete}
      />

      {/* Editor Modal */}
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
