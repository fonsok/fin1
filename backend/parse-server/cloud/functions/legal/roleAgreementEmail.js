'use strict';

const { normalizeString } = require('./shared');
const { sendEmailWithAttachments } = require('../../utils/emailService');
const { generateRoleAgreementPdf } = require('./roleAgreementPdf');
const { ROLE_CONSENT_SPECS } = require('./roleAgreementConsent');

const ROLE_LABELS = {
  trader: {
    de: 'Signalgeber-Vereinbarung',
    en: 'Trader (Signal Provider) Agreement',
  },
  investor: {
    de: 'Investor-Vereinbarung',
    en: 'Investor Agreement',
  },
};

function resolveUserEmail(user) {
  const email = normalizeString(user?.get?.('email') || user?.get?.('username') || user?.email);
  return email && email.includes('@') ? email : null;
}

function resolveUserDisplayName(user) {
  const first = normalizeString(user?.get?.('firstName'));
  const last = normalizeString(user?.get?.('lastName'));
  const full = `${first} ${last}`.trim();
  if (full) return full;
  return normalizeString(user?.get?.('username')) || 'Nutzer';
}

/**
 * Sends confirmation email with role agreement PDF attached (best-effort).
 */
async function sendRoleAgreementConfirmationEmail({
  user,
  role,
  version,
  acceptedAt,
  documentHash,
  ipAddress,
  userAgent,
}) {
  const to = resolveUserEmail(user);
  if (!to) {
    console.warn(`[RoleAgreement] No email for user ${user?.id}; skipping confirmation mail`);
    return false;
  }

  const roleKey = normalizeString(role)?.toLowerCase();
  const spec = ROLE_CONSENT_SPECS[roleKey];
  if (!spec) return false;

  const language = 'de';
  const title = ROLE_LABELS[roleKey]?.[language] || spec.consentType;
  const acceptedAtIso = acceptedAt instanceof Date ? acceptedAt.toISOString() : new Date().toISOString();
  const displayName = resolveUserDisplayName(user);

  let pdfBuffer = null;
  try {
    pdfBuffer = await generateRoleAgreementPdf({
      role: roleKey,
      version,
      language,
      acceptedAt,
      userId: user.id,
      documentHash: documentHash || null,
      ipAddress: ipAddress || null,
    });
  } catch (err) {
    console.error(`[RoleAgreement] PDF generation failed for ${user.id}:`, err.message);
  }

  const subject = `[FIN1] Bestätigung: ${title} (Version ${version})`;
  const text = `
Guten Tag ${displayName},

vielen Dank für Ihre Zustimmung zur ${title}.

Version: ${version}
Zeitpunkt: ${acceptedAtIso}
Nutzer-ID: ${user.id}
${documentHash ? `Dokument-Hash: ${documentHash}\n` : ''}${ipAddress ? `IP-Adresse: ${ipAddress}\n` : ''}
Die Vereinbarung ist dieser E-Mail als PDF beigefügt (sofern verfügbar).

Mit freundlichen Grüßen
Ihr FIN1-Team
  `.trim();

  const html = `
<div style="font-family: Arial, sans-serif; max-width: 640px; line-height: 1.5;">
  <h2 style="color: #1a5f7a;">Bestätigung: ${title}</h2>
  <p>Guten Tag ${displayName},</p>
  <p>vielen Dank für Ihre Zustimmung zur <strong>${title}</strong>.</p>
  <table style="border-collapse: collapse; margin: 16px 0;">
    <tr><td style="padding: 4px 12px 4px 0;"><strong>Version</strong></td><td>${version}</td></tr>
    <tr><td style="padding: 4px 12px 4px 0;"><strong>Zeitpunkt</strong></td><td>${acceptedAtIso}</td></tr>
    <tr><td style="padding: 4px 12px 4px 0;"><strong>Nutzer-ID</strong></td><td>${user.id}</td></tr>
    ${documentHash ? `<tr><td style="padding: 4px 12px 4px 0;"><strong>Dokument-Hash</strong></td><td style="font-family: monospace; font-size: 12px;">${documentHash}</td></tr>` : ''}
    ${ipAddress ? `<tr><td style="padding: 4px 12px 4px 0;"><strong>IP-Adresse</strong></td><td>${ipAddress}</td></tr>` : ''}
  </table>
  <p>Die Vereinbarung ist dieser E-Mail als PDF beigefügt (sofern verfügbar).</p>
  <p style="color: #888; font-size: 12px;">FIN1 · maschinell erstellt</p>
</div>
  `.trim();

  const attachments = [];
  if (pdfBuffer && pdfBuffer.length > 0) {
    const safeRole = roleKey === 'trader' ? 'Signalgeber' : 'Investor';
    attachments.push({
      filename: `FIN1_${safeRole}_Vereinbarung_v${version}.pdf`,
      content: pdfBuffer,
      contentType: 'application/pdf',
    });
  }

  return sendEmailWithAttachments({
    to,
    subject,
    text,
    html,
    attachments,
  });
}

module.exports = {
  sendRoleAgreementConfirmationEmail,
};
