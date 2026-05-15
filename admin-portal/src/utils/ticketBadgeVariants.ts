import clsx from 'clsx';

/** Shared chip shell — bg ≈ 20 %, border ≈ 70 % (Tailwind /20, /70). */
export const TICKET_CHIP_BASE =
  'inline-flex items-center px-2 py-0.5 rounded-full text-xs font-medium border';

/**
 * Status column — own palette (sky / orange / violet / emerald / slate).
 * Do not use getStatusVariant() from Badge.tsx (user/KYC mapping).
 */
const TICKET_STATUS_CHIP_DARK: Record<string, string> = {
  open: 'bg-sky-500/20 text-sky-100 border-sky-400/70',
  in_progress: 'bg-orange-500/20 text-orange-100 border-orange-400/70',
  waiting: 'bg-violet-500/20 text-violet-100 border-violet-400/70',
  resolved: 'bg-emerald-500/20 text-emerald-100 border-emerald-400/70',
  closed: 'bg-slate-500/20 text-slate-300 border-slate-400/70',
  archived: 'bg-slate-500/20 text-slate-300 border-slate-400/70',
};

const TICKET_STATUS_CHIP_LIGHT: Record<string, string> = {
  open: 'bg-sky-100 text-sky-800 border-sky-400/70',
  in_progress: 'bg-orange-100 text-orange-800 border-orange-400/70',
  waiting: 'bg-violet-100 text-violet-800 border-violet-400/70',
  resolved: 'bg-emerald-100 text-emerald-800 border-emerald-400/70',
  closed: 'bg-slate-100 text-slate-700 border-slate-400/70',
  archived: 'bg-slate-100 text-slate-700 border-slate-400/70',
};

/**
 * Priority column — own palette (red / orange / amber / cyan), distinct from status hues.
 */
const TICKET_PRIORITY_CHIP_DARK: Record<string, string> = {
  urgent: 'bg-red-500/20 text-red-100 border-red-400/70',
  high: 'bg-orange-500/20 text-orange-100 border-orange-400/70',
  medium: 'bg-amber-500/20 text-amber-100 border-amber-400/70',
  low: 'bg-cyan-500/20 text-cyan-100 border-cyan-400/70',
};

const TICKET_PRIORITY_CHIP_LIGHT: Record<string, string> = {
  urgent: 'bg-red-100 text-red-800 border-red-400/70',
  high: 'bg-orange-100 text-orange-800 border-orange-400/70',
  medium: 'bg-amber-100 text-amber-800 border-amber-400/70',
  low: 'bg-cyan-100 text-cyan-800 border-cyan-400/70',
};

const STATUS_CHIP_FALLBACK_DARK = 'bg-slate-500/20 text-slate-300 border-slate-400/70';
const STATUS_CHIP_FALLBACK_LIGHT = 'bg-slate-100 text-slate-700 border-slate-400/70';
const PRIORITY_CHIP_FALLBACK_DARK = 'bg-slate-500/20 text-slate-300 border-slate-400/70';
const PRIORITY_CHIP_FALLBACK_LIGHT = 'bg-slate-100 text-slate-700 border-slate-400/70';

function normalizeKey(value: string): string {
  return value?.toLowerCase().trim() || '';
}

export function ticketStatusChipClasses(status: string, isDark: boolean): string {
  const key = normalizeKey(status);
  const tone = isDark ? TICKET_STATUS_CHIP_DARK[key] : TICKET_STATUS_CHIP_LIGHT[key];
  const fallback = isDark ? STATUS_CHIP_FALLBACK_DARK : STATUS_CHIP_FALLBACK_LIGHT;
  return clsx(TICKET_CHIP_BASE, tone ?? fallback);
}

export function ticketPriorityChipClasses(priority: string, isDark: boolean): string {
  const key = normalizeKey(priority);
  const tone = isDark ? TICKET_PRIORITY_CHIP_DARK[key] : TICKET_PRIORITY_CHIP_LIGHT[key];
  const fallback = isDark ? PRIORITY_CHIP_FALLBACK_DARK : PRIORITY_CHIP_FALLBACK_LIGHT;
  return clsx(TICKET_CHIP_BASE, tone ?? fallback);
}

/** @deprecated Use ticketStatusChipClasses + TicketStatusBadge */
export type TicketBadgeVariant = 'success' | 'warning' | 'danger' | 'info' | 'neutral';

/** @deprecated Use ticketStatusChipClasses + TicketStatusBadge */
export function getTicketStatusBadgeVariant(status: string): TicketBadgeVariant {
  switch (normalizeKey(status)) {
    case 'open':
      return 'info';
    case 'in_progress':
      return 'warning';
    case 'resolved':
      return 'success';
    default:
      return 'neutral';
  }
}

/** @deprecated Use ticketPriorityChipClasses + TicketPriorityBadge */
export function getTicketPriorityBadgeVariant(priority: string): TicketBadgeVariant {
  switch (normalizeKey(priority)) {
    case 'urgent':
      return 'danger';
    case 'high':
    case 'medium':
      return 'warning';
    case 'low':
      return 'info';
    default:
      return 'neutral';
  }
}
