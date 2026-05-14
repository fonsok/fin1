import clsx from 'clsx';

/**
 * Central light-mode Tailwind grays wrapped once with `clsx`:
 * satisfies `fin1/no-tailwind-gray-outside-clsx`, dedupes strings for gzip,
 * and keeps dark/light typography picks in one place.
 */

const TEXT_GRAY_500 = clsx('text-gray-500');
const TEXT_GRAY_900 = clsx('text-gray-900');
const TEXT_GRAY_600 = clsx('text-gray-600');
const TEXT_GRAY_400 = clsx('text-gray-400');

const BG_GRAY_50_60 = clsx('bg-gray-50/60');
const HOVER_BG_GRAY_50 = clsx('hover:bg-gray-50');
const THEAD_SURFACE_LIGHT = clsx('bg-gray-50 border-gray-200');
const DIVIDE_GRAY_100 = clsx('divide-gray-100');
const EMPTY_STATE_LIGHT = clsx('text-gray-500 bg-gray-50/60');

/** Muted body / table header / secondary labels */
export function adminMuted(isDark: boolean): string {
  return isDark ? 'text-slate-400' : TEXT_GRAY_500;
}

/** Primary titles and strong table cell text */
export function adminPrimary(isDark: boolean): string {
  return isDark ? 'text-slate-100' : TEXT_GRAY_900;
}

/** IDs / mono hints (slightly stronger than muted in light mode) */
export function adminMonoHint(isDark: boolean): string {
  return isDark ? 'text-slate-400' : TEXT_GRAY_600;
}

/** Tertiary line under metrics (e.g. stat subtitles) */
export function adminCaption(isDark: boolean): string {
  return isDark ? 'text-slate-500' : TEXT_GRAY_400;
}

/** Stat / KPI card title row (slightly brighter than body muted in dark mode) */
export function adminStatTitle(isDark: boolean): string {
  return isDark ? 'text-slate-300' : TEXT_GRAY_500;
}

export function adminTableTheadSurface(isDark: boolean): string {
  return clsx('border-b', isDark ? 'bg-slate-800/50 border-slate-600' : THEAD_SURFACE_LIGHT);
}

export function adminTableBodyDivide(isDark: boolean): string {
  return clsx('divide-y', isDark ? 'divide-slate-700' : DIVIDE_GRAY_100);
}

export function adminListRowStripeLightOdd(): string {
  return BG_GRAY_50_60;
}

export function adminListRowHoverLight(): string {
  return HOVER_BG_GRAY_50;
}

export function adminEmptyListPlaceholderSurface(isDark: boolean): string {
  return isDark ? 'text-slate-400 bg-slate-900/30' : EMPTY_STATE_LIGHT;
}
