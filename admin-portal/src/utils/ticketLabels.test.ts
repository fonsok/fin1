import { describe, expect, it } from 'vitest';
import {
  getTicketDisplayStatus,
  getTicketStatusLabel,
  isTicketEscalated,
} from './ticketLabels';

describe('ticketLabels', () => {
  it('detects escalation by status or legacy flag', () => {
    expect(isTicketEscalated({ status: 'escalated' })).toBe(true);
    expect(isTicketEscalated({ status: 'in_progress', escalated: true })).toBe(true);
    expect(isTicketEscalated({ status: 'open' })).toBe(false);
    expect(isTicketEscalated({ status: 'resolved', escalated: true })).toBe(false);
  });

  it('maps display status for legacy escalated flag', () => {
    expect(getTicketDisplayStatus({ status: 'in_progress', escalated: true })).toBe('escalated');
    expect(getTicketStatusLabel('escalated')).toBe('Eskaliert');
  });
});
