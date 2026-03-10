import { useState } from 'react';
import { Card } from '../../../components/ui/Card';
import { Badge } from '../../../components/ui/Badge';
import { Button } from '../../../components/ui/Button';
import type {
  TermsContentListItem,
  TermsContentFull,
  TermsSection,
  VersionChangesResult,
} from '../types';
import { DOCUMENT_TYPE_LABELS } from '../types';
import { getTermsContent } from '../api';
import { compareVersions } from '../utils';

interface TermsListProps {
  items: TermsContentListItem[];
  documentTypeFilter?: 'all' | 'terms' | 'privacy' | 'imprint';
  onClone: (item: TermsContentListItem) => void;
  onSetActive: (objectId: string) => void;
  settingActiveId: string | null;
  /** Optional: öffnet den Editor direkt auf einem bestimmten Abschnitt. */
  onEditSection?: (item: TermsContentListItem, section: TermsSection) => void;
}

function SectionBlock({
  section,
  index,
  onEdit,
}: {
  section: TermsSection;
  index: number;
  onEdit?: () => void;
}) {
  const [expanded, setExpanded] = useState(false);
  const previewLength = 200;
  const isLong = section.content.length > previewLength;
  const text = isLong && !expanded ? section.content.slice(0, previewLength) + '…' : section.content;

  return (
    <div className="border border-gray-200 rounded-lg p-3 bg-gray-50/50">
      <div className="flex items-center justify-between gap-2 mb-2">
        <span className="font-medium text-gray-800">
          <span className="text-gray-500 font-normal text-xs uppercase tracking-wide mr-1.5">
            Titel:
          </span>
          {section.title || `Abschnitt ${index + 1}`}
          {section.id && (
            <span className="text-gray-500 font-normal text-sm ml-2">({section.id})</span>
          )}
        </span>
        <div className="flex items-center gap-2">
          {onEdit && (
            <Button variant="secondary" size="sm" onClick={onEdit}>
              Bearbeiten
            </Button>
          )}
          {isLong && (
            <Button variant="secondary" size="sm" onClick={() => setExpanded((e) => !e)}>
              {expanded ? 'Weniger' : 'Mehr'}
            </Button>
          )}
        </div>
      </div>
      <div className="text-sm text-gray-700 whitespace-pre-wrap break-words max-h-[40vh] overflow-y-auto">
        {text}
      </div>
    </div>
  );
}

function filterSectionsBySearch(sections: TermsSection[], query: string): TermsSection[] {
  const q = query.trim().toLowerCase();
  if (!q) return sections;
  return sections.filter(
    (s) =>
      (s.title && s.title.toLowerCase().includes(q)) ||
      (s.content && s.content.toLowerCase().includes(q)) ||
      (s.id && s.id.toLowerCase().includes(q))
  );
}

export function TermsList({
  items,
  documentTypeFilter,
  onClone,
  onSetActive,
  settingActiveId,
  onEditSection,
}: TermsListProps) {
  const [expandedId, setExpandedId] = useState<string | null>(null);
  const [fullCache, setFullCache] = useState<Record<string, TermsContentFull>>({});
  const [loadingId, setLoadingId] = useState<string | null>(null);
  const [sectionSearch, setSectionSearch] = useState('');
  const [changesResult, setChangesResult] = useState<Record<string, VersionChangesResult>>({});
  const [loadingChangesId, setLoadingChangesId] = useState<string | null>(null);

  async function toggleSections(item: TermsContentListItem) {
    const id = item.objectId;
    if (expandedId === id) {
      setExpandedId(null);
      return;
    }
    if (fullCache[id]) {
      setExpandedId(id);
      return;
    }
    setLoadingId(id);
    try {
      const full = await getTermsContent(id);
      setFullCache((c) => ({ ...c, [id]: full }));
      setExpandedId(id);
    } catch {
      setExpandedId(null);
    } finally {
      setLoadingId(null);
    }
  }

  async function loadAndShowChanges(item: TermsContentListItem, currentIndex: number) {
    const previousItem = items[currentIndex + 1];
    if (!previousItem) return;
    const prevId = previousItem.objectId;
    let previousFull = fullCache[prevId];
    if (!previousFull) {
      setLoadingChangesId(item.objectId);
      try {
        previousFull = await getTermsContent(prevId);
        setFullCache((c) => ({ ...c, [prevId]: previousFull }));
      } catch {
        return;
      } finally {
        setLoadingChangesId(null);
      }
    }
    const currentFull = fullCache[item.objectId];
    if (!currentFull || !previousFull) return;
    const changes = compareVersions(previousFull, currentFull);
    setChangesResult((r) => ({
      ...r,
      [item.objectId]: {
        previousVersion: previousFull.version,
        previousEffectiveDate: previousFull.effectiveDate,
        changes,
      },
    }));
  }

  if (items.length === 0) {
    return (
      <Card className="p-12 text-center">
        <div className="text-gray-400 text-5xl mb-4">📄</div>
        <h3 className="text-lg font-medium text-gray-900">
          {documentTypeFilter && documentTypeFilter !== 'all'
            ? `Keine ${DOCUMENT_TYPE_LABELS[documentTypeFilter] ?? documentTypeFilter}-Versionen gefunden`
            : 'Keine Rechtstexte gefunden'}
        </h3>
        <p className="text-gray-500 mt-2">
          Legen Sie eine neue Version an (z. B. per "+ Neue Version (leer)" oder aus einer bestehenden
          Version klonen).
        </p>
      </Card>
    );
  }

  return (
    <div className="space-y-3">
      {items.map((item, currentIndex) => (
        <Card key={item.objectId} className="p-4 hover:shadow-md transition-shadow">
          <div className="flex items-start justify-between gap-4">
            <div className="flex-1 min-w-0">
              <div className="flex items-center gap-2 mb-1">
                <span className="font-medium text-gray-900">
                  {DOCUMENT_TYPE_LABELS[item.documentType] ?? item.documentType} · v{item.version}
                </span>
                <span className="text-sm text-gray-500">{item.language.toUpperCase()}</span>
                {item.isActive && (
                  <Badge variant="info" className="text-xs">
                    Aktiv
                  </Badge>
                )}
              </div>
              <div className="flex items-center gap-3 text-sm text-gray-500 flex-wrap">
                <span>
                  Gültig ab:{' '}
                  {item.effectiveDate
                    ? new Date(item.effectiveDate).toLocaleString('de-DE', {
                        dateStyle: 'short',
                        timeStyle: 'short',
                      })
                    : '–'}
                </span>
                {item.updatedAt && (
                  <>
                    <span>·</span>
                    <span title="Letzte Änderung dieser Version">
                      Aktualisiert:{' '}
                      {new Date(item.updatedAt).toLocaleString('de-DE', {
                        dateStyle: 'short',
                        timeStyle: 'short',
                      })}
                    </span>
                  </>
                )}
                <span>·</span>
                <span>
                  {item.sectionCount} Abschnitte
                  <button
                    type="button"
                    onClick={() => toggleSections(item)}
                    disabled={loadingId !== null && loadingId !== item.objectId}
                    className="ml-2 text-fin1-primary hover:underline font-medium disabled:opacity-50"
                  >
                    {loadingId === item.objectId
                      ? '… Laden'
                      : expandedId === item.objectId
                        ? '(einklappen)'
                        : '(Inhalt anzeigen)'}
                  </button>
                </span>
                {item.documentHash && (
                  <>
                    <span>·</span>
                    <span
                      className="font-mono text-xs truncate max-w-[120px]"
                      title={item.documentHash}
                    >
                      {item.documentHash.slice(0, 8)}…
                    </span>
                  </>
                )}
              </div>
            </div>
            <div className="flex gap-2 flex-shrink-0 flex-wrap">
              <Button
                variant="secondary"
                size="sm"
                onClick={() => toggleSections(item)}
                disabled={loadingId !== null && loadingId !== item.objectId}
              >
                {loadingId === item.objectId
                  ? 'Laden…'
                  : expandedId === item.objectId
                    ? 'Einklappen'
                    : 'Inhalt anzeigen'}
              </Button>
              <Button variant="secondary" size="sm" onClick={() => onClone(item)}>
                Klonen (neue Version)
              </Button>
              {!item.isActive && (
                <Button
                  size="sm"
                  disabled={settingActiveId !== null}
                  onClick={() => onSetActive(item.objectId)}
                >
                  {settingActiveId === item.objectId ? 'Aktivieren…' : 'Als aktiv setzen'}
                </Button>
              )}
            </div>
          </div>
          {expandedId === item.objectId && fullCache[item.objectId]?.sections && (() => {
            const sections = fullCache[item.objectId].sections;
            const filtered = filterSectionsBySearch(sections, sectionSearch);
            const hasPrevious = currentIndex + 1 < items.length;
            const result = changesResult[item.objectId];
            const loadingChanges = loadingChangesId === item.objectId;
            return (
              <div className="mt-4 pt-4 border-t border-gray-200 space-y-3">
                <div className="rounded-md bg-slate-50 border border-slate-200 px-3 py-2 text-sm">
                  <h4 className="font-semibold text-gray-800 mb-1">Änderungen zur Vorgängerversion</h4>
                  {!hasPrevious ? (
                    <p className="text-gray-500">Keine Vorgängerversion (erste Version).</p>
                  ) : result ? (
                    <div className="space-y-2">
                      <p className="text-gray-600">
                        Vergleich mit v{result.previousVersion}
                        {result.previousEffectiveDate &&
                          ` (gültig ab ${new Date(result.previousEffectiveDate).toLocaleDateString('de-DE')})`}
                        : {result.changes.length} Änderung(en).
                      </p>
                      <ul className="list-disc list-inside space-y-1 text-gray-700">
                        {result.changes.map((c, i) => (
                          <li key={i}>
                            <span className="font-medium">
                              {c.changeType === 'added' && '➕ Hinzugefügt: '}
                              {c.changeType === 'removed' && '➖ Entfernt: '}
                              {c.changeType === 'modified' && '✏️ Geändert: '}
                            </span>
                            {c.sectionTitle}
                            {c.sectionId && c.sectionId !== c.sectionTitle && (
                              <span className="text-gray-500 ml-1">({c.sectionId})</span>
                            )}
                            {c.description && (
                              <span className="block text-gray-500 text-xs mt-0.5 ml-4">{c.description}</span>
                            )}
                          </li>
                        ))}
                      </ul>
                    </div>
                  ) : (
                    <Button
                      variant="secondary"
                      size="sm"
                      onClick={() => loadAndShowChanges(item, currentIndex)}
                      disabled={loadingChanges}
                    >
                      {loadingChanges ? 'Lade…' : 'Änderungen anzeigen'}
                    </Button>
                  )}
                </div>
                <div className="rounded-md bg-amber-50 border border-amber-200 px-3 py-2 text-sm text-amber-800">
                  <strong>Titel und Inhalt bearbeiten:</strong> Nutzen Sie entweder{' '}
                  <strong>„Klonen (neue Version)“</strong> oder den{' '}
                  <strong>„Bearbeiten“‑Button</strong> direkt am Abschnitt. Im Editor hat jeder
                  Abschnitt ein Feld <strong>„Titel des Abschnitts“</strong> (z. B. „Wichtige
                  Hinweise“) und „Inhalt“. Nach dem Anpassen speichern Sie die neue Version und
                  setzen sie bei Bedarf auf „Als aktiv setzen“.
                </div>
                <div className="flex flex-col sm:flex-row sm:items-center gap-2">
                  <h4 className="text-sm font-semibold text-gray-700">Inhalt der Abschnitte</h4>
                  <div className="flex-1 flex items-center gap-2">
                    <input
                      type="search"
                      placeholder="Abschnitte durchsuchen (Titel, Inhalt, ID)…"
                      value={sectionSearch}
                      onChange={(e) => setSectionSearch(e.target.value)}
                      className="flex-1 min-w-0 rounded-md border border-gray-300 px-3 py-1.5 text-sm focus:border-fin1-primary focus:ring-1 focus:ring-fin1-primary"
                    />
                    {sectionSearch.trim() && (
                      <span className="text-sm text-gray-500 whitespace-nowrap">
                        {filtered.length} / {sections.length}
                      </span>
                    )}
                  </div>
                </div>
                <div className="space-y-3 max-h-[60vh] overflow-y-auto">
                  {filtered.length === 0 ? (
                    <p className="text-sm text-gray-500 py-4">
                      {sectionSearch.trim()
                        ? 'Kein Abschnitt enthält den Suchbegriff.'
                        : 'Keine Abschnitte.'}
                    </p>
                  ) : (
                    filtered.map((section, index) => (
                      <SectionBlock
                        key={section.id || index}
                        section={section}
                        index={index}
                        onEdit={
                          onEditSection ? () => onEditSection(item, section) : undefined
                        }
                      />
                    ))
                  )}
                </div>
              </div>
            );
          })()}
        </Card>
      ))}
    </div>
  );
}

