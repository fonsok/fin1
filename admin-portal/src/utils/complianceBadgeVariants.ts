import clsx from 'clsx';
import { CHIP_BASE, CHIP_SIZE_SM } from './chipVariants';

export const COMPLIANCE_CHIP_BASE = clsx(CHIP_BASE, CHIP_SIZE_SM);

/** Severity column — distinct hue per level (not shared danger for critical+high). */
const SEVERITY_CHIP_DARK: Record<string, string> = {
  critical: 'bg-red-500/20 text-red-100 border-red-400/70',
  high: 'bg-orange-500/20 text-orange-100 border-orange-400/70',
  medium: 'bg-amber-500/20 text-amber-100 border-amber-400/70',
  low: 'bg-cyan-500/20 text-cyan-100 border-cyan-400/70',
};

const SEVERITY_CHIP_LIGHT: Record<string, string> = {
  critical: 'bg-red-100 text-red-800 border-red-400/70',
  high: 'bg-orange-100 text-orange-800 border-orange-400/70',
  medium: 'bg-amber-100 text-amber-800 border-amber-400/70',
  low: 'bg-cyan-100 text-cyan-800 border-cyan-400/70',
};

/** Event type column — each eventType gets its own hue. */
const EVENT_TYPE_CHIP_DARK: Record<string, string> = {
  aml_check_failed: 'bg-red-500/20 text-red-100 border-red-400/70',
  suspicious_activity: 'bg-rose-500/20 text-rose-100 border-rose-400/70',
  large_transaction: 'bg-violet-500/20 text-violet-100 border-violet-400/70',
  login_from_new_device: 'bg-sky-500/20 text-sky-100 border-sky-400/70',
  failed_login_attempt: 'bg-orange-500/20 text-orange-100 border-orange-400/70',
  kyc_document_uploaded: 'bg-emerald-500/20 text-emerald-100 border-emerald-400/70',
  account_locked: 'bg-amber-500/20 text-amber-100 border-amber-400/70',
  account_suspended: 'bg-fuchsia-500/20 text-fuchsia-100 border-fuchsia-400/70',
  password_changed: 'bg-indigo-500/20 text-indigo-100 border-indigo-400/70',
};

const EVENT_TYPE_CHIP_LIGHT: Record<string, string> = {
  aml_check_failed: 'bg-red-100 text-red-800 border-red-400/70',
  suspicious_activity: 'bg-rose-100 text-rose-800 border-rose-400/70',
  large_transaction: 'bg-violet-100 text-violet-800 border-violet-400/70',
  login_from_new_device: 'bg-sky-100 text-sky-800 border-sky-400/70',
  failed_login_attempt: 'bg-orange-100 text-orange-800 border-orange-400/70',
  kyc_document_uploaded: 'bg-emerald-100 text-emerald-800 border-emerald-400/70',
  account_locked: 'bg-amber-100 text-amber-800 border-amber-400/70',
  account_suspended: 'bg-fuchsia-100 text-fuchsia-800 border-fuchsia-400/70',
  password_changed: 'bg-indigo-100 text-indigo-800 border-indigo-400/70',
};

const SEVERITY_FALLBACK_DARK = 'bg-slate-500/20 text-slate-300 border-slate-400/70';
const SEVERITY_FALLBACK_LIGHT = 'bg-slate-100 text-slate-700 border-slate-400/70';
const EVENT_TYPE_FALLBACK_DARK = 'bg-slate-500/20 text-slate-300 border-slate-400/70';
const EVENT_TYPE_FALLBACK_LIGHT = 'bg-slate-100 text-slate-700 border-slate-400/70';

function normalizeKey(value: string): string {
  return value?.toLowerCase().trim() || '';
}

export function complianceSeverityChipClasses(severity: string, isDark: boolean): string {
  const key = normalizeKey(severity);
  const tone = isDark ? SEVERITY_CHIP_DARK[key] : SEVERITY_CHIP_LIGHT[key];
  const fallback = isDark ? SEVERITY_FALLBACK_DARK : SEVERITY_FALLBACK_LIGHT;
  return clsx(COMPLIANCE_CHIP_BASE, tone ?? fallback);
}

export function complianceEventTypeChipClasses(eventType: string, isDark: boolean): string {
  const key = normalizeKey(eventType);
  const tone = isDark ? EVENT_TYPE_CHIP_DARK[key] : EVENT_TYPE_CHIP_LIGHT[key];
  const fallback = isDark ? EVENT_TYPE_FALLBACK_DARK : EVENT_TYPE_FALLBACK_LIGHT;
  return clsx(COMPLIANCE_CHIP_BASE, tone ?? fallback);
}

export const COMPLIANCE_EVENT_TYPE_LABELS: Record<string, string> = {
  aml_check_failed: 'AML-Prüfung fehlgeschlagen',
  suspicious_activity: 'Verdächtige Aktivität',
  large_transaction: 'Große Transaktion',
  login_from_new_device: 'Login von neuem Gerät',
  failed_login_attempt: 'Fehlgeschlagener Login',
  kyc_document_uploaded: 'KYC-Dokument hochgeladen',
  account_locked: 'Konto gesperrt',
  account_suspended: 'Konto gesperrt',
  password_changed: 'Passwort geändert',
};

export function getComplianceEventTypeLabel(eventType: string): string {
  const key = normalizeKey(eventType);
  return COMPLIANCE_EVENT_TYPE_LABELS[key] || eventType || '-';
}

export const COMPLIANCE_SEVERITY_LABELS: Record<string, string> = {
  critical: 'Kritisch',
  high: 'Hoch',
  medium: 'Mittel',
  low: 'Niedrig',
};

export function getComplianceSeverityLabel(severity: string): string {
  const key = normalizeKey(severity);
  return COMPLIANCE_SEVERITY_LABELS[key] || severity || '-';
}
