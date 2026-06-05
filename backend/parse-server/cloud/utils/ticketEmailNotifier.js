'use strict';

const { sendTicketNotification, sendEmail } = require('./emailService');
const {
  renderCustomerEmail,
  buildTicketEmailValues,
  loadUserProfile,
  escapeHtml,
} = require('./emailTemplateRenderer');

function fireAndForget(promise) {
  Promise.resolve(promise).catch((err) => {
    console.error('[ticket-email]', err.message || err);
  });
}

function ticketView(ticket) {
  if (ticket.get) {
    return {
      objectId: ticket.id,
      ticketNumber: ticket.get('ticketNumber'),
      subject: ticket.get('subject'),
      description: ticket.get('description'),
      status: ticket.get('status'),
      priority: ticket.get('priority'),
      createdAt: ticket.get('createdAt'),
      userId: ticket.get('userId'),
      assignedTo: ticket.get('assignedTo'),
    };
  }
  return ticket;
}

async function loadUserEmail(userId) {
  const profile = await loadUserProfile(userId);
  return profile?.email || null;
}

async function sendCustomerTicketEmail({ to, subject, text, html }) {
  if (!to) return false;
  return sendEmail({ to, subject, text, html });
}

async function sendRenderedCustomerEmail(ticket, templateType, extras = {}) {
  const to = await loadUserEmail(ticketSnapshotUserId(ticket));
  if (!to) return false;

  const values = await buildTicketEmailValues(ticket, extras);

  const rendered = await renderCustomerEmail(templateType, values, { language: 'de' });
  return sendCustomerTicketEmail({
    to,
    subject: rendered.subject,
    text: rendered.text,
    html: rendered.html,
  });
}

function ticketSnapshotUserId(ticket) {
  if (ticket.get) return ticket.get('userId');
  return ticket.userId;
}

async function notifyTicketCreated(ticket) {
  const t = ticketView(ticket);
  await sendTicketNotification(t, 'new');
  await sendRenderedCustomerEmail(ticket, 'ticket_created');
}

async function notifyTicketPublicReply(ticket, responseMessage, options = {}) {
  await sendRenderedCustomerEmail(ticket, 'ticket_response', {
    agentId: options.agentId,
    responseMessage: String(responseMessage || ''),
  });
}

async function notifyTicketEscalated(ticket, reason) {
  const t = ticketView(ticket);
  await sendTicketNotification({ ...t, message: reason }, 'update');

  const agentEmail = await loadUserEmail(t.assignedTo);
  if (agentEmail) {
    const safeReason = escapeHtml(reason);
    await sendEmail({
      to: agentEmail,
      subject: `[FIN1] Ticket ${t.ticketNumber} eskaliert`,
      text: `Ticket ${t.ticketNumber} wurde eskaliert.\n\nGrund: ${reason}`,
      html: `<p>Ticket <strong>${escapeHtml(t.ticketNumber)}</strong> wurde eskaliert.</p><p>${safeReason}</p>`,
    });
  }
}

async function notifyTicketResolved(ticket, resolutionNote, options = {}) {
  await sendRenderedCustomerEmail(ticket, 'ticket_resolved', {
    agentId: options.agentId,
    resolutionSummary: String(resolutionNote || ''),
  });
}

function scheduleTicketCreated(ticket) {
  fireAndForget(notifyTicketCreated(ticket));
}

function scheduleTicketPublicReply(ticket, responseMessage, options = {}) {
  fireAndForget(notifyTicketPublicReply(ticket, responseMessage, options));
}

function scheduleTicketEscalated(ticket, reason) {
  fireAndForget(notifyTicketEscalated(ticket, reason));
}

function scheduleTicketResolved(ticket, resolutionNote, options = {}) {
  fireAndForget(notifyTicketResolved(ticket, resolutionNote, options));
}

module.exports = {
  notifyTicketCreated,
  notifyTicketPublicReply,
  notifyTicketEscalated,
  notifyTicketResolved,
  scheduleTicketCreated,
  scheduleTicketPublicReply,
  scheduleTicketEscalated,
  scheduleTicketResolved,
};
