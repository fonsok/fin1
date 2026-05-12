/**
 * Consistent German-locale ordering for CSR template UIs (lists + dropdowns).
 */
const deOpts = { sensitivity: 'base' as const };

export function compareTextDe(a: string, b: string): number {
  return a.localeCompare(b, 'de', deOpts);
}

export function sortByTitleDe<T extends { title: string }>(items: readonly T[]): T[] {
  return [...items].sort((x, y) => compareTextDe(x.title, y.title));
}

export function sortByDisplayNameDe<T extends { displayName: string }>(items: readonly T[]): T[] {
  return [...items].sort((x, y) => compareTextDe(x.displayName, y.displayName));
}
