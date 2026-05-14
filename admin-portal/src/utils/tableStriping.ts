import clsx from 'clsx';

export type ListRowStripeOptions = {
  /** Default true. Set false for static config-style rows without hover affordance. */
  hover?: boolean;
  /** Merged last, e.g. `cursor-pointer` or `transition-colors`. */
  className?: string;
};

/**
 * Alternating row backgrounds aligned with ThemeContext (`dark` / light).
 * Not tied to Tailwind `dark:` — pass `isDark` from `useTheme()`.
 */
export function listRowStripeClasses(isDark: boolean, index: number, options?: ListRowStripeOptions): string {
  const hover = options?.hover !== false;
  return clsx(
    isDark
      ? index % 2 === 0
        ? 'bg-slate-900/30'
        : 'bg-slate-800/30'
      : index % 2 === 0
        ? 'bg-white'
        : 'bg-gray-50/60',
    hover && (isDark ? 'hover:bg-slate-800/60' : 'hover:bg-gray-50'),
    options?.className,
  );
}

/** Apply to `<thead>` (background + bottom border). */
export function tableTheadSurfaceClasses(isDark: boolean): string {
  return clsx('border-b', isDark ? 'bg-slate-800/50 border-slate-600' : 'bg-gray-50 border-gray-200');
}

/** Apply to `<tbody>` row dividers. */
export function tableBodyDivideClasses(isDark: boolean): string {
  return clsx('divide-y', isDark ? 'divide-slate-700' : 'divide-gray-100');
}

/** Typical `<th>` text color for admin tables. */
export function tableHeaderCellTextClasses(isDark: boolean): string {
  return isDark ? 'text-slate-400' : 'text-gray-500';
}

/** Primary text in `<tbody>` cells (titles, names). */
export function tableBodyCellPrimaryClasses(isDark: boolean): string {
  return isDark ? 'text-slate-100' : 'text-gray-900';
}

/** Secondary / muted text in `<tbody>` cells (timestamps, hints). */
export function tableBodyCellMutedClasses(isDark: boolean): string {
  return isDark ? 'text-slate-400' : 'text-gray-500';
}

/** Monospace hints in table cells (ids). */
export function tableBodyCellMonoHintClasses(isDark: boolean): string {
  return isDark ? 'text-slate-400' : 'text-gray-600';
}

export function emptyListPlaceholderClasses(isDark: boolean): string {
  return clsx(
    'p-6 text-center text-sm',
    isDark ? 'text-slate-400 bg-slate-900/30' : 'text-gray-500 bg-gray-50/60',
  );
}
