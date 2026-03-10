import { useState, useMemo } from 'react';
import { Button } from '../../../components/ui/Button';
import type { TermsContentFull, TermsSection, CreateTermsContentRequest } from '../types';
import { createTermsContent } from '../api';

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
      <div className="bg-white rounded-xl shadow-xl max-w-4xl w-full max-h-[90vh] overflow-y-auto">
        <form onSubmit={handleSubmit}>
          <div className="p-6 border-b border-gray-200">
            <h2 className="text-xl font-bold text-gray-900">
              {cloneFrom ? 'Neue Version aus Klon' : 'Neue Rechtstext-Version'}
            </h2>
            <p className="text-sm text-gray-500 mt-1">
              Platzhalter wie {`{{LEGAL_PLATFORM_NAME}}`} werden serverseitig ersetzt. Version wird zunächst inaktiv angelegt; danach „Als aktiv setzen“ nutzen.
            </p>
          </div>
          <div className="p-6 space-y-4">
            {error && (
              <div className="bg-red-50 text-red-600 p-3 rounded-lg text-sm">{error}</div>
            )}
            <div className="grid grid-cols-2 gap-4">
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">Version *</label>
                <input
                  type="text"
                  value={version}
                  onChange={(e) => setVersion(e.target.value)}
                  placeholder="z.B. 1.1"
                  className="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-fin1-primary focus:border-transparent"
                  required
                />
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">Gültig ab *</label>
                <input
                  type="date"
                  value={effectiveDate}
                  onChange={(e) => setEffectiveDate(e.target.value)}
                  className="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-fin1-primary focus:border-transparent"
                  required
                />
              </div>
            </div>
            <div className="grid grid-cols-2 gap-4">
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">Sprache</label>
                <select
                  value={language}
                  onChange={(e) => setLanguage(e.target.value)}
                  className="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-fin1-primary focus:border-transparent"
                >
                  <option value="de">Deutsch</option>
                  <option value="en">English</option>
                </select>
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">Dokumenttyp</label>
                <select
                  value={documentType}
                  onChange={(e) => setDocumentType(e.target.value)}
                  className="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-fin1-primary focus:border-transparent"
                >
                  {DOCUMENT_TYPES.map((opt) => (
                    <option key={opt.value} value={opt.value}>{opt.label}</option>
                  ))}
                </select>
              </div>
            </div>

            <div>
              <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-2 mb-2">
                <label className="block text-sm font-medium text-gray-700">Abschnitte *</label>
                <div className="flex items-center gap-2 flex-1 sm:max-w-md">
                  <input
                    type="search"
                    placeholder="Abschnitte durchsuchen (Titel, Inhalt, ID)…"
                    value={sectionSearch}
                    onChange={(e) => setSectionSearch(e.target.value)}
                    className="flex-1 min-w-0 rounded-md border border-gray-300 px-3 py-1.5 text-sm focus:border-fin1-primary focus:ring-1 focus:ring-fin1-primary"
                  />
                  {sectionSearch.trim() && (
                    <span className="text-sm text-gray-500 whitespace-nowrap">
                      {filteredSectionsForDisplay.length} / {sections.length}
                    </span>
                  )}
                </div>
                <Button type="button" variant="secondary" size="sm" onClick={addSection}>
                  + Abschnitt
                </Button>
              </div>
              <div className="space-y-4 border border-gray-200 rounded-lg p-4 max-h-[40vh] overflow-y-auto">
                {filteredSectionsForDisplay.length === 0 ? (
                  <p className="text-sm text-gray-500 py-4">
                    {sectionSearch.trim()
                      ? 'Kein Abschnitt enthält den Suchbegriff.'
                      : 'Keine Abschnitte.'}
                  </p>
                ) : (
                  filteredSectionsForDisplay.map(({ section, index }) => (
                    <div key={index} className="border border-gray-100 rounded p-3 bg-gray-50/50">
                      <div className="flex justify-between items-center mb-2">
                        <span className="text-sm font-medium text-gray-600">Abschnitt {index + 1}</span>
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
                          className="px-3 py-1.5 border border-gray-300 rounded text-sm"
                        />
                        <input
                          type="text"
                          value={section.icon}
                          onChange={(e) => updateSection(index, 'icon', e.target.value)}
                          placeholder="Icon (z.B. document-text)"
                          className="px-3 py-1.5 border border-gray-300 rounded text-sm"
                        />
                      </div>
                      <input
                        type="text"
                        value={section.title}
                        onChange={(e) => updateSection(index, 'title', e.target.value)}
                        placeholder="Titel des Abschnitts"
                        className="w-full px-3 py-2 border border-gray-300 rounded text-sm mb-2"
                      />
                      <textarea
                        value={section.content}
                        onChange={(e) => updateSection(index, 'content', e.target.value)}
                        placeholder="Inhalt (Markdown/Text; Platzhalter z.B. {{LEGAL_PLATFORM_NAME}})"
                        rows={4}
                        className="w-full px-3 py-2 border border-gray-300 rounded text-sm"
                      />
                    </div>
                  ))
                )}
              </div>
            </div>
          </div>
          <div className="p-6 border-t border-gray-200 flex justify-end gap-3">
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
