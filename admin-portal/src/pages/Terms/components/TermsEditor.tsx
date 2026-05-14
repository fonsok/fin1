import { useState, useMemo } from 'react';
import clsx from 'clsx';
import { Button } from '../../../components/ui/Button';
import { useTheme } from '../../../context/ThemeContext';
import type { TermsContentFull, TermsSection, CreateTermsContentRequest } from '../types';
import { createTermsContent } from '../api';

import { adminLabel, adminMuted, adminPrimary, adminSoft } from '../../../utils/adminThemeClasses';
function filterSectionsBySearch(sections: TermsSection[], query: string): { section: TermsSection; index: number }[] {
  const q = query.trim().toLowerCase();
  if (!q) return sections.map((s, i) => ({ section: s, index: i }));
  return sections
    .map((s, i) => ({ section: s, index: i }))
    .filter(
      ({ section }) =>
        (section.title && section.title.toLowerCase().includes(q)) ||
        (section.content && section.content.toLowerCase().includes(q)) ||
        (section.id && section.id.toLowerCase().includes(q))
    );
}

interface TermsEditorProps {
  /** When set, form is prefilled from this version (clone mode). */
  cloneFrom?: TermsContentFull | null;
  initialSectionSearch?: string;
  onSaved: () => void;
  onClose: () => void;
}

const DOCUMENT_TYPES = [
  { value: 'terms', label: 'AGB / Terms of Service' },
  { value: 'privacy', label: 'Datenschutz' },
  { value: 'imprint', label: 'Impressum' },
];

function getNextSemanticVersion(previous?: string | null): string {
  const trimmed = (previous ?? '').trim();
  if (!trimmed) return '1.0.0';
  const match = trimmed.match(/^(\d+)\.(\d+)\.(\d+)(.*)$/);
  if (!match) {
    return trimmed;
  }
  const [, major, minor, patch, suffix] = match;
  const nextPatch = Number(patch) + 1;
  return `${major}.${minor}.${nextPatch}${suffix}`;
}

export function TermsEditor({ cloneFrom, initialSectionSearch, onSaved, onClose }: TermsEditorProps) {
  const { theme } = useTheme();
  const isDark = theme === 'dark';
  const [version, setVersion] = useState(
    cloneFrom ? getNextSemanticVersion(cloneFrom.version) : '1.0.0'
  );
  const [language, setLanguage] = useState(cloneFrom?.language ?? 'de');
  const [documentType, setDocumentType] = useState(cloneFrom?.documentType ?? 'terms');
  const [effectiveDate, setEffectiveDate] = useState(
    cloneFrom?.effectiveDate?.slice(0, 10) ?? new Date().toISOString().slice(0, 10)
  );
  const [sections, setSections] = useState<TermsSection[]>(
    cloneFrom?.sections?.length
      ? cloneFrom.sections.map((s) => ({ ...s }))
      : [{ id: 'intro', title: '', content: '', icon: 'document-text' }]
  );
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [sectionSearch, setSectionSearch] = useState(initialSectionSearch ?? '');

  const filteredSectionsForDisplay = useMemo(
    () => filterSectionsBySearch(sections, sectionSearch),
    [sections, sectionSearch]
  );

  function addSection() {
    setSections((prev) => [
      ...prev,
      { id: `sec-${Date.now()}`, title: '', content: '', icon: 'document-text' },
    ]);
  }

  function removeSection(index: number) {
    setSections((prev) => prev.filter((_, i) => i !== index));
  }

  function updateSection(index: number, field: keyof TermsSection, value: string) {
    setSections((prev) => {
      const next = [...prev];
      next[index] = { ...next[index], [field]: value };
      return next;
    });
  }

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    setError(null);
    if (!version.trim()) {
      setError('Version ist erforderlich');
      return;
    }
    if (sections.length === 0 || sections.every((s) => !s.title?.trim() && !s.content?.trim())) {
      setError('Mindestens ein Abschnitt mit Titel oder Inhalt ist erforderlich');
      return;
    }
    const trimmed = sections.map((s) => ({
      id: (s.id || '').trim() || `sec-${Date.now()}`,
      title: (s.title || '').trim(),
      content: (s.content || '').trim(),
      icon: (s.icon || 'document-text').trim(),
    }));
    const withContent = trimmed.filter((s) => s.title || s.content);
    if (withContent.length === 0) {
      setError('Mindestens ein Abschnitt mit Titel oder Inhalt ist erforderlich');
      return;
    }
    setSaving(true);
    try {
      const payload: CreateTermsContentRequest = {
        version: version.trim(),
        language,
        documentType,
        effectiveDate: effectiveDate || new Date().toISOString().slice(0, 10),
        isActive: false,
        sections: withContent,
      };
      await createTermsContent(payload);
      onSaved();
      onClose();
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Speichern fehlgeschlagen');
    } finally {
      setSaving(false);
    }
  }

  return (
    <div className="fixed inset-0 bg-black/50 flex items-center justify-center z-50 p-4">
      <div
        className={clsx(
          'rounded-xl shadow-xl max-w-4xl w-full max-h-[90vh] overflow-y-auto border',
          isDark ? 'bg-slate-800 border-slate-600' : 'bg-white border-gray-200',
        )}
      >
        <form onSubmit={handleSubmit}>
          <div className={clsx('p-6 border-b', isDark ? 'border-slate-600' : 'border-gray-200')}>
            <h2 className={clsx('text-xl font-bold', adminPrimary(isDark))}>
              {cloneFrom ? 'Neue Version aus Klon' : 'Neue Rechtstext-Version'}
            </h2>
            <p className={clsx('text-sm mt-1', adminMuted(isDark))}>
              Platzhalter wie {`{{APP_NAME}}`} / {`{{LEGAL_PLATFORM_NAME}}`} werden serverseitig ersetzt. Version wird zunächst inaktiv angelegt; danach „Als aktiv setzen“ nutzen.
            </p>
          </div>
          <div className="p-6 space-y-4">
            {error && (
              <div className={clsx('p-3 rounded-lg text-sm', isDark ? 'bg-red-900/30 text-red-300' : 'bg-red-50 text-red-600')}>{error}</div>
            )}
            <div className="grid grid-cols-2 gap-4">
              <div>
                <label className={clsx('block text-sm font-medium mb-1', adminLabel(isDark))}>Version *</label>
                <input
                  type="text"
                  value={version}
                  onChange={(e) => setVersion(e.target.value)}
                  placeholder="z.B. 1.1"
                  className={clsx(
                    'w-full px-4 py-2 border rounded-lg focus:ring-2 focus:ring-fin1-primary focus:border-transparent',
                    isDark ? 'bg-slate-900/70 border-slate-600 text-slate-100' : 'bg-white border-gray-300 text-gray-900',
                  )}
                  required
                />
              </div>
              <div>
                <label className={clsx('block text-sm font-medium mb-1', adminLabel(isDark))}>Gültig ab *</label>
                <input
                  type="date"
                  value={effectiveDate}
                  onChange={(e) => setEffectiveDate(e.target.value)}
                  className={clsx(
                    'w-full px-4 py-2 border rounded-lg focus:ring-2 focus:ring-fin1-primary focus:border-transparent',
                    isDark ? 'bg-slate-900/70 border-slate-600 text-slate-100' : 'bg-white border-gray-300 text-gray-900',
                  )}
                  required
                />
              </div>
            </div>
            <div className="grid grid-cols-2 gap-4">
              <div>
                <label className={clsx('block text-sm font-medium mb-1', adminLabel(isDark))}>Sprache</label>
                <select
                  value={language}
                  onChange={(e) => setLanguage(e.target.value)}
                  className={clsx(
                    'w-full px-4 py-2 border rounded-lg focus:ring-2 focus:ring-fin1-primary focus:border-transparent',
                    isDark ? 'bg-slate-900/70 border-slate-600 text-slate-100' : 'bg-white border-gray-300 text-gray-900',
                  )}
                >
                  <option value="de">Deutsch</option>
                  <option value="en">English</option>
                </select>
              </div>
              <div>
                <label className={clsx('block text-sm font-medium mb-1', adminLabel(isDark))}>Dokumenttyp</label>
                <select
                  value={documentType}
                  onChange={(e) => setDocumentType(e.target.value)}
                  className={clsx(
                    'w-full px-4 py-2 border rounded-lg focus:ring-2 focus:ring-fin1-primary focus:border-transparent',
                    isDark ? 'bg-slate-900/70 border-slate-600 text-slate-100' : 'bg-white border-gray-300 text-gray-900',
                  )}
                >
                  {DOCUMENT_TYPES.map((opt) => (
                    <option key={opt.value} value={opt.value}>{opt.label}</option>
                  ))}
                </select>
              </div>
            </div>

            <div>
              <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-2 mb-2">
                <label className={clsx('block text-sm font-medium', adminLabel(isDark))}>Abschnitte *</label>
                <div className="flex items-center gap-2 flex-1 sm:max-w-md">
                  <input
                    type="search"
                    placeholder="Abschnitte durchsuchen (Titel, Inhalt, ID)…"
                    value={sectionSearch}
                    onChange={(e) => setSectionSearch(e.target.value)}
                    className={clsx(
                      'flex-1 min-w-0 rounded-md border px-3 py-1.5 text-sm focus:border-fin1-primary focus:ring-1 focus:ring-fin1-primary',
                      isDark ? 'bg-slate-900/70 border-slate-600 text-slate-100' : 'bg-white border-gray-300 text-gray-900',
                    )}
                  />
                  {sectionSearch.trim() && (
                    <span className={clsx('text-sm whitespace-nowrap', adminMuted(isDark))}>
                      {filteredSectionsForDisplay.length} / {sections.length}
                    </span>
                  )}
                </div>
                <Button type="button" variant="secondary" size="sm" onClick={addSection}>
                  + Abschnitt
                </Button>
              </div>
              <div className={clsx('space-y-4 border rounded-lg p-4 max-h-[40vh] overflow-y-auto', isDark ? 'border-slate-600 bg-slate-900/20' : 'border-gray-200')}>
                {filteredSectionsForDisplay.length === 0 ? (
                  <p className={clsx('text-sm py-4', adminMuted(isDark))}>
                    {sectionSearch.trim()
                      ? 'Kein Abschnitt enthält den Suchbegriff.'
                      : 'Keine Abschnitte.'}
                  </p>
                ) : (
                  filteredSectionsForDisplay.map(({ section, index }) => (
                    <div key={index} className={clsx('border rounded p-3', isDark ? 'border-slate-700 bg-slate-800/40' : 'border-gray-100 bg-gray-50/50')}>
                      <div className="flex justify-between items-center mb-2">
                        <span className={clsx('text-sm font-medium', adminSoft(isDark))}>Abschnitt {index + 1}</span>
                        <Button
                          type="button"
                          variant="secondary"
                          size="sm"
                          onClick={() => removeSection(index)}
                          disabled={sections.length <= 1}
                        >
                          Entfernen
                        </Button>
                      </div>
                      <div className="grid grid-cols-2 gap-2 mb-2">
                        <input
                          type="text"
                          value={section.id}
                          onChange={(e) => updateSection(index, 'id', e.target.value)}
                          placeholder="ID (z.B. intro)"
                          className={clsx('px-3 py-1.5 border rounded text-sm', isDark ? 'bg-slate-900/70 border-slate-600 text-slate-100' : 'bg-white border-gray-300 text-gray-900')}
                        />
                        <input
                          type="text"
                          value={section.icon}
                          onChange={(e) => updateSection(index, 'icon', e.target.value)}
                          placeholder="Icon (z.B. document-text)"
                          className={clsx('px-3 py-1.5 border rounded text-sm', isDark ? 'bg-slate-900/70 border-slate-600 text-slate-100' : 'bg-white border-gray-300 text-gray-900')}
                        />
                      </div>
                      <input
                        type="text"
                        value={section.title}
                        onChange={(e) => updateSection(index, 'title', e.target.value)}
                        placeholder="Titel des Abschnitts"
                        className={clsx('w-full px-3 py-2 border rounded text-sm mb-2', isDark ? 'bg-slate-900/70 border-slate-600 text-slate-100' : 'bg-white border-gray-300 text-gray-900')}
                      />
                      <textarea
                        value={section.content}
                        onChange={(e) => updateSection(index, 'content', e.target.value)}
                        placeholder="Inhalt (Markdown/Text; Platzhalter z.B. {{APP_NAME}}, {{LEGAL_PLATFORM_NAME}})"
                        rows={4}
                        className={clsx('w-full px-3 py-2 border rounded text-sm', isDark ? 'bg-slate-900/70 border-slate-600 text-slate-100' : 'bg-white border-gray-300 text-gray-900')}
                      />
                    </div>
                  ))
                )}
              </div>
            </div>
          </div>
          <div className={clsx('p-6 border-t flex justify-end gap-3', isDark ? 'border-slate-600' : 'border-gray-200')}>
            <Button type="button" variant="secondary" onClick={onClose} disabled={saving}>
              Abbrechen
            </Button>
            <Button type="submit" disabled={saving}>
              {saving ? 'Speichern…' : 'Neue Version anlegen'}
            </Button>
          </div>
        </form>
      </div>
    </div>
  );
}
