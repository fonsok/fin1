import clsx from 'clsx';
import { CHIP_BASE, CHIP_SIZE_SM } from './chipVariants';

export const AUDIT_LOG_CHIP_BASE = clsx(CHIP_BASE, CHIP_SIZE_SM);

/** Audit log type column — each logType gets its own hue. */
const AUDIT_LOG_TYPE_CHIP_DARK: Record<string, string> = {
  data_access: 'bg-cyan-500/20 text-cyan-100 border-cyan-400/70',
  action: 'bg-orange-500/20 text-orange-100 border-orange-400/70',
  security: 'bg-red-500/20 text-red-100 border-red-400/70',
  compliance: 'bg-amber-500/20 text-amber-100 border-amber-400/70',
  admin: 'bg-indigo-500/20 text-indigo-100 border-indigo-400/70',
  admin_customer_view: 'bg-sky-500/20 text-sky-100 border-sky-400/70',
  user: 'bg-slate-500/20 text-slate-200 border-slate-400/70',
  system: 'bg-violet-500/20 text-violet-100 border-violet-400/70',
  audit: 'bg-purple-500/20 text-purple-100 border-purple-400/70',
  legal: 'bg-rose-500/20 text-rose-100 border-rose-400/70',
  configuration: 'bg-emerald-500/20 text-emerald-100 border-emerald-400/70',
  correction: 'bg-fuchsia-500/20 text-fuchsia-100 border-fuchsia-400/70',
};

const AUDIT_LOG_TYPE_CHIP_LIGHT: Record<string, string> = {
  data_access: 'bg-cyan-100 text-cyan-800 border-cyan-400/70',
  action: 'bg-orange-100 text-orange-800 border-orange-400/70',
  security: 'bg-red-100 text-red-800 border-red-400/70',
  compliance: 'bg-amber-100 text-amber-800 border-amber-400/70',
  admin: 'bg-indigo-100 text-indigo-800 border-indigo-400/70',
  admin_customer_view: 'bg-sky-100 text-sky-800 border-sky-400/70',
  user: 'bg-slate-100 text-slate-700 border-slate-400/70',
  system: 'bg-violet-100 text-violet-800 border-violet-400/70',
  audit: 'bg-purple-100 text-purple-800 border-purple-400/70',
  legal: 'bg-rose-100 text-rose-800 border-rose-400/70',
  configuration: 'bg-emerald-100 text-emerald-800 border-emerald-400/70',
  correction: 'bg-fuchsia-100 text-fuchsia-800 border-fuchsia-400/70',
};

const FALLBACK_DARK = 'bg-slate-500/20 text-slate-300 border-slate-400/70';
const FALLBACK_LIGHT = 'bg-slate-100 text-slate-700 border-slate-400/70';

function normalizeLogType(value: string): string {
  return value?.toLowerCase().trim() || '';
}

export function auditLogTypeChipClasses(logType: string, isDark: boolean): string {
  const key = normalizeLogType(logType);
  const tone = isDark ? AUDIT_LOG_TYPE_CHIP_DARK[key] : AUDIT_LOG_TYPE_CHIP_LIGHT[key];
  const fallback = isDark ? FALLBACK_DARK : FALLBACK_LIGHT;
  return clsx(AUDIT_LOG_CHIP_BASE, tone ?? fallback);
}

export const AUDIT_LOG_TYPE_LABELS: Record<string, string> = {
  security: 'Sicherheit',
  compliance: 'Compliance',
  admin: 'Admin',
  user: 'Benutzer',
  system: 'System',
  audit: 'Audit',
  admin_customer_view: 'Kundensicht (Portal)',
  data_access: 'Datenzugriff',
  action: 'Aktion',
  legal: 'Rechtliches',
  configuration: 'Konfiguration',
  correction: 'Korrektur',
};

export function getAuditLogTypeLabel(logType: string): string {
  const key = normalizeLogType(logType);
  return AUDIT_LOG_TYPE_LABELS[key] || logType || '-';
}
