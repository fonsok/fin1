import clsx from 'clsx';
import {
  adminEmptyListPlaceholderSurface,
  adminListRowHoverLight,
  adminListRowStripeLightOdd,
  adminMonoHint,
  adminMuted,
  adminPrimary,
  adminTableBodyDivide,
  adminTableTheadSurface,
} from './adminThemeClasses';

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
        : adminListRowStripeLightOdd(),
    hover && (isDark ? 'hover:bg-slate-800/60' : adminListRowHoverLight()),
    options?.className,
  );
}

/** Apply to `<thead>` (background + bottom border). */
export function tableTheadSurfaceClasses(isDark: boolean): string {
  return adminTableTheadSurface(isDark);
}

/** Apply to `<tbody>` row dividers. */
export function tableBodyDivideClasses(isDark: boolean): string {
  return adminTableBodyDivide(isDark);
}

/** Typical `<th>` text color for admin tables. */
export function tableHeaderCellTextClasses(isDark: boolean): string {
  return adminMuted(isDark);
}

/** Primary text in `<tbody>` cells (titles, names). */
export function tableBodyCellPrimaryClasses(isDark: boolean): string {
  return adminPrimary(isDark);
}

/** Secondary / muted text in `<tbody>` cells (timestamps, hints). */
export function tableBodyCellMutedClasses(isDark: boolean): string {
  return adminMuted(isDark);
}

/** Monospace hints in table cells (ids). */
export function tableBodyCellMonoHintClasses(isDark: boolean): string {
  return adminMonoHint(isDark);
}

export function emptyListPlaceholderClasses(isDark: boolean): string {
  return clsx('p-6 text-center text-sm', adminEmptyListPlaceholderSurface(isDark));
}
