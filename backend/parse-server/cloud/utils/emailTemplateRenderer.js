'use strict';

const FALLBACK_TEMPLATES_DE = {
  ticket_created: {
    subject: '[{{companyName}}] Ticket {{ticketNumber}} wurde erstellt',
    body:
      'Guten Tag {{customerName}},\n\nvielen Dank für Ihre Anfrage. Wir haben Ihr Support-Ticket erstellt.\n\nTicket: {{ticketNumber}}\nBetreff: {{ticketSubject}}\n\nUnser Support-Team wird sich schnellstmöglich bei Ihnen melden.\n\n{{ticketLink}}\n\nMit freundlichen Grüßen,\nIhr {{companyName}} Support-Team',
  },
  ticket_response: {
    subject: '[{{companyName}}] Neue Antwort auf Ticket {{ticketNumber}}',
    body:
      'Guten Tag {{customerName}},\n\nSie haben eine neue Antwort auf Ihr Support-Ticket erhalten.\n\nTicket: {{ticketNumber}}\nBetreff: {{ticketSubject}}\n\nAntwort von {{agentName}}:\n{{responseMessage}}\n\n{{ticketLink}}\n\nMit freundlichen Grüßen,\nIhr {{companyName}} Support-Team',
  },
  ticket_resolved: {
    subject: '[{{companyName}}] Ticket {{ticketNumber}} wurde gelöst',
    body:
      'Guten Tag {{customerName}},\n\nIhr Support-Ticket wurde gelöst.\n\nTicket: {{ticketNumber}}\nBetreff: {{ticketSubject}}\nBearbeitet von: {{agentName}}\n\nLösung:\n{{resolutionSummary}}\n\n{{ticketLink}}\n\nMit freundlichen Grüßen,\nIhr {{companyName}} Support-Team',
  },
};

function escapeHtml(value) {
  return String(value ?? '')
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#39;');
}

function plainTextToHtml(text) {
  return escapeHtml(text).replace(/\r\n/g, '\n').replace(/\n/g, '<br>\n');
}

function wrapCustomerEmailHtml(bodyHtml) {
  const open = '<div style="font-family: Arial, sans-serif; max-width: 600px; line-height: 1.5; color: #222;">';
  const close = '</div>';
  return open + '\n' + bodyHtml + '\n<hr style="border: none; border-top: 1px solid #eee; margin: 24px 0;">\n<p style="color: #888; font-size: 12px;">FIN1 Kundenservice</p>\n' + close;
}

function bodyNeedsTicketLink(body) {
  if (!body) return false;
  return !/\{\{\s*ticketLink\s*\}\}/i.test(body);
}

function insertTicketLinkPlaceholder(body) {
  if (!body || !bodyNeedsTicketLink(body)) return body;
  const markers = ['\n\nMit freundlichen Grüßen', '\n\nBest regards,'];
  for (const marker of markers) {
    const idx = body.indexOf(marker);
    if (idx !== -1) {
      return `${body.slice(0, idx)}\n\n{{ticketLink}}${body.slice(idx)}`;
    }
  }
  return `${body}\n\n{{ticketLink}}`;
}

function mergePlaceholderList(existing, required) {
  const set = new Set([...(Array.isArray(existing) ? existing : []), ...required]);
  return [...set].sort();
}

function replacePlaceholders(template, values) {
  let out = String(template || '');
  for (const [key, value] of Object.entries(values || {})) {
    const escapedKey = key.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
    const re = new RegExp(`\\{\\{\\s*${escapedKey}\\s*\\}\\}`, 'gi');
    out = out.replace(re, value != null ? String(value) : '');
  }
  return out.trim();
}

function getCompanyName() {
  return process.env.FIN1_COMPANY_NAME || 'FIN1';
}

function buildTicketLinkLine(ticketObjectId) {
  const base = (process.env.FIN1_APP_WEB_URL || process.env.FIN1_PUBLIC_WEB_URL || '').replace(/\/$/, '');
  if (!base || !ticketObjectId) {
    return 'Öffnen Sie die FIN1-App und gehen Sie zu „Meine Tickets“, um die Nachricht zu lesen.';
  }
  const url = `${base}/support/tickets/${ticketObjectId}`;
  return `Ticket in der App öffnen: ${url}`;
}

async function loadActiveEmailTemplate(type, language = 'de') {
  const Template = Parse.Object.extend('CSREmailTemplate');
  const query = new Parse.Query(Template);
  query.equalTo('type', type);
  query.equalTo('isActive', true);
  const template = await query.first({ useMasterKey: true });
  if (!template) return null;

  const subject = language === 'de'
    ? (template.get('subjectDe') || template.get('subject'))
    : template.get('subject');
  const body = language === 'de'
    ? (template.get('bodyTemplateDe') || template.get('bodyTemplate'))
    : template.get('bodyTemplate');

  return { subject, body, type };
}

function getFallbackTemplate(type, language = 'de') {
  if (language === 'de' && FALLBACK_TEMPLATES_DE[type]) {
    return FALLBACK_TEMPLATES_DE[type];
  }
  return FALLBACK_TEMPLATES_DE[type] || null;
}

/**
 * Render CSREmailTemplate (DB) or built-in fallback for customer-facing mail.
 */
async function renderCustomerEmail(type, values = {}, options = {}) {
  const language = options.language || 'de';
  const dbTemplate = await loadActiveEmailTemplate(type, language);
  const fallback = getFallbackTemplate(type, language);
  const source = dbTemplate || fallback;

  if (!source) {
    throw new Error(`No email template for type: ${type}`);
  }

  const subject = replacePlaceholders(source.subject, values);
  const body = replacePlaceholders(source.body, values);
  const html = wrapCustomerEmailHtml(plainTextToHtml(body));

  return { subject, body, text: body, html, type };
}

async function loadUserProfile(userId) {
  if (!userId) return null;
  try {
    const user = await new Parse.Query(Parse.User).get(userId, { useMasterKey: true });
    const firstName = user.get('firstName') || '';
    const lastName = user.get('lastName') || '';
    const email = user.get('email') || '';
    const fullName = `${firstName} ${lastName}`.trim();
    return {
      email,
      displayName: fullName || (email ? email.split('@')[0] : 'Kunde/Kundin'),
    };
  } catch {
    return null;
  }
}

async function loadAgentName(agentId) {
  if (!agentId) return 'Ihr FIN1 Support-Team';
  const profile = await loadUserProfile(agentId);
  return profile?.displayName || 'Ihr FIN1 Support-Team';
}

function ticketSnapshot(ticket) {
  if (ticket.get) {
    return {
      objectId: ticket.id,
      ticketNumber: ticket.get('ticketNumber'),
      subject: ticket.get('subject'),
      description: ticket.get('description'),
      userId: ticket.get('userId'),
    };
  }
  return {
    objectId: ticket.objectId || ticket.id,
    ticketNumber: ticket.ticketNumber,
    subject: ticket.subject,
    description: ticket.description,
    userId: ticket.userId,
  };
}

async function buildTicketEmailValues(ticket, extras = {}) {
  const snap = ticketSnapshot(ticket);
  const customer = await loadUserProfile(snap.userId);
  const agentName = await loadAgentName(extras.agentId);

  return {
    companyName: getCompanyName(),
    customerName: customer?.displayName || 'Kunde/Kundin',
    ticketNumber: snap.ticketNumber || snap.objectId?.slice(0, 8) || '—',
    ticketSubject: snap.subject || '—',
    ticketDescription: snap.description || '',
    agentName,
    responseMessage: extras.responseMessage || '',
    resolutionSummary: extras.resolutionSummary || '',
    ticketLink: buildTicketLinkLine(snap.objectId),
  };
}

module.exports = {
  escapeHtml,
  plainTextToHtml,
  bodyNeedsTicketLink,
  insertTicketLinkPlaceholder,
  mergePlaceholderList,
  replacePlaceholders,
  loadActiveEmailTemplate,
  renderCustomerEmail,
  buildTicketEmailValues,
  loadUserProfile,
  getCompanyName,
  buildTicketLinkLine,
  FALLBACK_TEMPLATES_DE,
};
