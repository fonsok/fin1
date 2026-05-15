import clsx from 'clsx';
import { CHIP_BASE, CHIP_SIZE_SM, chipAccentClasses, type ChipAccent } from './chipVariants';

export const COMPLIANCE_CHIP_BASE = clsx(CHIP_BASE, CHIP_SIZE_SM);

/** Severity column — distinct hue per level (incl. info from schema). */
const SEVERITY_CHIP_DARK: Record<string, string> = {
  critical: 'bg-red-500/20 text-red-100 border-red-400/70',
  high: 'bg-orange-500/20 text-orange-100 border-orange-400/70',
  medium: 'bg-amber-500/20 text-amber-100 border-amber-400/70',
  low: 'bg-cyan-500/20 text-cyan-100 border-cyan-400/70',
  info: 'bg-sky-500/20 text-sky-100 border-sky-400/70',
};

const SEVERITY_CHIP_LIGHT: Record<string, string> = {
  critical: 'bg-red-100 text-red-800 border-red-400/70',
  high: 'bg-orange-100 text-orange-800 border-orange-400/70',
  medium: 'bg-amber-100 text-amber-800 border-amber-400/70',
  low: 'bg-cyan-100 text-cyan-800 border-cyan-400/70',
  info: 'bg-sky-100 text-sky-800 border-sky-400/70',
};

/** Event type column — explicit hue per known ComplianceEvent.eventType. */
const EVENT_TYPE_CHIP_DARK: Record<string, string> = {
  // KYC
  kyc_initiated: 'bg-teal-500/20 text-teal-100 border-teal-400/70',
  kyc_document_uploaded: 'bg-emerald-500/20 text-emerald-100 border-emerald-400/70',
  kyc_verified: 'bg-green-500/20 text-green-100 border-green-400/70',
  kyc_rejected: 'bg-red-500/20 text-red-100 border-red-400/70',
  kyc_expired: 'bg-slate-500/20 text-slate-300 border-slate-400/70',
  // AML
  aml_check_passed: 'bg-emerald-500/20 text-emerald-100 border-emerald-400/70',
  aml_check_failed: 'bg-red-500/20 text-red-100 border-red-400/70',
  pep_check_positive: 'bg-rose-500/20 text-rose-100 border-rose-400/70',
  sanction_check_positive: 'bg-red-500/20 text-red-100 border-red-400/70',
  // Orders / trades (iOS camelCase normalizes here — blue / yellow / green / red quartet)
  order_placed: 'bg-blue-500/20 text-blue-100 border-blue-400/70',
  order_completed: 'bg-green-500/20 text-green-100 border-green-400/70',
  risk_check: 'bg-yellow-500/20 text-yellow-100 border-yellow-400/70',
  order_executed: 'bg-indigo-500/20 text-indigo-100 border-indigo-400/70',
  order_cancelled: 'bg-slate-500/20 text-slate-300 border-slate-400/70',
  trade_completed: 'bg-violet-500/20 text-violet-100 border-violet-400/70',
  // Risk
  appropriateness_check: 'bg-cyan-500/20 text-cyan-100 border-cyan-400/70',
  risk_warning_shown: 'bg-amber-500/20 text-amber-100 border-amber-400/70',
  risk_warning_acknowledged: 'bg-emerald-500/20 text-emerald-100 border-emerald-400/70',
  // Monitoring
  large_transaction: 'bg-violet-500/20 text-violet-100 border-violet-400/70',
  suspicious_activity: 'bg-rose-500/20 text-rose-100 border-rose-400/70',
  sar_filed: 'bg-red-500/20 text-red-100 border-red-400/70',
  // Wallet
  deposit_received: 'bg-green-500/20 text-green-100 border-green-400/70',
  withdrawal_requested: 'bg-orange-500/20 text-orange-100 border-orange-400/70',
  withdrawal_completed: 'bg-emerald-500/20 text-emerald-100 border-emerald-400/70',
  // Account
  account_created: 'bg-sky-500/20 text-sky-100 border-sky-400/70',
  account_locked: 'bg-amber-500/20 text-amber-100 border-amber-400/70',
  account_suspended: 'bg-fuchsia-500/20 text-fuchsia-100 border-fuchsia-400/70',
  account_reactivated: 'bg-emerald-500/20 text-emerald-100 border-emerald-400/70',
  account_closed: 'bg-slate-500/20 text-slate-300 border-slate-400/70',
  // Security
  login_from_new_device: 'bg-sky-500/20 text-sky-100 border-sky-400/70',
  failed_login_attempt: 'bg-orange-500/20 text-orange-100 border-orange-400/70',
  password_changed: 'bg-indigo-500/20 text-indigo-100 border-indigo-400/70',
  two_factor_enabled: 'bg-purple-500/20 text-purple-100 border-purple-400/70',
  // GDPR
  data_exported: 'bg-cyan-500/20 text-cyan-100 border-cyan-400/70',
  data_deleted: 'bg-rose-500/20 text-rose-100 border-rose-400/70',
  consent_given: 'bg-emerald-500/20 text-emerald-100 border-emerald-400/70',
  consent_revoked: 'bg-amber-500/20 text-amber-100 border-amber-400/70',
  // CSR / support (iOS app; not always in Mongo enum)
  escalation: 'bg-red-500/20 text-red-100 border-red-400/70',
};

const EVENT_TYPE_CHIP_LIGHT: Record<string, string> = {
  kyc_initiated: 'bg-teal-100 text-teal-800 border-teal-400/70',
  kyc_document_uploaded: 'bg-emerald-100 text-emerald-800 border-emerald-400/70',
  kyc_verified: 'bg-green-100 text-green-800 border-green-400/70',
  kyc_rejected: 'bg-red-100 text-red-800 border-red-400/70',
  kyc_expired: 'bg-slate-100 text-slate-700 border-slate-400/70',
  aml_check_passed: 'bg-emerald-100 text-emerald-800 border-emerald-400/70',
  aml_check_failed: 'bg-red-100 text-red-800 border-red-400/70',
  pep_check_positive: 'bg-rose-100 text-rose-800 border-rose-400/70',
  sanction_check_positive: 'bg-red-100 text-red-800 border-red-400/70',
  order_placed: 'bg-blue-100 text-blue-800 border-blue-400/70',
  order_completed: 'bg-green-100 text-green-800 border-green-400/70',
  risk_check: 'bg-yellow-100 text-yellow-800 border-yellow-400/70',
  order_executed: 'bg-indigo-100 text-indigo-800 border-indigo-400/70',
  order_cancelled: 'bg-slate-100 text-slate-700 border-slate-400/70',
  trade_completed: 'bg-violet-100 text-violet-800 border-violet-400/70',
  appropriateness_check: 'bg-cyan-100 text-cyan-800 border-cyan-400/70',
  risk_warning_shown: 'bg-amber-100 text-amber-800 border-amber-400/70',
  risk_warning_acknowledged: 'bg-emerald-100 text-emerald-800 border-emerald-400/70',
  large_transaction: 'bg-violet-100 text-violet-800 border-violet-400/70',
  suspicious_activity: 'bg-rose-100 text-rose-800 border-rose-400/70',
  sar_filed: 'bg-red-100 text-red-800 border-red-400/70',
  deposit_received: 'bg-green-100 text-green-800 border-green-400/70',
  withdrawal_requested: 'bg-orange-100 text-orange-800 border-orange-400/70',
  withdrawal_completed: 'bg-emerald-100 text-emerald-800 border-emerald-400/70',
  account_created: 'bg-sky-100 text-sky-800 border-sky-400/70',
  account_locked: 'bg-amber-100 text-amber-800 border-amber-400/70',
  account_suspended: 'bg-fuchsia-100 text-fuchsia-800 border-fuchsia-400/70',
  account_reactivated: 'bg-emerald-100 text-emerald-800 border-emerald-400/70',
  account_closed: 'bg-slate-100 text-slate-700 border-slate-400/70',
  login_from_new_device: 'bg-sky-100 text-sky-800 border-sky-400/70',
  failed_login_attempt: 'bg-orange-100 text-orange-800 border-orange-400/70',
  password_changed: 'bg-indigo-100 text-indigo-800 border-indigo-400/70',
  two_factor_enabled: 'bg-purple-100 text-purple-800 border-purple-400/70',
  data_exported: 'bg-cyan-100 text-cyan-800 border-cyan-400/70',
  data_deleted: 'bg-rose-100 text-rose-800 border-rose-400/70',
  consent_given: 'bg-emerald-100 text-emerald-800 border-emerald-400/70',
  consent_revoked: 'bg-amber-100 text-amber-800 border-amber-400/70',
  escalation: 'bg-red-100 text-red-800 border-red-400/70',
};

const SEVERITY_FALLBACK_DARK = 'bg-slate-500/20 text-slate-300 border-slate-400/70';
const SEVERITY_FALLBACK_LIGHT = 'bg-slate-100 text-slate-700 border-slate-400/70';

/** Stable accent rotation for event types not in the explicit map. */
const EVENT_TYPE_FALLBACK_ACCENTS: ChipAccent[] = [
  'blue',
  'indigo',
  'violet',
  'purple',
  'cyan',
  'sky',
  'emerald',
  'orange',
  'rose',
  'amber',
];

/** snake_case (Parse seed) and camelCase (iOS ComplianceEventType rawValue). */
export function normalizeEventTypeKey(value: string): string {
  const trimmed = value?.trim() || '';
  if (!trimmed) return '';
  return trimmed
    .replace(/([a-z0-9])([A-Z])/g, '$1_$2')
    .replace(/-/g, '_')
    .toLowerCase();
}

function normalizeKey(value: string): string {
  return normalizeEventTypeKey(value);
}

function stableAccentForEventType(key: string): ChipAccent {
  let hash = 0;
  for (let i = 0; i < key.length; i += 1) {
    hash = (hash * 31 + key.charCodeAt(i)) >>> 0;
  }
  return EVENT_TYPE_FALLBACK_ACCENTS[hash % EVENT_TYPE_FALLBACK_ACCENTS.length];
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
  if (tone) {
    return clsx(COMPLIANCE_CHIP_BASE, tone);
  }
  return chipAccentClasses(stableAccentForEventType(key), isDark);
}

export const COMPLIANCE_EVENT_TYPE_LABELS: Record<string, string> = {
  kyc_initiated: 'KYC gestartet',
  kyc_document_uploaded: 'KYC-Dokument hochgeladen',
  kyc_verified: 'KYC verifiziert',
  kyc_rejected: 'KYC abgelehnt',
  kyc_expired: 'KYC abgelaufen',
  aml_check_passed: 'AML bestanden',
  aml_check_failed: 'AML fehlgeschlagen',
  pep_check_positive: 'PEP-Treffer',
  sanction_check_positive: 'Sanktions-Treffer',
  order_placed: 'Order platziert',
  order_completed: 'Order abgeschlossen',
  risk_check: 'Risiko-Prüfung',
  order_executed: 'Order ausgeführt',
  order_cancelled: 'Order storniert',
  trade_completed: 'Trade abgeschlossen',
  appropriateness_check: 'Angemessenheitsprüfung',
  risk_warning_shown: 'Risikohinweis angezeigt',
  risk_warning_acknowledged: 'Risikohinweis bestätigt',
  large_transaction: 'Große Transaktion',
  suspicious_activity: 'Verdächtige Aktivität',
  sar_filed: 'SAR eingereicht',
  deposit_received: 'Einzahlung erhalten',
  withdrawal_requested: 'Auszahlung angefordert',
  withdrawal_completed: 'Auszahlung abgeschlossen',
  account_created: 'Konto erstellt',
  account_locked: 'Konto gesperrt',
  account_suspended: 'Konto suspendiert',
  account_reactivated: 'Konto reaktiviert',
  account_closed: 'Konto geschlossen',
  login_from_new_device: 'Login von neuem Gerät',
  failed_login_attempt: 'Fehlgeschlagener Login',
  password_changed: 'Passwort geändert',
  two_factor_enabled: '2FA aktiviert',
  data_exported: 'Datenexport',
  data_deleted: 'Daten gelöscht',
  consent_given: 'Einwilligung erteilt',
  consent_revoked: 'Einwilligung widerrufen',
  escalation: 'Eskalation',
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
  info: 'Info',
};

export function getComplianceSeverityLabel(severity: string): string {
  const key = normalizeKey(severity);
  return COMPLIANCE_SEVERITY_LABELS[key] || severity || '-';
}
