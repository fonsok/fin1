import { describe, expect, it } from 'vitest';
import { compareTextDe, sortByDisplayNameDe, sortByTitleDe } from './templateDisplayOrder';

describe('templateDisplayOrder', () => {
  it('sortByTitleDe orders with German locale', () => {
    const items = [{ title: 'Zebra', id: '1' }, { title: 'Äpfel', id: '2' }, { title: 'banane', id: '3' }];
    const sorted = sortByTitleDe(items);
    expect(sorted.map((t) => t.title)).toEqual(['Äpfel', 'banane', 'Zebra']);
  });

  it('sortByDisplayNameDe sorts email-style rows', () => {
    const rows = [{ displayName: 'Beta', id: 'a' }, { displayName: 'Alpha', id: 'b' }];
    expect(sortByDisplayNameDe(rows).map((r) => r.displayName)).toEqual(['Alpha', 'Beta']);
  });

  it('compareTextDe is case-insensitive (base sensitivity)', () => {
    expect(compareTextDe('foo', 'FOO')).toBe(0);
  });
});
