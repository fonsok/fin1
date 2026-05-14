import { useState } from 'react';
import clsx from 'clsx';
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
import { useTheme } from '../../../context/ThemeContext';
import type { LegalBrandingPreviewValues } from '../utils/hydrateTermsPreview';
import { hydrateTermsPreviewText } from '../utils/hydrateTermsPreview';

import { adminCaption, adminMuted, adminPrimary } from '../../../utils/adminThemeClasses';
interface TermsListProps {
  items: TermsContentListItem[];
  documentTypeFilter?: 'all' | 'terms' | 'privacy' | 'imprint';
  onClone: (item: TermsContentListItem) => void;
  onSetActive: (objectId: string) => void;
  settingActiveId: string | null;
  /** Optional: öffnet den Editor direkt auf einem bestimmten Abschnitt. */
  onEditSection?: (item: TermsContentListItem, section: TermsSection) => void;
  /** Live preview values for common legal placeholders (does not change persisted content). */
  legalPreview?: LegalBrandingPreviewValues | null;
}

function SectionBlock({
  section,
  index,
  onEdit,
  legalPreview,
}: {
  section: TermsSection;
  index: number;
  onEdit?: () => void;
  legalPreview?: LegalBrandingPreviewValues | null;
}) {
  const { theme } = useTheme();
  const isDark = theme === 'dark';
  const [expanded, setExpanded] = useState(false);
  const previewLength = 200;
  const hydratedTitle = hydrateTermsPreviewText(section.title || '', legalPreview);
  const hydratedContent = hydrateTermsPreviewText(section.content || '', legalPreview);
  const isHydrated =
    hydratedTitle !== (section.title || '') || hydratedContent !== (section.content || '');
  const isLong = hydratedContent.length > previewLength;
  const text = isLong && !expanded ? hydratedContent.slice(0, previewLength) + '…' : hydratedContent;

  return (
    <div
      className={clsx(
        'border rounded-lg p-3',
        isDark ? 'border-slate-600 bg-slate-700/60' : 'border-gray-200 bg-gray-50/50',
      )}
    >
      <div
        className={clsx(
          'flex items-center justify-between gap-2 mb-2 rounded-md px-2.5 py-2 border',
          isDark ? 'bg-slate-800/80 border-slate-600' : 'bg-slate-100 border-slate-200',
        )}
      >
        <span
          className={clsx(
            'font-medium',
            isDark ? 'text-slate-100' : 'text-gray-800',
          )}
        >
          <span
            className={clsx(
              'font-normal text-xs uppercase tracking-wide mr-1.5',
              isDark ? 'text-slate-300' : 'text-gray-500',
            )}
          >
            Titel:
          </span>
          {hydratedTitle || `Abschnitt ${index + 1}`}
          {section.id && (
            <span
              className={clsx(
                'font-normal text-sm ml-2',
                isDark ? 'text-slate-300' : 'text-gray-500',
              )}
            >
              ({section.id})
            </span>
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
      <div
        className={clsx(
          'text-sm whitespace-pre-wrap break-words max-h-[40vh] overflow-y-auto',
          isDark ? 'text-slate-100' : 'text-gray-700',
        )}
      >
        {isHydrated && (
          <div
            className={clsx(
              'mb-2 rounded-md border px-2 py-1 text-xs',
              isDark ? 'border-slate-600 bg-slate-900/40 text-slate-300' : 'border-slate-200 bg-white text-slate-600',
            )}
          >
            Vorschau: Platzhalter (z. B. <span className="font-mono">{'{{APP_NAME}}'}</span>) werden hier mit den
            aktuellen Konfigurationswerten ersetzt. Gespeicherte Texte bleiben unverändert, bis Sie eine neue Version
            anlegen.
          </div>
        )}
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
  legalPreview,
}: TermsListProps) {
  const { theme } = useTheme();
  const isDark = theme === 'dark';
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
        <div className={clsx('text-5xl mb-4', adminCaption(isDark))}>📄</div>
        <h3 className={clsx('text-lg font-medium', adminPrimary(isDark))}>
          {documentTypeFilter && documentTypeFilter !== 'all'
            ? `Keine ${DOCUMENT_TYPE_LABELS[documentTypeFilter] ?? documentTypeFilter}-Versionen gefunden`
            : 'Keine Rechtstexte gefunden'}
        </h3>
        <p className={clsx('mt-2', adminMuted(isDark))}>
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
                <span className={clsx('font-medium', adminPrimary(isDark))}>
                  {DOCUMENT_TYPE_LABELS[item.documentType] ?? item.documentType} · v{item.version}
                </span>
                <span className={clsx('text-sm', adminMuted(isDark))}>
                  {item.language.toUpperCase()}
                </span>
                {item.isActive && (
                  <Badge variant="info" className="text-xs">
                    Aktiv
                  </Badge>
                )}
              </div>
              <div
                className={clsx(
                  'flex items-center gap-3 text-sm flex-wrap',
                  adminMuted(isDark),
                )}
              >
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
              <div
                className={clsx(
                  'mt-4 pt-4 border-t space-y-3',
                  isDark ? 'border-slate-600' : 'border-gray-200',
                )}
              >
                <div
                  className={clsx(
                    'rounded-md border px-3 py-2 text-sm',
                    isDark ? 'bg-slate-800/60 border-slate-600' : 'bg-slate-50 border-slate-200',
                  )}
                >
                  <h4 className={clsx('font-semibold mb-1', isDark ? 'text-slate-100' : 'text-gray-800')}>
                    Änderungen zur Vorgängerversion
                  </h4>
                  {!hasPrevious ? (
                    <p className={clsx(adminMuted(isDark))}>
                      Keine Vorgängerversion (erste Version).
                    </p>
                  ) : result ? (
                    <div className="space-y-2">
                      <p className={clsx(isDark ? 'text-slate-300' : 'text-gray-600')}>
                        Vergleich mit v{result.previousVersion}
                        {result.previousEffectiveDate &&
                          ` (gültig ab ${new Date(result.previousEffectiveDate).toLocaleDateString('de-DE')})`}
                        : {result.changes.length} Änderung(en).
                      </p>
                      <ul className={clsx('list-disc list-inside space-y-1', isDark ? 'text-slate-200' : 'text-gray-700')}>
                        {result.changes.map((c, i) => (
                          <li key={i}>
                            <span className="font-medium">
                              {c.changeType === 'added' && '➕ Hinzugefügt: '}
                              {c.changeType === 'removed' && '➖ Entfernt: '}
                              {c.changeType === 'modified' && '✏️ Geändert: '}
                            </span>
                            {c.sectionTitle}
                            {c.sectionId && c.sectionId !== c.sectionTitle && (
                              <span className={clsx('ml-1', adminMuted(isDark))}>
                                ({c.sectionId})
                              </span>
                            )}
                            {c.description && (
                              <span className={clsx('block text-xs mt-0.5 ml-4', adminMuted(isDark))}>
                                {c.description}
                              </span>
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
                <div
                  className={clsx(
                    'rounded-md border px-3 py-2 text-sm',
                    isDark ? 'bg-amber-950/30 border-amber-700 text-amber-200' : 'bg-amber-50 border-amber-200 text-amber-800',
                  )}
                >
                  <strong>Titel und Inhalt bearbeiten:</strong> Nutzen Sie entweder{' '}
                  <strong>„Klonen (neue Version)“</strong> oder den{' '}
                  <strong>„Bearbeiten“-Button</strong> direkt am Abschnitt. Im Editor hat jeder
                  Abschnitt ein Feld <strong>„Titel des Abschnitts“</strong> (z. B. „Wichtige
                  Hinweise“) und „Inhalt“. Nach dem Anpassen speichern Sie die neue Version und
                  setzen sie bei Bedarf auf „Als aktiv setzen“.
                </div>
                <div className="flex flex-col sm:flex-row sm:items-center gap-2">
                  <h4 className={clsx('text-sm font-semibold', isDark ? 'text-slate-200' : 'text-gray-700')}>
                    Inhalt der Abschnitte
                  </h4>
                  <div className="flex-1 flex items-center gap-2">
                    <input
                      type="search"
                      placeholder="Abschnitte durchsuchen (Titel, Inhalt, ID)…"
                      value={sectionSearch}
                      onChange={(e) => setSectionSearch(e.target.value)}
                      className={clsx(
                        'flex-1 min-w-0 rounded-md border px-3 py-1.5 text-sm focus:border-fin1-primary focus:ring-1 focus:ring-fin1-primary',
                        isDark ? 'border-slate-600 bg-slate-900/60 text-slate-100 placeholder:text-slate-400' : 'border-gray-300 bg-white text-gray-900 placeholder:text-gray-400',
                      )}
                    />
                    {sectionSearch.trim() && (
                      <span className={clsx('text-sm whitespace-nowrap', adminMuted(isDark))}>
                        {filtered.length} / {sections.length}
                      </span>
                    )}
                  </div>
                </div>
                <div className="space-y-3 max-h-[60vh] overflow-y-auto">
                  {filtered.length === 0 ? (
                    <p className={clsx('text-sm py-4', adminMuted(isDark))}>
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
                        legalPreview={legalPreview}
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

