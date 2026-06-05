/** Minimal ticket shape for escalation/display helpers (no extra API fields). */
export interface TicketEscalationFields {
  status?: string;
  escalated?: boolean;
  escalationReason?: string;
  escalatedAt?: string;
  escalatedByName?: string;
}

const TERMINAL_STATUSES = new Set(['resolved', 'closed', 'archived']);

/** True if actively escalated (not after resolve/close). */
export function isTicketEscalated(ticket: TicketEscalationFields): boolean {
  const status = normalizeTicketKey(ticket.status);
  if (TERMINAL_STATUSES.has(status)) return false;
  if (status === 'escalated') return true;
  return ticket.escalated === true;
}

/** Status key for badges/filters (covers legacy escalated=true without status change). */
export function getTicketDisplayStatus(ticket: TicketEscalationFields): string {
  return isTicketEscalated(ticket) ? 'escalated' : (ticket.status ?? '');
}

function normalizeTicketKey(value: string | undefined): string {
  return value?.toLowerCase().trim() ?? '';
}

export function getTicketStatusLabel(status: string): string {
  switch (normalizeTicketKey(status)) {
    case 'open':
      return 'Offen';
    case 'in_progress':
      return 'In Bearbeitung';
    case 'waiting':
    case 'waiting_for_customer':
      return 'Wartend';
    case 'escalated':
      return 'Eskaliert';
    case 'resolved':
      return 'Gelöst';
    case 'closed':
      return 'Geschlossen';
    case 'archived':
      return 'Archiviert';
    default:
      return status || '-';
  }
}

export function getTicketPriorityLabel(priority: string): string {
  switch (normalizeTicketKey(priority)) {
    case 'urgent':
      return 'Dringend';
    case 'high':
      return 'Hoch';
    case 'medium':
      return 'Mittel';
    case 'low':
      return 'Niedrig';
    default:
      return priority || '-';
  }
}
