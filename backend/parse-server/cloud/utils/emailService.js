// ============================================================================
// E-Mail Service for FIN1
// utils/emailService.js
// ============================================================================
//
// Nodemailer-basierter E-Mail-Service für Benachrichtigungen.
// Unterstützt verschiedene SMTP-Provider (Gmail, SendGrid, eigener SMTP).
//
// Umgebungsvariablen:
//   SMTP_HOST     - SMTP Server (z.B. smtp.gmail.com)
//   SMTP_PORT     - SMTP Port (587 für TLS, 465 für SSL)
//   SMTP_USER     - SMTP Benutzername
//   SMTP_PASS     - SMTP Passwort/App-Password
//   SMTP_FROM     - Absender-Adresse (z.B. noreply@fin1.de)
//   SMTP_SECURE   - true für SSL (Port 465), false für TLS (Port 587)
//
// ============================================================================

'use strict';

let nodemailer;
let transporter = null;

// Try to load nodemailer
try {
  nodemailer = require('nodemailer');
  console.log('Nodemailer loaded successfully');
} catch (e) {
  console.warn('Nodemailer not installed - email functionality disabled');
  console.warn('To enable: npm install nodemailer');
}

/**
 * Initialize the email transporter
 */
function initTransporter() {
  if (!nodemailer) return null;
  if (transporter) return transporter;

  const host = process.env.SMTP_HOST;
  const port = parseInt(process.env.SMTP_PORT || '587');
  const user = process.env.SMTP_USER;
  const pass = process.env.SMTP_PASS;
  const secure = process.env.SMTP_SECURE === 'true';

  if (!host || !user || !pass) {
    console.warn('SMTP not configured - email functionality disabled');
    console.warn('Required: SMTP_HOST, SMTP_USER, SMTP_PASS');
    return null;
  }

  transporter = nodemailer.createTransport({
    host,
    port,
    secure,
    auth: { user, pass },
  });

  console.log(`SMTP configured: ${host}:${port}`);
  return transporter;
}

/**
 * Send an email
 * @param {Object} options - Email options
 * @param {string} options.to - Recipient email
 * @param {string} options.subject - Email subject
 * @param {string} options.text - Plain text body
 * @param {string} options.html - HTML body (optional)
 * @returns {Promise<boolean>} - Success status
 */
async function sendEmail({ to, subject, text, html }) {
  const transport = initTransporter();

  if (!transport) {
    console.log(`[EMAIL DISABLED] Would send to ${to}: ${subject}`);
    return false;
  }

  const from = process.env.SMTP_FROM || process.env.SMTP_USER;

  try {
    const result = await transport.sendMail({
      from: `FIN1 <${from}>`,
      to,
      subject,
      text,
      html: html || text,
    });
    console.log(`Email sent to ${to}: ${subject} (${result.messageId})`);
    return true;
  } catch (error) {
    console.error(`Failed to send email to ${to}:`, error.message);
    return false;
  }
}

// ============================================================================
// EMAIL TEMPLATES
// ============================================================================

/**
 * Send ticket notification to support team
 */
async function sendTicketNotification(ticket, type = 'new') {
  const subjects = {
    new: `[FIN1] Neues Ticket #${ticket.ticketNumber}: ${ticket.subject}`,
    update: `[FIN1] Ticket #${ticket.ticketNumber} aktualisiert`,
    reply: `[FIN1] Neue Antwort auf Ticket #${ticket.ticketNumber}`,
  };

  const supportEmail = process.env.SUPPORT_EMAIL || process.env.SMTP_USER;

  return sendEmail({
    to: supportEmail,
    subject: subjects[type] || subjects.new,
    text: `
Ticket #${ticket.ticketNumber}
==========================

Betreff: ${ticket.subject}
Status: ${ticket.status}
Priorität: ${ticket.priority}
Erstellt: ${ticket.createdAt}

Nachricht:
${ticket.message || ticket.description || '-'}

---
FIN1 Admin Portal
    `.trim(),
    html: `
<div style="font-family: Arial, sans-serif; max-width: 600px;">
  <h2 style="color: #1a5f7a;">Ticket #${ticket.ticketNumber}</h2>
  <p><strong>Betreff:</strong> ${ticket.subject}</p>
  <p><strong>Status:</strong> ${ticket.status}</p>
  <p><strong>Priorität:</strong> ${ticket.priority}</p>
  <hr style="border: 1px solid #eee;">
  <p>${ticket.message || ticket.description || '-'}</p>
  <hr style="border: 1px solid #eee;">
  <p style="color: #888; font-size: 12px;">FIN1 Admin Portal</p>
</div>
    `.trim(),
  });
}

/**
 * Send approval request notification
 */
async function sendApprovalNotification(request, approverEmail) {
  return sendEmail({
    to: approverEmail,
    subject: `[FIN1] Freigabe erforderlich: ${request.requestType}`,
    text: `
4-Augen-Freigabe erforderlich
=============================

Typ: ${request.requestType}
Angefragt von: ${request.requesterRole}
Erstellt: ${request.createdAt}
Läuft ab: ${request.expiresAt}

Details:
${JSON.stringify(request.metadata, null, 2)}

Bitte melden Sie sich im Admin Portal an, um die Anfrage zu prüfen.

---
FIN1 Admin Portal
    `.trim(),
    html: `
<div style="font-family: Arial, sans-serif; max-width: 600px;">
  <h2 style="color: #1a5f7a;">4-Augen-Freigabe erforderlich</h2>
  <p><strong>Typ:</strong> ${request.requestType}</p>
  <p><strong>Angefragt von:</strong> ${request.requesterRole}</p>
  <p><strong>Läuft ab:</strong> ${request.expiresAt}</p>
  <hr style="border: 1px solid #eee;">
  <p>Bitte melden Sie sich im <a href="http://192.168.178.24/admin/approvals">Admin Portal</a> an.</p>
  <hr style="border: 1px solid #eee;">
  <p style="color: #888; font-size: 12px;">FIN1 Admin Portal</p>
</div>
    `.trim(),
  });
}

/**
 * Send security alert notification
 */
async function sendSecurityAlert(alert, recipientEmail) {
  const severityColors = {
    low: '#28a745',
    medium: '#ffc107',
    high: '#fd7e14',
    critical: '#dc3545',
  };

  return sendEmail({
    to: recipientEmail,
    subject: `[FIN1 SECURITY] ${alert.severity.toUpperCase()}: ${alert.type}`,
    text: `
SICHERHEITSWARNUNG
==================

Typ: ${alert.type}
Schweregrad: ${alert.severity}
Zeit: ${alert.createdAt}

Beschreibung:
${alert.message}

${alert.userId ? `Betroffener Benutzer: ${alert.email || alert.userId}` : ''}

---
FIN1 Security
    `.trim(),
    html: `
<div style="font-family: Arial, sans-serif; max-width: 600px;">
  <h2 style="color: ${severityColors[alert.severity] || '#dc3545'};">
    ⚠️ Sicherheitswarnung: ${alert.severity.toUpperCase()}
  </h2>
  <p><strong>Typ:</strong> ${alert.type}</p>
  <p><strong>Zeit:</strong> ${alert.createdAt}</p>
  <hr style="border: 1px solid #eee;">
  <p>${alert.message}</p>
  ${alert.userId ? `<p><strong>Betroffener Benutzer:</strong> ${alert.email || alert.userId}</p>` : ''}
  <hr style="border: 1px solid #eee;">
  <p style="color: #888; font-size: 12px;">FIN1 Security</p>
</div>
    `.trim(),
  });
}

/**
 * Send password reset email
 */
async function sendPasswordResetEmail(userEmail, resetToken) {
  const resetLink = `http://192.168.178.24/admin/reset-password?token=${resetToken}`;

  return sendEmail({
    to: userEmail,
    subject: '[FIN1] Passwort zurücksetzen',
    text: `
Passwort zurücksetzen
=====================

Sie haben eine Passwort-Zurücksetzung angefordert.

Klicken Sie auf folgenden Link, um ein neues Passwort zu setzen:
${resetLink}

Dieser Link ist 24 Stunden gültig.

Falls Sie diese Anfrage nicht gestellt haben, ignorieren Sie diese E-Mail.

---
FIN1 Admin Portal
    `.trim(),
    html: `
<div style="font-family: Arial, sans-serif; max-width: 600px;">
  <h2 style="color: #1a5f7a;">Passwort zurücksetzen</h2>
  <p>Sie haben eine Passwort-Zurücksetzung angefordert.</p>
  <p>
    <a href="${resetLink}" style="display: inline-block; background: #1a5f7a; color: white; padding: 12px 24px; text-decoration: none; border-radius: 6px;">
      Neues Passwort setzen
    </a>
  </p>
  <p style="color: #888; font-size: 12px;">Dieser Link ist 24 Stunden gültig.</p>
  <hr style="border: 1px solid #eee;">
  <p style="color: #888; font-size: 12px;">FIN1 Admin Portal</p>
</div>
    `.trim(),
  });
}

/**
 * Test email configuration
 */
async function testEmailConfig() {
  const testEmail = process.env.SMTP_USER;
  if (!testEmail) return { success: false, error: 'SMTP not configured' };

  try {
    const sent = await sendEmail({
      to: testEmail,
      subject: '[FIN1] E-Mail-Test erfolgreich',
      text: 'Wenn Sie diese E-Mail sehen, ist die SMTP-Konfiguration korrekt.',
    });
    return { success: sent };
  } catch (error) {
    return { success: false, error: error.message };
  }
}

module.exports = {
  sendEmail,
  sendTicketNotification,
  sendApprovalNotification,
  sendSecurityAlert,
  sendPasswordResetEmail,
  testEmailConfig,
};

console.log('Email Service loaded');
