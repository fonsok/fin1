import { describe, it, expect } from 'vitest';
import { compareVersions } from './utils';
import type { TermsContentFull } from './types';

function makeDoc(
  version: string,
  sections: Array<{ id: string; title: string; content: string; icon?: string }>
): TermsContentFull {
  return {
    objectId: `id-${version}`,
    version,
    language: 'de',
    documentType: 'terms',
    effectiveDate: null,
    isActive: false,
    documentHash: null,
    sectionCount: sections.length,
    createdAt: null,
    updatedAt: null,
    sections: sections.map((s) => ({
      id: s.id,
      title: s.title,
      content: s.content,
      icon: s.icon ?? 'doc.text',
    })),
  };
}

describe('compareVersions', () => {
  it('returns empty when both versions have identical sections', () => {
    const sections = [
      { id: 'a', title: 'Title A', content: 'Content A' },
      { id: 'b', title: 'Title B', content: 'Content B' },
    ];
    const oldDoc = makeDoc('1.0', sections);
    const newDoc = makeDoc('1.1', sections);
    const changes = compareVersions(oldDoc, newDoc);
    expect(changes).toHaveLength(0);
  });

  it('detects added sections', () => {
    const oldDoc = makeDoc('1.0', [{ id: 'a', title: 'A', content: 'A' }]);
    const newDoc = makeDoc('1.1', [
      { id: 'a', title: 'A', content: 'A' },
      { id: 'b', title: 'B', content: 'New section' },
    ]);
    const changes = compareVersions(oldDoc, newDoc);
    expect(changes).toHaveLength(1);
    expect(changes[0].changeType).toBe('added');
    expect(changes[0].sectionId).toBe('b');
    expect(changes[0].sectionTitle).toBe('B');
    expect(changes[0].description).toContain('New section');
  });

  it('detects removed sections', () => {
    const oldDoc = makeDoc('1.0', [
      { id: 'a', title: 'A', content: 'A' },
      { id: 'b', title: 'B', content: 'B' },
    ]);
    const newDoc = makeDoc('1.1', [{ id: 'a', title: 'A', content: 'A' }]);
    const changes = compareVersions(oldDoc, newDoc);
    expect(changes).toHaveLength(1);
    expect(changes[0].changeType).toBe('removed');
    expect(changes[0].sectionId).toBe('b');
  });

  it('detects modified sections (title or content change)', () => {
    const oldDoc = makeDoc('1.0', [{ id: 'a', title: 'Old Title', content: 'Old content' }]);
    const newDoc = makeDoc('1.1', [{ id: 'a', title: 'New Title', content: 'Old content' }]);
    const changes = compareVersions(oldDoc, newDoc);
    expect(changes).toHaveLength(1);
    expect(changes[0].changeType).toBe('modified');
    expect(changes[0].sectionId).toBe('a');
    expect(changes[0].description).toBe('Titel oder Inhalt geändert');
  });

  it('ignores whitespace-only differences', () => {
    const oldDoc = makeDoc('1.0', [{ id: 'a', title: 'Title', content: 'Line one\nLine two' }]);
    const newDoc = makeDoc('1.1', [{ id: 'a', title: '  Title  ', content: 'Line one  \n  Line two' }]);
    const changes = compareVersions(oldDoc, newDoc);
    expect(changes).toHaveLength(0);
  });

  it('returns added and removed when section set changes completely', () => {
    const oldDoc = makeDoc('1.0', [{ id: 'x', title: 'X', content: 'X' }]);
    const newDoc = makeDoc('1.1', [{ id: 'y', title: 'Y', content: 'Y' }]);
    const changes = compareVersions(oldDoc, newDoc);
    expect(changes).toHaveLength(2);
    const added = changes.find((c) => c.changeType === 'added');
    const removed = changes.find((c) => c.changeType === 'removed');
    expect(added?.sectionId).toBe('y');
    expect(removed?.sectionId).toBe('x');
  });
});
