import type { TermsContentFull, SectionChange } from './types';

/**
 * Vergleicht zwei Rechtstext-Versionen und liefert die Änderungen
 * (hinzugefügt/entfernt/geändert) für die Admin-Anzeige „Änderungen zur Vorgängerversion“.
 */
export function compareVersions(
  oldContent: TermsContentFull,
  newContent: TermsContentFull
): SectionChange[] {
  const changes: SectionChange[] = [];
  const oldById = new Map(oldContent.sections.map((s) => [s.id, s]));
  const newById = new Map(newContent.sections.map((s) => [s.id, s]));
  const normalize = (s: string) => s.replace(/\s+/g, ' ').trim();

  for (const section of newContent.sections) {
    const oldSection = oldById.get(section.id);
    if (!oldSection) {
      changes.push({
        changeType: 'added',
        sectionId: section.id,
        sectionTitle: section.title || section.id,
        description: section.content.slice(0, 80) + (section.content.length > 80 ? '…' : ''),
      });
    } else if (
      normalize(oldSection.title || '') !== normalize(section.title || '') ||
      normalize(oldSection.content || '') !== normalize(section.content || '')
    ) {
      changes.push({
        changeType: 'modified',
        sectionId: section.id,
        sectionTitle: section.title || section.id,
        description: 'Titel oder Inhalt geändert',
      });
    }
  }
  for (const section of oldContent.sections) {
    if (!newById.has(section.id)) {
      changes.push({
        changeType: 'removed',
        sectionId: section.id,
        sectionTitle: section.title || section.id,
      });
    }
  }
  return changes;
}
