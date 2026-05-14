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
const TEXT_GRAY_700 = clsx('text-gray-700');
const TEXT_GRAY_800 = clsx('text-gray-800');
const TEXT_GRAY_300 = clsx('text-gray-300');

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

/** Stat card title (dark: slate-300, light: gray-500) — distinct from body muted */
export function adminStatTitle(isDark: boolean): string {
  return isDark ? 'text-slate-300' : TEXT_GRAY_500;
}

/** Secondary body / table cells (slate-300 / gray-600) */
export function adminSoft(isDark: boolean): string {
  return isDark ? 'text-slate-300' : TEXT_GRAY_600;
}

/** Form labels and UI chrome (slate-300 / gray-700) */
export function adminLabel(isDark: boolean): string {
  return isDark ? 'text-slate-300' : TEXT_GRAY_700;
}

/** Emphasized labels and section titles (slate-200 / gray-700) */
export function adminStrong(isDark: boolean): string {
  return isDark ? 'text-slate-200' : TEXT_GRAY_700;
}

/** Emphasized table / data text (slate-200 / gray-900) */
export function adminBodyStrong(isDark: boolean): string {
  return isDark ? 'text-slate-200' : TEXT_GRAY_900;
}

/** Subheads and dense UI (slate-200 / gray-800) */
export function adminEmphasisSoft(isDark: boolean): string {
  return isDark ? 'text-slate-200' : TEXT_GRAY_800;
}

/** Card / section titles on light gray-800 (slate-100 / gray-800) */
export function adminHeadline(isDark: boolean): string {
  return isDark ? 'text-slate-100' : TEXT_GRAY_800;
}

/** Strong values on softer light (slate-100 / gray-700) */
export function adminHeadlineAlt(isDark: boolean): string {
  return isDark ? 'text-slate-100' : TEXT_GRAY_700;
}

/** Row accent on light (slate-300 / gray-900) */
export function adminEmphasisOnLight(isDark: boolean): string {
  return isDark ? 'text-slate-300' : TEXT_GRAY_900;
}

/** Muted icon / checkbox chrome (slate-400 / gray-400) */
export function adminIconField(isDark: boolean): string {
  return isDark ? 'text-slate-400' : TEXT_GRAY_400;
}

/** Large empty-state glyphs (slate-600 / gray-300) */
export function adminEmptyIcon(isDark: boolean): string {
  return isDark ? 'text-slate-600' : TEXT_GRAY_300;
}

/** Delimiters and faint glyphs (slate-500 / gray-300) */
export function adminGlyphFaint(isDark: boolean): string {
  return isDark ? 'text-slate-500' : TEXT_GRAY_300;
}

/** Longer prose on tinted surfaces (slate-200 / gray-600) */
export function adminProse(isDark: boolean): string {
  return isDark ? 'text-slate-200' : TEXT_GRAY_600;
}

/** Both themes muted (slate-500 / gray-500) */
export function adminDualMuted(isDark: boolean): string {
  return isDark ? 'text-slate-500' : TEXT_GRAY_500;
}

/** Footer / legal line on white cards (slate-600 / gray-500) */
export function adminFootnote(isDark: boolean): string {
  return isDark ? 'text-slate-600' : TEXT_GRAY_500;
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
