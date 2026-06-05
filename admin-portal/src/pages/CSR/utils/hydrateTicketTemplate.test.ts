import { describe, expect, it } from 'vitest';
import {
  buildTicketTemplateContext,
  buildTicketTemplateContextFromTicket,
  hydrateTicketTemplateText,
  resolveCustomerDisplayName,
} from './hydrateTicketTemplate';

describe('hydrateTicketTemplate', () => {
  it('resolves customer display name from profile fields', () => {
    expect(
      resolveCustomerDisplayName({
        firstName: 'Max',
        lastName: 'Mustermann',
        email: 'max@test.com',
      }),
    ).toBe('Max Mustermann');
  });

  it('replaces KUNDENNAME and AGENTNAME placeholders', () => {
    const ctx = buildTicketTemplateContext({
      customer: {
        objectId: 'u1',
        userId: 'u1',
        customerNumber: 'ANL-1',
        email: 'investor4@test.com',
        firstName: 'Anna',
        lastName: 'Investor',
        fullName: 'Anna Investor',
        status: 'active',
        role: 'investor',
      },
      agent: { firstName: 'CSR', lastName: 'Agent', email: 'csr@fin1.de' },
    });

    const out = hydrateTicketTemplateText(
      'Guten Tag {{KUNDENNAME}},\n\nIhr Konto wurde entsperrt.\n\n{{AGENTNAME}}',
      ctx,
    );

    expect(out).toContain('Guten Tag Anna Investor');
    expect(out).not.toContain('{{KUNDENNAME}}');
    expect(out).toContain('CSR Agent');
  });

  it('replaces TICKETNUMMER when ticket number is known', () => {
    const ctx = buildTicketTemplateContext({
      customer: {
        objectId: 'u1',
        userId: 'u1',
        customerNumber: 'ANL-1',
        email: 'a@b.de',
        fullName: 'Test User',
        status: 'active',
        role: 'investor',
      },
      ticketNumber: 'TKT-2026-00003',
    });

    const out = hydrateTicketTemplateText('Ticket {{TICKETNUMMER}}', ctx);
    expect(out).toBe('Ticket TKT-2026-00003');
  });

  it('buildTicketTemplateContextFromTicket uses profile when available', () => {
    const ctx = buildTicketTemplateContextFromTicket({
      ticket: {
        userId: 'u1',
        userEmail: 'investor4@test.com',
        ticketNumber: 'TKT-2026-00099',
      },
      customerProfile: {
        objectId: 'u1',
        userId: 'u1',
        customerNumber: 'ANL-4',
        email: 'investor4@test.com',
        fullName: 'Anna Investor',
        status: 'active',
        role: 'investor',
        createdAt: '2026-01-01',
      },
    });
    expect(ctx.customerName).toBe('Anna Investor');
    expect(ctx.ticketNumber).toBe('TKT-2026-00099');
  });
});
