import clsx from 'clsx';

/** Standard portal chip variants (SSOT for Badge + inline chips). */
export type ChipVariant = 'success' | 'warning' | 'danger' | 'info' | 'neutral';

/** Extended accents for roles, template shortcuts, icon wells. */
export type ChipAccent =
  | 'emerald'
  | 'amber'
  | 'orange'
  | 'cyan'
  | 'sky'
  | 'blue'
  | 'indigo'
  | 'violet'
  | 'purple'
  | 'rose'
  | 'red'
  | 'slate';

export const CHIP_BASE =
  'inline-flex items-center font-medium rounded-full border';

export const CHIP_SIZE_SM = 'px-2 py-0.5 text-xs';
export const CHIP_SIZE_MD = 'px-2.5 py-1 text-sm';

const CHIP_LIGHT: Record<ChipVariant, string> = {
  success: 'bg-green-100 text-green-800 border-green-400/70',
  warning: 'bg-amber-100 text-amber-800 border-amber-400/70',
  danger: 'bg-red-100 text-red-800 border-red-400/70',
  info: 'bg-blue-100 text-blue-800 border-blue-400/70',
  neutral: 'bg-gray-100 text-gray-800 border-gray-400/70',
};

const CHIP_DARK: Record<ChipVariant, string> = {
  success: 'bg-emerald-500/20 !text-emerald-100 border-emerald-400/70',
  warning: 'bg-amber-500/20 !text-amber-100 border-amber-400/70',
  danger: 'bg-red-500/20 !text-red-100 border-red-400/70',
  info: 'bg-blue-500/20 !text-blue-100 border-blue-400/70',
  neutral: 'bg-slate-500/20 !text-slate-200 border-slate-400/70',
};

const CHIP_ACCENT_LIGHT: Record<ChipAccent, string> = {
  emerald: 'bg-emerald-100 text-emerald-800 border-emerald-400/70',
  amber: 'bg-amber-100 text-amber-800 border-amber-400/70',
  orange: 'bg-orange-100 text-orange-800 border-orange-400/70',
  cyan: 'bg-cyan-100 text-cyan-800 border-cyan-400/70',
  sky: 'bg-sky-100 text-sky-800 border-sky-400/70',
  blue: 'bg-blue-100 text-blue-800 border-blue-400/70',
  indigo: 'bg-indigo-100 text-indigo-800 border-indigo-400/70',
  violet: 'bg-violet-100 text-violet-800 border-violet-400/70',
  purple: 'bg-purple-100 text-purple-800 border-purple-400/70',
  rose: 'bg-rose-100 text-rose-800 border-rose-400/70',
  red: 'bg-red-100 text-red-800 border-red-400/70',
  slate: 'bg-gray-100 text-gray-700 border-gray-400/70',
};

const CHIP_ACCENT_DARK: Record<ChipAccent, string> = {
  emerald: 'bg-emerald-500/20 !text-emerald-100 border-emerald-400/70',
  amber: 'bg-amber-500/20 !text-amber-100 border-amber-400/70',
  orange: 'bg-orange-500/20 !text-orange-100 border-orange-400/70',
  cyan: 'bg-cyan-500/20 !text-cyan-100 border-cyan-400/70',
  sky: 'bg-sky-500/20 !text-sky-100 border-sky-400/70',
  blue: 'bg-blue-500/20 !text-blue-100 border-blue-400/70',
  indigo: 'bg-indigo-500/20 !text-indigo-100 border-indigo-400/70',
  violet: 'bg-violet-500/20 !text-violet-100 border-violet-400/70',
  purple: 'bg-purple-500/20 !text-purple-100 border-purple-400/70',
  rose: 'bg-rose-500/20 !text-rose-100 border-rose-400/70',
  red: 'bg-red-500/20 !text-red-100 border-red-400/70',
  slate: 'bg-slate-500/20 !text-slate-200 border-slate-400/70',
};

/** Panel shell (e.g. trend cards) — same palette, larger surface. */
const PANEL_ACCENT_DARK: Record<ChipVariant, string> = {
  success: 'bg-emerald-500/15 border-emerald-500/50 text-emerald-100',
  warning: 'bg-orange-500/15 border-orange-500/50 text-orange-100',
  danger: 'bg-red-500/15 border-red-500/50 text-red-100',
  info: 'bg-blue-500/15 border-blue-500/50 text-blue-100',
  neutral: 'bg-slate-500/15 border-slate-500/50 text-slate-200',
};

const PANEL_ACCENT_LIGHT: Record<ChipVariant, string> = {
  success: 'bg-green-50 border-green-300 text-green-900',
  warning: 'bg-orange-50 border-orange-300 text-orange-900',
  danger: 'bg-red-50 border-red-300 text-red-900',
  info: 'bg-blue-50 border-blue-300 text-blue-900',
  neutral: 'bg-gray-50 border-gray-300 text-gray-900',
};

const ICON_WELL_ACCENT_DARK: Record<'blue' | 'green' | 'amber' | 'red', string> = {
  blue: 'bg-blue-500/20 text-blue-100 border border-blue-400/70',
  green: 'bg-emerald-500/20 text-emerald-100 border border-emerald-400/70',
  amber: 'bg-amber-500/20 text-amber-100 border border-amber-400/70',
  red: 'bg-red-500/20 text-red-100 border border-red-400/70',
};

const ICON_WELL_ACCENT_LIGHT: Record<'blue' | 'green' | 'amber' | 'red', string> = {
  blue: 'bg-blue-100 text-blue-800 border border-blue-400/70',
  green: 'bg-green-100 text-green-800 border border-green-400/70',
  amber: 'bg-amber-100 text-amber-800 border border-amber-400/70',
  red: 'bg-red-100 text-red-800 border border-red-400/70',
};

export function chipVariantClasses(
  variant: ChipVariant,
  isDark: boolean,
  size: 'sm' | 'md' = 'sm',
): string {
  return clsx(
    CHIP_BASE,
    size === 'sm' ? CHIP_SIZE_SM : CHIP_SIZE_MD,
    isDark ? CHIP_DARK[variant] : CHIP_LIGHT[variant],
  );
}

export function chipAccentClasses(accent: ChipAccent, isDark: boolean): string {
  return clsx(CHIP_BASE, CHIP_SIZE_SM, isDark ? CHIP_ACCENT_DARK[accent] : CHIP_ACCENT_LIGHT[accent]);
}

export function severityToChipVariant(severity: string): ChipVariant {
  switch (severity?.toLowerCase()) {
    case 'critical':
    case 'high':
      return 'danger';
    case 'warning':
    case 'medium':
      return 'warning';
    case 'info':
    case 'low':
      return 'info';
    default:
      return 'neutral';
  }
}

export function severityPanelClasses(severity: string, isDark: boolean): string {
  const variant = severityToChipVariant(severity);
  return clsx(
    'border-2 rounded-xl',
    isDark ? PANEL_ACCENT_DARK[variant] : PANEL_ACCENT_LIGHT[variant],
  );
}

export function dashboardIconWellClasses(
  color: 'blue' | 'green' | 'amber' | 'red',
  isDark: boolean,
): string {
  return clsx('p-3 rounded-lg border', isDark ? ICON_WELL_ACCENT_DARK[color] : ICON_WELL_ACCENT_LIGHT[color]);
}

export function severityIconWellClasses(severity: string, isDark: boolean): string {
  const variant = severityToChipVariant(severity);
  const color: 'blue' | 'green' | 'amber' | 'red' =
    variant === 'danger' ? 'red' : variant === 'warning' ? 'amber' : 'blue';
  return clsx('p-2 rounded-lg', dashboardIconWellClasses(color, isDark));
}

/** CSR template shortcut chips — maps intent → accent. */
export function templateShortcutChipClasses(shortcut: string, isDark: boolean): string {
  const key = (shortcut || '').toLowerCase().replace(/^\//, '');

  if (key.includes('close') || key.includes('resolved') || key.includes('done')) {
    return chipAccentClasses('emerald', isDark);
  }
  if (key === 'hi' || key.includes('high') || key.includes('prio1') || key.includes('p1')) {
    return chipAccentClasses('amber', isDark);
  }
  if (key.includes('med') || key.includes('medium') || key.includes('prio2') || key.includes('p2')) {
    return chipAccentClasses('orange', isDark);
  }
  if (key.includes('low') || key.includes('lo') || key.includes('prio3') || key.includes('p3')) {
    return chipAccentClasses('cyan', isDark);
  }
  if (key.includes('formal') || key.includes('official')) {
    return chipAccentClasses('indigo', isDark);
  }
  if (key.includes('urgent') || key.includes('escalate') || key.includes('warn')) {
    return chipAccentClasses('rose', isDark);
  }
  if (key.includes('friendly') || key.includes('greet')) {
    return chipAccentClasses('sky', isDark);
  }

  return chipVariantClasses('neutral', isDark);
}

export function csrRoleAccentClasses(csrSubRole: string | undefined, isDark: boolean): string {
  switch ((csrSubRole || '').toLowerCase().replace(/_/g, '')) {
    case 'level1':
      return chipAccentClasses('blue', isDark);
    case 'level2':
      return chipAccentClasses('emerald', isDark);
    case 'fraudanalyst':
    case 'fraud':
      return chipAccentClasses('red', isDark);
    case 'complianceofficer':
    case 'compliance':
      return chipAccentClasses('purple', isDark);
    case 'techsupport':
    case 'tech':
      return chipAccentClasses('amber', isDark);
    case 'teamlead':
    case 'lead':
      return chipAccentClasses('indigo', isDark);
    default:
      return chipVariantClasses('neutral', isDark);
  }
}
