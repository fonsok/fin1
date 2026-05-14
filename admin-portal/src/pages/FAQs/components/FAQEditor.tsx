import { useState, useEffect } from 'react';
import * as React from 'react';
import clsx from 'clsx';
import { Button } from '../../../components/ui/Button';
import { Card } from '../../../components/ui/Card';
import { useTheme } from '../../../context/ThemeContext';
import type {
  FAQ,
  FAQCategory,
  CreateFAQRequest,
  UpdateFAQRequest,
  CreateFAQCategoryRequest,
} from '../types';
import { createFAQCategory } from '../api';
import { isRetiredFaqCategorySlug } from '../retiredFaqCategories';

import { adminBodyStrong, adminBorderChrome, adminLabel, adminMuted, adminPrimary } from '../../../utils/adminThemeClasses';
interface FAQEditorProps {
  faq: FAQ | null;
  categories: FAQCategory[];
  onSave: (data: CreateFAQRequest | UpdateFAQRequest) => Promise<void>;
  onClose: () => void;
}

export function FAQEditor({ faq, categories, onSave, onClose }: FAQEditorProps) {
  const { theme } = useTheme();
  const isDark = theme === 'dark';
  const isEdit = Boolean(faq);

  const fieldClass = clsx(
    'w-full px-4 py-2 rounded-lg focus:outline-none focus:ring-2 focus:ring-fin1-primary focus:border-fin1-primary',
    isDark
      ? 'bg-slate-900/90 border border-slate-600 text-slate-100 placeholder:text-slate-500'
      : 'border border-gray-300 text-gray-900 bg-white placeholder:text-gray-400',
  );

  const fieldClassSm = clsx(
    'w-full px-3 py-1.5 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-fin1-primary focus:border-fin1-primary',
    isDark
      ? 'bg-slate-900/90 border border-slate-600 text-slate-100 placeholder:text-slate-500'
      : 'border border-gray-300 text-gray-900 bg-white',
  );

  const hintBadgeClass = clsx(
    'inline-flex h-4 w-4 shrink-0 cursor-help select-none items-center justify-center rounded-full border text-[9px] font-semibold leading-none',
    isDark ? 'border-slate-500 text-slate-400' : 'border-gray-400 text-gray-500',
  );

  // Form state
  const [faqId, setFaqId] = useState(faq?.faqId || '');
  const [question, setQuestion] = useState(faq?.question || '');
  const [questionEn, setQuestionEn] = useState(faq?.questionEn ?? faq?.questionDe ?? '');
  const [answer, setAnswer] = useState(faq?.answer || '');
  const [answerEn, setAnswerEn] = useState(faq?.answerEn ?? faq?.answerDe ?? '');
  // Multi-category support: keep a list of selected category IDs.
  const initialCategoryIds =
    (faq?.categoryIds && faq.categoryIds.length > 0 && faq.categoryIds) ||
    (faq?.categoryId ? [faq.categoryId] : []);
  const [categoryIds, setCategoryIds] = useState<string[]>(initialCategoryIds);
  const [sortOrder, setSortOrder] = useState(() => {
    const raw = faq?.sortOrder;
    if (raw === undefined || raw === null) return 100;
    const n = Number(raw);
    return Number.isFinite(n) ? n : 100;
  });
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

    // Must match backend getFAQCategories(help_center): active AND (showOnLanding OR showInHelpCenter).
    // Previously this used tautologies (x || !x) and allowed „dead“ categories → FAQs visible in Admin but dropped in the iOS client.
    if (hasContext('help_center')) {
      filteredCategories = filteredCategories.filter((cat) => cat.showInHelpCenter || cat.showOnLanding);
    }
    if (hasContext('landing')) {
      filteredCategories = filteredCategories.filter((cat) => cat.showOnLanding);
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

    const selectedIdSet = new Set(categoryIds);
    const withLegacyRetired = unique.filter((cat) => {
      if (isRetiredFaqCategorySlug(cat.slug)) {
        return selectedIdSet.has(cat.objectId);
      }
      return true;
    });

    // Sort by sortOrder
    return withLegacyRetired.sort((a, b) => (a.sortOrder || 0) - (b.sortOrder || 0));
  }, [categories, contexts, categoryIds]);

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

    const normalizedContexts = contexts.length ? contexts : ['help_center'];
    const targetsHelpCenter = normalizedContexts.includes('help_center');
    if (targetsHelpCenter && !isPublic && !isUserVisible) {
      setError(
        'Für die App (Help Center): mindestens „Öffentlich“ oder „Für Benutzer sichtbar“ aktivieren — sonst liefert die API die FAQ nicht aus.',
      );
      return;
    }

    setSaving(true);

    try {
      const primaryCategoryId = categoryIds[0];

      const data: CreateFAQRequest | UpdateFAQRequest = {
        ...(isEdit ? {} : { faqId: faqId || undefined }),
        question: question.trim(),
        questionEn: questionEn.trim() || undefined,
        answer: answer.trim(),
        answerEn: answerEn.trim() || undefined,
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
      <Card className="max-w-3xl w-full max-h-[90vh] overflow-y-auto shadow-xl" padding="none">
        <form onSubmit={handleSubmit}>
          {/* Header */}
          <div className={clsx('p-6 border-b', adminBorderChrome(isDark))}>
            <h2 className={clsx('text-xl font-bold', adminPrimary(isDark))}>
              {isEdit ? 'FAQ bearbeiten' : 'Neue FAQ'}
            </h2>
          </div>

          {/* Content */}
          <div className="p-6 space-y-4">
            {error && (
              <div
                className={clsx(
                  'p-3 rounded-lg text-sm border',
                  isDark
                    ? 'bg-red-950/50 border-red-800/80 text-red-200'
                    : 'bg-red-50 border-transparent text-red-600',
                )}
              >
                {error}
              </div>
            )}

            {/* FAQ ID (only for new FAQs) */}
            {!isEdit && (
              <div>
                <label className={clsx('block text-sm font-medium mb-1', adminLabel(isDark))}>
                  FAQ ID (optional)
                </label>
                <input
                  type="text"
                  value={faqId}
                  onChange={(e) => setFaqId(e.target.value)}
                  placeholder="z.B. inv-1, landing-1"
                  className={fieldClass}
                />
                <p className={clsx('text-xs mt-1', adminMuted(isDark))}>
                  Eindeutige ID für diese FAQ (wird automatisch generiert wenn leer)
                </p>
              </div>
            )}

            {/* Kontext(e) – multiple contexts per FAQ */}
            <div>
              <label className={clsx('block text-sm font-medium mb-1', adminLabel(isDark))}>
                Kontexte
              </label>
              <div className="grid grid-cols-2 gap-2 text-sm">
                {[
                  { id: 'help_center', label: 'Help Center' },
                  { id: 'landing', label: 'Landing Page' },
                  { id: 'investor', label: 'Investor' },
                  { id: 'trader', label: 'Trader' },
                ].map((ctx) => (
                  <label
                    key={ctx.id}
                    className={clsx('flex items-center cursor-pointer', adminBodyStrong(isDark))}
                  >
                    <input
                      type="checkbox"
                      className="mr-2 accent-fin1-primary"
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
                  className={clsx(fieldClassSm, 'flex-1')}
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
              <p className={clsx('text-xs mt-1', adminMuted(isDark))}>
                Die verfügbaren Kategorien ändern sich je nach gewählten Kontexten. Eine FAQ kann mehreren
                Kontexten gleichzeitig zugeordnet sein. Eigene Kontext‑Tags können für zukünftige
                Erweiterungen ergänzt werden.
              </p>
            </div>

            {/* Category & Sort Order */}
            <div className="grid grid-cols-2 gap-4">
              <div>
                <label className={clsx('block text-sm font-medium mb-1', adminLabel(isDark))}>
                  Kategorien *
                </label>
                <div
                  className={clsx(
                    'rounded-lg max-h-48 overflow-y-auto px-3 py-2 space-y-1 border',
                    isDark ? 'border-slate-600 bg-slate-900/45' : 'border-gray-300 bg-white',
                  )}
                >
                  {availableCategories.map((cat) => {
                    const id = cat.objectId;
                    const checked = categoryIds.includes(id);
                    return (
                      <label
                        key={id}
                        className={clsx('flex items-center text-sm cursor-pointer', adminBodyStrong(isDark))}
                      >
                        <input
                          type="checkbox"
                          className="mr-2 accent-fin1-primary"
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
                    className={fieldClassSm}
                  />
                  <input
                    type="text"
                    value={newCategorySlug}
                    onChange={(e) => setNewCategorySlug(e.target.value)}
                    placeholder="Slug (z.B. investments_pro)"
                    className={fieldClassSm}
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
                  <p className={clsx('text-xs', adminMuted(isDark))}>
                    Neue Kategorien werden serverseitig in `FAQCategory` angelegt und sind auch für zukünftige
                    App‑Versionen nutzbar.
                  </p>
                </div>
              </div>

              <div>
                <label
                  className={clsx(
                    'flex items-center gap-1.5 text-sm font-medium mb-1',
                    adminLabel(isDark),
                  )}
                >
                  <span>Sortierung</span>
                  <span
                    role="img"
                    aria-label="Hilfe: Legt die Anzeigereihenfolge fest. Kleinere Zahlen erscheinen weiter oben. 100 ist nur ein Standardwert."
                    title="Legt die Anzeigereihenfolge in Listen (z. B. Help Center) fest: kleinere Zahlen erscheinen weiter oben, größere weiter unten. 100 ist ein beliebiger Standardwert — für die Reihenfolge z. B. 10, 20, 30 oder 1, 2, 3 nutzen."
                    className={hintBadgeClass}
                  >
                    i
                  </span>
                </label>
                <input
                  type="number"
                  value={sortOrder}
                  onChange={(e) => setSortOrder(parseInt(e.target.value) || 100)}
                  className={fieldClass}
                  title="Anzeigereihenfolge: niedrigere Zahl = weiter oben. 100 ist Standard."
                />
              </div>
            </div>

            {/* Question (DE) */}
            <div>
              <label className={clsx('block text-sm font-medium mb-1', adminLabel(isDark))}>
                Frage (DE) *
              </label>
              <textarea
                value={question}
                onChange={(e) => setQuestion(e.target.value)}
                placeholder="Was ist FIN1?"
                rows={2}
                className={fieldClass}
                required
              />
            </div>

            {/* Question (EN optional) */}
            <div>
              <label className={clsx('block text-sm font-medium mb-1', adminLabel(isDark))}>
                Frage (EN optional)
              </label>
              <textarea
                value={questionEn}
                onChange={(e) => setQuestionEn(e.target.value)}
                placeholder="What is FIN1?"
                rows={2}
                className={fieldClass}
              />
            </div>

            {/* Answer (DE) */}
            <div>
              <label className={clsx('block text-sm font-medium mb-1', adminLabel(isDark))}>
                Antwort (DE) *
              </label>
              <textarea
                value={answer}
                onChange={(e) => setAnswer(e.target.value)}
                placeholder="FIN1 ist eine Investment-Pool-App..."
                rows={6}
                className={fieldClass}
                required
              />
            </div>

            {/* Answer (EN optional) */}
            <div>
              <label className={clsx('block text-sm font-medium mb-1', adminLabel(isDark))}>
                Antwort (EN optional)
              </label>
              <textarea
                value={answerEn}
                onChange={(e) => setAnswerEn(e.target.value)}
                placeholder="FIN1 is an investment pool platform..."
                rows={6}
                className={fieldClass}
              />
            </div>

            {/* Status Flags */}
            <div className="grid grid-cols-1 sm:grid-cols-3 gap-4 pt-2">
              <label
                className={clsx(
                  'flex cursor-pointer items-center gap-1.5 text-sm',
                  adminBodyStrong(isDark),
                )}
              >
                <input
                  type="checkbox"
                  checked={isPublished}
                  onChange={(e) => setIsPublished(e.target.checked)}
                  className="accent-fin1-primary"
                  title="Deaktiviert = Entwurf: wird Endnutzern und Standard-API-Aufrufen nicht ausgeliefert (im Admin weiter sichtbar)."
                />
                <span>Veröffentlicht</span>
                <span
                  role="img"
                  aria-label="Hilfe Veröffentlicht: Entwurf vs. live."
                  title="Wenn deaktiviert, gilt die FAQ als Entwurf: Endnutzer und reguläre App-Abfragen erhalten sie nicht. Im Admin-Portal bleibt sie zur Bearbeitung sichtbar."
                  className={hintBadgeClass}
                >
                  i
                </span>
              </label>
              <label
                className={clsx(
                  'flex cursor-pointer items-center gap-1.5 text-sm',
                  adminBodyStrong(isDark),
                )}
              >
                <input
                  type="checkbox"
                  checked={isPublic}
                  onChange={(e) => setIsPublic(e.target.checked)}
                  className="accent-fin1-primary"
                  title="Öffentliche Kontexte (z. B. Landing ohne Login); im Help Center zusätzlich zu nutzersichtbaren FAQs."
                />
                <span>Öffentlich</span>
                <span
                  role="img"
                  aria-label="Hilfe Öffentlich: ohne Anmeldung abrufbar."
                  title="Erlaubt die Auslieferung in öffentlichen Kontexten ohne Anmeldung (z. B. Landing). Im Help Center werden öffentliche FAQs zusätzlich zu den als „für Benutzer sichtbar“ markierten Einträgen berücksichtigt."
                  className={hintBadgeClass}
                >
                  i
                </span>
              </label>
              <label
                className={clsx(
                  'flex cursor-pointer items-center gap-1.5 text-sm',
                  adminBodyStrong(isDark),
                )}
              >
                <input
                  type="checkbox"
                  checked={isUserVisible}
                  onChange={(e) => setIsUserVisible(e.target.checked)}
                  className="accent-fin1-primary"
                  title="Für eingeloggte Nutzer in der App (z. B. Help Center); kombinierbar mit „Öffentlich“."
                />
                <span>Für Benutzer sichtbar</span>
                <span
                  role="img"
                  aria-label="Hilfe: Sichtbarkeit für eingeloggte Nutzer."
                  title="Erlaubt die Anzeige für eingeloggte Nutzer in der App (z. B. Help Center). Sinnvoll für Inhalte nur für registrierte Nutzer; mit „Öffentlich“ lassen sich beide Zielgruppen abdecken."
                  className={hintBadgeClass}
                >
                  i
                </span>
              </label>
            </div>
          </div>

          {/* Footer */}
          <div className={clsx('p-6 border-t flex justify-end gap-3', adminBorderChrome(isDark))}>
            <Button type="button" variant="secondary" onClick={onClose} disabled={saving}>
              Abbrechen
            </Button>
            <Button type="submit" disabled={saving}>
              {saving ? 'Speichern...' : isEdit ? 'Aktualisieren' : 'Erstellen'}
            </Button>
          </div>
        </form>
      </Card>
    </div>
  );
}
