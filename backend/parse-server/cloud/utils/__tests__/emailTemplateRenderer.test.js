'use strict';

const {
  escapeHtml,
  replacePlaceholders,
  insertTicketLinkPlaceholder,
  buildTicketLinkLine,
  FALLBACK_TEMPLATES_DE,
} = require('../emailTemplateRenderer');

describe('emailTemplateRenderer', () => {
  describe('escapeHtml', () => {
    it('escapes script tags', () => {
      expect(escapeHtml('<script>alert(1)</script>')).not.toContain('<script>');
    });
  });

  describe('replacePlaceholders', () => {
    it('replaces placeholders case-insensitively with spaces', () => {
      const tpl = 'Hallo {{ customerName }}, Ticket {{TICKETNUMBER}}';
      const out = replacePlaceholders(tpl, {
        customerName: 'Anna',
        ticketNumber: 'TKT-1',
      });
      expect(out).toBe('Hallo Anna, Ticket TKT-1');
    });
  });

  describe('buildTicketLinkLine', () => {
    it('returns app hint when no base URL configured', () => {
      const prev = process.env.FIN1_APP_WEB_URL;
      delete process.env.FIN1_APP_WEB_URL;
      delete process.env.FIN1_PUBLIC_WEB_URL;
      expect(buildTicketLinkLine('abc123')).toContain('FIN1-App');
      if (prev) process.env.FIN1_APP_WEB_URL = prev;
    });

    it('returns URL when FIN1_APP_WEB_URL is set', () => {
      process.env.FIN1_APP_WEB_URL = 'https://app.fin1.test';
      expect(buildTicketLinkLine('abc123')).toContain('https://app.fin1.test/support/tickets/abc123');
      delete process.env.FIN1_APP_WEB_URL;
    });
  });

  describe('insertTicketLinkPlaceholder', () => {
    it('inserts before German closing when missing', () => {
      const body = 'Hallo\n\nMit freundlichen Grüßen,\nTeam';
      const out = insertTicketLinkPlaceholder(body);
      expect(out).toContain('{{ticketLink}}');
      expect(out.indexOf('{{ticketLink}}')).toBeLessThan(out.indexOf('Mit freundlichen'));
    });

    it('is idempotent', () => {
      const body = 'Text\n\n{{ticketLink}}\n\nMit freundlichen Grüßen';
      expect(insertTicketLinkPlaceholder(body)).toBe(body);
    });
  });

  describe('FALLBACK_TEMPLATES_DE', () => {
    it('includes ticket_response with responseMessage placeholder', () => {
      const tpl = FALLBACK_TEMPLATES_DE.ticket_response;
      expect(tpl.body).toContain('{{responseMessage}}');
      const rendered = replacePlaceholders(tpl.body, {
        customerName: 'Max',
        ticketNumber: 'TKT-1',
        ticketSubject: 'Test',
        agentName: 'CSR',
        responseMessage: 'Ihr Konto ist entsperrt.',
        companyName: 'FIN1',
        ticketLink: 'https://example.com',
      });
      expect(rendered).toContain('Max');
      expect(rendered).toContain('Ihr Konto ist entsperrt.');
      expect(rendered).not.toContain('{{responseMessage}}');
    });
  });
});
