import { format, formatDistanceToNow, parseISO, isValid } from 'date-fns';
import { de } from 'date-fns/locale';

/**
 * Safely parse a date value.
 * Handles plain strings, Date instances, and Parse Server encoded dates
 * (`{ __type: "Date", iso: "…" }`).
 */
function safeParseDate(dateValue: unknown): Date | null {
  if (!dateValue) return null;

  try {
    let date: Date;

    if (dateValue instanceof Date) {
      date = dateValue;
    } else if (typeof dateValue === 'string') {
      date = parseISO(dateValue);
      if (!isValid(date)) {
        date = new Date(dateValue);
      }
    } else if (
      typeof dateValue === 'object' &&
      dateValue !== null &&
      (dateValue as Record<string, unknown>).__type === 'Date' &&
      typeof (dateValue as Record<string, unknown>).iso === 'string'
    ) {
      date = parseISO((dateValue as Record<string, string>).iso);
    } else {
      return null;
    }

    return isValid(date) ? date : null;
  } catch {
    return null;
  }
}

/**
 * Format a date string to German locale
 */
export function formatDate(dateString: unknown): string {
  const date = safeParseDate(dateString);
  if (!date) return '-';

  try {
    return format(date, 'dd.MM.yyyy', { locale: de });
  } catch {
    return '-';
  }
}

/**
 * Format a date with time
 */
export function formatDateTime(dateString: unknown): string {
  const date = safeParseDate(dateString);
  if (!date) return '-';

  try {
    return format(date, 'dd.MM.yyyy HH:mm', { locale: de });
  } catch {
    return '-';
  }
}

/**
 * Format relative time (e.g., "vor 5 Minuten")
 */
export function formatRelative(dateString: unknown): string {
  const date = safeParseDate(dateString);
  if (!date) return '-';

  try {
    return formatDistanceToNow(date, { addSuffix: true, locale: de });
  } catch {
    return '-';
  }
}

/**
 * Format currency (Euro)
 */
export function formatCurrency(amount: number | undefined): string {
  if (amount === undefined || amount === null) return '-';

  return new Intl.NumberFormat('de-DE', {
    style: 'currency',
    currency: 'EUR',
  }).format(amount);
}

/**
 * Format number with German locale
 */
export function formatNumber(num: number | undefined): string {
  if (num === undefined || num === null) return '-';

  return new Intl.NumberFormat('de-DE').format(num);
}

/**
 * Format percentage (0.1 -> "10%")
 */
export function formatPercentage(value: number | undefined): string {
  if (value === undefined || value === null) return '-';

  return new Intl.NumberFormat('de-DE', {
    style: 'percent',
    minimumFractionDigits: 0,
    maximumFractionDigits: 2,
  }).format(value);
}

/**
 * Truncate text with ellipsis
 */
export function truncate(text: string, maxLength: number): string {
  if (text.length <= maxLength) return text;
  return text.slice(0, maxLength - 3) + '...';
}

/**
 * Get status badge color class
 */
export function getStatusColor(status: string): string {
  const colors: Record<string, string> = {
    // User status
    active: 'badge-success',
    pending: 'badge-warning',
    suspended: 'badge-danger',
    locked: 'badge-danger',
    closed: 'badge-neutral',
    deleted: 'badge-neutral',

    // Ticket status
    open: 'badge-warning',
    in_progress: 'badge-info',
    resolved: 'badge-success',

    // Compliance severity
    low: 'badge-info',
    medium: 'badge-warning',
    high: 'badge-danger',
    critical: 'badge-danger',

    // Approval status
    approved: 'badge-success',
    rejected: 'badge-danger',

    // KYC status
    verified: 'badge-success',
    not_started: 'badge-neutral',
    in_review: 'badge-warning',
    failed: 'badge-danger',
  };

  return colors[status.toLowerCase()] || 'badge-neutral';
}

/**
 * Get role display name
 */
export function getRoleDisplay(role: string): string {
  const roles: Record<string, string> = {
    investor: 'Anleger',
    trader: 'Händler',
    admin: 'Administrator',
    business_admin: 'Finance Admin',
    security_officer: 'Security Officer',
    compliance: 'Compliance',
    customer_service: 'Kundenservice',
    system: 'System',
  };

  return roles[role] || role;
}

/**
 * Maps `csrSubRole` (and legacy `csrRole`) from Parse to a short sidebar label.
 * Accepts both seeded keys (`level1`, `fraud`, …) and legacy underscore forms (`level_1`, `fraud_analyst`, …).
 */
export function getCsrSubRoleSidebarLabel(csrSubRole?: string | null): string | null {
  if (csrSubRole == null || typeof csrSubRole !== 'string') return null;
  const key = csrSubRole.trim();
  if (!key) return null;

  switch (key) {
    case 'level_1':
    case 'level1':
      return 'CSR L1';
    case 'level_2':
    case 'level2':
      return 'CSR L2';
    case 'fraud_analyst':
    case 'fraudAnalyst':
    case 'fraud':
      return 'Fraud';
    case 'compliance_officer':
    case 'complianceOfficer':
    case 'compliance':
      return 'Compliance';
    case 'tech_support':
    case 'techSupport':
    case 'tech':
      return 'Tech';
    case 'teamlead':
      return 'Lead';
    default:
      return null;
  }
}

/**
 * Second line under the user name in admin / CSR sidebars.
 */
export function getSidebarRoleSubtitle(user: { role: string; csrSubRole?: string; csrRole?: string }): string {
  if (user.role === 'customer_service') {
    const sub = getCsrSubRoleSidebarLabel(user.csrSubRole || user.csrRole);
    if (sub) return sub;
    return 'CSR';
  }
  return getRoleDisplay(user.role);
}

/**
 * Get status display name
 */
export function getStatusDisplay(status: string): string {
  const statuses: Record<string, string> = {
    active: 'Aktiv',
    pending: 'Ausstehend',
    suspended: 'Gesperrt',
    locked: 'Gesperrt',
    closed: 'Geschlossen',
    deleted: 'Gelöscht',
    open: 'Offen',
    in_progress: 'In Bearbeitung',
    resolved: 'Gelöst',
    approved: 'Genehmigt',
    rejected: 'Abgelehnt',
    verified: 'Verifiziert',
    not_started: 'Nicht gestartet',
    in_review: 'In Prüfung',
    failed: 'Fehlgeschlagen',
  };

  return statuses[status.toLowerCase()] || status;
}
