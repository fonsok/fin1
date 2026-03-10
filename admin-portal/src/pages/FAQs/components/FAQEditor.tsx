import { useState, useEffect } from 'react';
import * as React from 'react';
import { Button } from '../../../components/ui/Button';
import type {
  FAQ,
  FAQCategory,
  CreateFAQRequest,
  UpdateFAQRequest,
  CreateFAQCategoryRequest,
} from '../types';
import { createFAQCategory } from '../api';

interface FAQEditorProps {
  faq: FAQ | null;
  categories: FAQCategory[];
  onSave: (data: CreateFAQRequest | UpdateFAQRequest) => Promise<void>;
  onClose: () => void;
}

export function FAQEditor({ faq, categories, onSave, onClose }: FAQEditorProps) {
  const isEdit = Boolean(faq);

  // Form state
  const [faqId, setFaqId] = useState(faq?.faqId || '');
  const [question, setQuestion] = useState(faq?.question || '');
  const [questionDe, setQuestionDe] = useState(faq?.questionDe || '');
  const [answer, setAnswer] = useState(faq?.answer || '');
  const [answerDe, setAnswerDe] = useState(faq?.answerDe || '');
  // Multi-category support: keep a list of selected category IDs.
  const initialCategoryIds =
    (faq?.categoryIds && faq.categoryIds.length > 0 && faq.categoryIds) ||
    (faq?.categoryId ? [faq.categoryId] : []);
  const [categoryIds, setCategoryIds] = useState<string[]>(initialCategoryIds);
  const [sortOrder, setSortOrder] = useState(faq?.sortOrder || 100);
  const [isPublished, setIsPublished] = useState(faq?.isPublished ?? true);
  const [isPublic, setIsPublic] = useState(faq?.isPublic ?? true);
  const [isUserVisible, setIsUserVisible] = useState(faq?.isUserVisible ?? true);
  // Multi-context support: allow assigning multiple logical contexts to a single FAQ.
  const initialContexts =
    (faq?.contexts && faq.contexts.length > 0 && faq.contexts) ||
    (faq?.source ? [faq.source] : ['help_center']);
  const [contexts, setContexts] = useState<string[]>(initialContexts);
  const [newContext, setNewContext] = useState('');

  // Local state for quick category creation
  const [newCategoryName, setNewCategoryName] = useState('');
  const [newCategorySlug, setNewCategorySlug] = useState('');
  const [creatingCategory, setCreatingCategory] = useState(false);

  // Filter and deduplicate categories based on selected source/context
  const availableCategories = React.useMemo(() => {
    // Filter categories based on source/context.
    // For multi-context we take all categories that match at least one selected context.
    let filteredCategories = categories;

    const hasContext = (ctx: string) => contexts.includes(ctx);

    if (hasContext('help_center')) {
      filteredCategories = filteredCategories.filter((cat) => cat.showInHelpCenter || !cat.showInHelpCenter);
    }
    if (hasContext('landing')) {
      filteredCategories = filteredCategories.filter((cat) => cat.showOnLanding || !cat.showOnLanding);
    }

    // Investor / Trader contexts are defined via category slugs
    const investorSlugs = ['investments', 'invoices', 'notifications', 'portfolio', 'security', 'technical'];
    const traderSlugs = ['invoices', 'notifications', 'portfolio', 'security', 'technical', 'trading'];

    if (hasContext('investor')) {
      filteredCategories = filteredCategories.filter((cat) => {
        const slug = (cat.slug || '').toLowerCase();
        return investorSlugs.includes(slug);
      });
    }

    if (hasContext('trader')) {
      filteredCategories = filteredCategories.filter((cat) => {
        const slug = (cat.slug || '').toLowerCase();
        return traderSlugs.includes(slug);
      });
    }

    // Remove duplicates by slug (keep first occurrence)
    const seen = new Set<string>();
    const unique = filteredCategories.filter((cat) => {
      const slug = (cat.slug || '').toLowerCase();
      if (seen.has(slug)) return false;
      seen.add(slug);
      return true;
    });

    // Sort by sortOrder
    return unique.sort((a, b) => (a.sortOrder || 0) - (b.sortOrder || 0));
  }, [categories, contexts]);

  const [saving, setSaving] = useState(false);
  const [error, setError] = useState<string | null>(null);

  // Reset category if current one is not available in new context
  useEffect(() => {
    if (availableCategories.length === 0) {
      setCategoryIds([]);
      return;
    }

    const availableIds = new Set(availableCategories.map((cat) => cat.objectId));
    const stillValid = categoryIds.filter((id) => availableIds.has(id));

    if (stillValid.length === 0) {
      setCategoryIds([availableCategories[0].objectId]);
    } else if (stillValid.length !== categoryIds.length) {
      setCategoryIds(stillValid);
    }
  }, [categoryIds, availableCategories]);

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    setError(null);

    if (!question.trim() || !answer.trim()) {
      setError('Frage und Antwort sind erforderlich');
      return;
    }

    if (!categoryIds.length) {
      setError('Mindestens eine Kategorie ist erforderlich');
      return;
    }

    setSaving(true);

    try {
      const primaryCategoryId = categoryIds[0];
      const normalizedContexts = contexts.length ? contexts : ['help_center'];

      const data: CreateFAQRequest | UpdateFAQRequest = {
        ...(isEdit ? {} : { faqId: faqId || undefined }),
        question: question.trim(),
        questionDe: questionDe.trim() || undefined,
        answer: answer.trim(),
        answerDe: answerDe.trim() || undefined,
        categoryId: primaryCategoryId,
        categoryIds,
        sortOrder,
        isPublished,
        isPublic,
        isUserVisible,
        source: normalizedContexts[0],
        contexts: normalizedContexts,
      };

      await onSave(data);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Fehler beim Speichern');
    } finally {
      setSaving(false);
    }
  }

  return (
    <div className="fixed inset-0 bg-black/50 flex items-center justify-center z-50 p-4">
      <div className="bg-white rounded-xl shadow-xl max-w-3xl w-full max-h-[90vh] overflow-y-auto">
        <form onSubmit={handleSubmit}>
          {/* Header */}
          <div className="p-6 border-b border-gray-200">
            <h2 className="text-xl font-bold text-gray-900">
              {isEdit ? 'FAQ bearbeiten' : 'Neue FAQ'}
            </h2>
          </div>

          {/* Content */}
          <div className="p-6 space-y-4">
            {error && (
              <div className="bg-red-50 text-red-600 p-3 rounded-lg text-sm">{error}</div>
            )}

            {/* FAQ ID (only for new FAQs) */}
            {!isEdit && (
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">
                  FAQ ID (optional)
                </label>
                <input
                  type="text"
                  value={faqId}
                  onChange={(e) => setFaqId(e.target.value)}
                  placeholder="z.B. inv-1, landing-1"
                  className="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-fin1-primary focus:border-transparent"
                />
                <p className="text-xs text-gray-500 mt-1">
                  Eindeutige ID für diese FAQ (wird automatisch generiert wenn leer)
                </p>
              </div>
            )}

            {/* Kontext(e) – multiple contexts per FAQ */}
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1">Kontexte</label>
              <div className="grid grid-cols-2 gap-2 text-sm">
                {[
                  { id: 'help_center', label: 'Help Center' },
                  { id: 'landing', label: 'Landing Page' },
                  { id: 'investor', label: 'Investor' },
                  { id: 'trader', label: 'Trader' },
                ].map((ctx) => (
                  <label key={ctx.id} className="flex items-center">
                    <input
                      type="checkbox"
                      className="mr-2"
                      checked={contexts.includes(ctx.id)}
                      onChange={(e) => {
                        setContexts((prev) =>
                          e.target.checked ? [...prev, ctx.id] : prev.filter((c) => c !== ctx.id)
                        );
                      }}
                    />
                    {ctx.label}
                  </label>
                ))}
              </div>
              <div className="mt-2 flex items-center gap-2">
                <input
                  type="text"
                  value={newContext}
                  onChange={(e) => setNewContext(e.target.value)}
                  placeholder="Neuen Kontext hinzufügen (z.B. csr_help)"
                  className="flex-1 px-3 py-1.5 border border-gray-300 rounded-lg text-sm focus:ring-2 focus:ring-fin1-primary focus:border-transparent"
                />
                <Button
                  type="button"
                  variant="secondary"
                  size="sm"
                  disabled={!newContext.trim()}
                  onClick={() => {
                    const value = newContext.trim();
                    if (!value) return;
                    setContexts((prev) => (prev.includes(value) ? prev : [...prev, value]));
                    setNewContext('');
                  }}
                >
                  Hinzufügen
                </Button>
              </div>
              <p className="text-xs text-gray-500 mt-1">
                Die verfügbaren Kategorien ändern sich je nach gewählten Kontexten. Eine FAQ kann mehreren
                Kontexten gleichzeitig zugeordnet sein. Eigene Kontext‑Tags können für zukünftige
                Erweiterungen ergänzt werden.
              </p>
            </div>

            {/* Category & Sort Order */}
            <div className="grid grid-cols-2 gap-4">
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">
                  Kategorien *
                </label>
                <div className="border border-gray-300 rounded-lg max-h-48 overflow-y-auto px-3 py-2 space-y-1">
                  {availableCategories.map((cat) => {
                    const id = cat.objectId;
                    const checked = categoryIds.includes(id);
                    return (
                      <label key={id} className="flex items-center text-sm">
                        <input
                          type="checkbox"
                          className="mr-2"
                          checked={checked}
                          onChange={(e) => {
                            setCategoryIds((prev) =>
                              e.target.checked ? [...prev, id] : prev.filter((c) => c !== id)
                            );
                          }}
                        />
                        {cat.displayName || cat.title || cat.slug}
                      </label>
                    );
                  })}
                </div>
                <div className="mt-2 space-y-1">
                  <input
                    type="text"
                    value={newCategoryName}
                    onChange={(e) => setNewCategoryName(e.target.value)}
                    placeholder="Neue Kategorie (Titel)"
                    className="w-full px-3 py-1.5 border border-gray-300 rounded-lg text-sm focus:ring-2 focus:ring-fin1-primary focus:border-transparent"
                  />
                  <input
                    type="text"
                    value={newCategorySlug}
                    onChange={(e) => setNewCategorySlug(e.target.value)}
                    placeholder="Slug (z.B. investments_pro)"
                    className="w-full px-3 py-1.5 border border-gray-300 rounded-lg text-sm focus:ring-2 focus:ring-fin1-primary focus:border-transparent"
                  />
                  <Button
                    type="button"
                    size="sm"
                    variant="secondary"
                    disabled={creatingCategory || !newCategorySlug.trim() || !newCategoryName.trim()}
                    onClick={async () => {
                      setError(null);
                      try {
                        setCreatingCategory(true);
                        const payload: CreateFAQCategoryRequest = {
                          slug: newCategorySlug.trim().toLowerCase(),
                          title: newCategoryName.trim(),
                          isActive: true,
                          showInHelpCenter: true,
                          showInCSR: true,
                        };
                        const created = (await createFAQCategory(payload)) as FAQCategory;
                        // Add to selected categories and available list via local state
                        setCategoryIds((prev) => (prev.includes(created.objectId) ? prev : [...prev, created.objectId]));
                      } catch (e) {
                        setError(
                          e instanceof Error ? e.message : 'Neue Kategorie konnte nicht erstellt werden. Slug einzigartig?'
                        );
                      } finally {
                        setCreatingCategory(false);
                      }
                    }}
                  >
                    {creatingCategory ? 'Kategorie wird angelegt…' : 'Neue Kategorie anlegen'}
                  </Button>
                  <p className="text-xs text-gray-500">
                    Neue Kategorien werden serverseitig in `FAQCategory` angelegt und sind auch für zukünftige
                    App‑Versionen nutzbar.
                  </p>
                </div>
              </div>

              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">
                  Sortierung
                </label>
                <input
                  type="number"
                  value={sortOrder}
                  onChange={(e) => setSortOrder(parseInt(e.target.value) || 100)}
                  className="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-fin1-primary focus:border-transparent"
                />
              </div>
            </div>

            {/* Question (EN) */}
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1">
                Frage (EN) *
              </label>
              <textarea
                value={question}
                onChange={(e) => setQuestion(e.target.value)}
                placeholder="What is FIN1?"
                rows={2}
                className="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-fin1-primary focus:border-transparent"
                required
              />
            </div>

            {/* Question (DE) */}
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1">
                Frage (DE)
              </label>
              <textarea
                value={questionDe}
                onChange={(e) => setQuestionDe(e.target.value)}
                placeholder="Was ist FIN1?"
                rows={2}
                className="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-fin1-primary focus:border-transparent"
              />
            </div>

            {/* Answer (EN) */}
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1">
                Antwort (EN) *
              </label>
              <textarea
                value={answer}
                onChange={(e) => setAnswer(e.target.value)}
                placeholder="FIN1 is an investment pool platform..."
                rows={6}
                className="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-fin1-primary focus:border-transparent"
                required
              />
            </div>

            {/* Answer (DE) */}
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1">
                Antwort (DE)
              </label>
              <textarea
                value={answerDe}
                onChange={(e) => setAnswerDe(e.target.value)}
                placeholder="FIN1 ist eine Investment-Pool-Plattform..."
                rows={6}
                className="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-fin1-primary focus:border-transparent"
              />
            </div>

            {/* Status Flags */}
            <div className="grid grid-cols-3 gap-4 pt-2">
              <label className="flex items-center">
                <input
                  type="checkbox"
                  checked={isPublished}
                  onChange={(e) => setIsPublished(e.target.checked)}
                  className="mr-2"
                />
                <span className="text-sm text-gray-700">Veröffentlicht</span>
              </label>
              <label className="flex items-center">
                <input
                  type="checkbox"
                  checked={isPublic}
                  onChange={(e) => setIsPublic(e.target.checked)}
                  className="mr-2"
                />
                <span className="text-sm text-gray-700">Öffentlich</span>
              </label>
              <label className="flex items-center">
                <input
                  type="checkbox"
                  checked={isUserVisible}
                  onChange={(e) => setIsUserVisible(e.target.checked)}
                  className="mr-2"
                />
                <span className="text-sm text-gray-700">Für Benutzer sichtbar</span>
              </label>
            </div>
          </div>

          {/* Footer */}
          <div className="p-6 border-t border-gray-200 flex justify-end gap-3">
            <Button type="button" variant="secondary" onClick={onClose} disabled={saving}>
              Abbrechen
            </Button>
            <Button type="submit" disabled={saving}>
              {saving ? 'Speichern...' : isEdit ? 'Aktualisieren' : 'Erstellen'}
            </Button>
          </div>
        </form>
      </div>
    </div>
  );
}
