import { useMemo } from 'react';
import type { TermsContentListItem } from '../types';

type ListViewFilter = 'all' | 'active_only' | 'last_10' | 'last_20';

export function useTermsDerivedList(items: TermsContentListItem[], listViewFilter: ListViewFilter) {
  const sortedItems = useMemo(() => {
    return [...items].sort((a, b) => {
      if (a.isActive !== b.isActive) return a.isActive ? -1 : 1;

      const aDate = a.effectiveDate ? Date.parse(a.effectiveDate) : 0;
      const bDate = b.effectiveDate ? Date.parse(b.effectiveDate) : 0;
      if (aDate !== bDate) return bDate - aDate;

      const aUpdated = a.updatedAt ? Date.parse(a.updatedAt) : 0;
      const bUpdated = b.updatedAt ? Date.parse(b.updatedAt) : 0;
      if (aUpdated !== bUpdated) return bUpdated - aUpdated;

      return a.version.localeCompare(b.version);
    });
  }, [items]);

  const displayedItems = useMemo(() => {
    if (listViewFilter === 'active_only') return sortedItems.filter((i) => i.isActive);
    if (listViewFilter === 'last_10') return sortedItems.slice(0, 10);
    if (listViewFilter === 'last_20') return sortedItems.slice(0, 20);
    return sortedItems;
  }, [sortedItems, listViewFilter]);

  const activeCount = useMemo(() => items.filter((i) => i.isActive).length, [items]);

  return { displayedItems, activeCount };
}
