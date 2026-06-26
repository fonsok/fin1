'use strict';

const http = require('http');
const https = require('https');
const { URL } = require('url');
const { normalizeString } = require('./shared');
const { ROLE_CONSENT_SPECS, buildRoleAgreementReplacements } = require('./roleAgreementConsent');
const { serializeTermsContent } = require('./shared');

function replacePlaceholders(text, replacements) {
  if (typeof text !== 'string' || !text) return text;
  return text.replace(/\{\{([A-Z0-9_]+)\}\}/g, (match, token) => {
    if (Object.prototype.hasOwnProperty.call(replacements, token)) {
      return String(replacements[token]);
    }
    return match;
  });
}

function escapeHtml(value) {
  return String(value || '')
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;');
}

function paragraphsFromContent(content) {
  return String(content || '')
    .split(/\n{2,}/)
    .map((block) => block.trim())
    .filter(Boolean)
    .map((block) => `<p>${escapeHtml(block).replace(/\n/g, '<br/>')}</p>`)
    .join('\n');
}

async function loadActiveAgreementDocument(documentType, language = 'de') {
  const q = new Parse.Query('TermsContent');
  q.equalTo('documentType', documentType);
  q.equalTo('language', language);
  q.equalTo('isActive', true);
  q.descending('effectiveDate');
  q.limit(1);
  const doc = await q.first({ useMasterKey: true });
  if (!doc) {
    throw new Error(`No active ${documentType} document for ${language}`);
  }
  return serializeTermsContent(doc);
}

function buildAgreementHtml({
  title,
  version,
  acceptedAt,
  userId,
  documentHash,
  ipAddress,
  sections,
  replacements,
}) {
  const acceptedAtIso = acceptedAt instanceof Date ? acceptedAt.toISOString() : new Date().toISOString();
  const sectionHtml = (sections || []).map((section) => {
    const heading = replacePlaceholders(section.title || '', replacements);
    const body = replacePlaceholders(section.content || '', replacements);
    return `
      <section style="margin-bottom: 20px;">
        <h2 style="font-size: 14px; color: #1a5f7a; margin: 0 0 8px;">${escapeHtml(heading)}</h2>
        ${paragraphsFromContent(body)}
      </section>
    `;
  }).join('\n');

  return `<!DOCTYPE html>
<html lang="de">
<head>
  <meta charset="utf-8"/>
  <title>${escapeHtml(title)}</title>
  <style>
    body { font-family: Arial, Helvetica, sans-serif; font-size: 11pt; color: #222; margin: 32px; }
    h1 { font-size: 18pt; color: #1a5f7a; margin-bottom: 4px; }
    .meta { font-size: 9pt; color: #666; margin-bottom: 24px; border-bottom: 1px solid #ddd; padding-bottom: 12px; }
    p { margin: 0 0 8px; line-height: 1.45; }
  </style>
</head>
<body>
  <h1>${escapeHtml(title)}</h1>
  <div class="meta">
    <div>Version: ${escapeHtml(version)}</div>
    <div>Zustimmung: ${escapeHtml(acceptedAtIso)}</div>
    <div>Nutzer-ID: ${escapeHtml(userId || '—')}</div>
    ${documentHash ? `<div>Dokument-Hash: <span style="font-family: monospace; font-size: 8pt;">${escapeHtml(documentHash)}</span></div>` : ''}
    ${ipAddress ? `<div>IP-Adresse: ${escapeHtml(ipAddress)}</div>` : ''}
  </div>
  ${sectionHtml}
</body>
</html>`;
}

function postJsonForPdf(urlString, payload, timeoutMs = 15000) {
  return new Promise((resolve, reject) => {
    let url;
    try {
      url = new URL(urlString);
    } catch (err) {
      reject(err);
      return;
    }

    const body = JSON.stringify(payload);
    const transport = url.protocol === 'https:' ? https : http;
    const req = transport.request(
      {
        hostname: url.hostname,
        port: url.port || (url.protocol === 'https:' ? 443 : 80),
        path: `${url.pathname}${url.search}`,
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Content-Length': Buffer.byteLength(body),
        },
        timeout: timeoutMs,
      },
      (res) => {
        const chunks = [];
        res.on('data', (chunk) => chunks.push(chunk));
        res.on('end', () => {
          const buffer = Buffer.concat(chunks);
          if (res.statusCode && res.statusCode >= 200 && res.statusCode < 300) {
            resolve(buffer);
            return;
          }
          reject(new Error(`PDF service HTTP ${res.statusCode}: ${buffer.toString('utf8').slice(0, 200)}`));
        });
      },
    );

    req.on('error', reject);
    req.on('timeout', () => {
      req.destroy(new Error('PDF service request timed out'));
    });
    req.write(body);
    req.end();
  });
}

async function generateRoleAgreementPdf({
  role,
  version,
  language = 'de',
  acceptedAt,
  userId,
  documentHash,
  ipAddress,
}) {
  const roleKey = normalizeString(role)?.toLowerCase();
  const spec = ROLE_CONSENT_SPECS[roleKey];
  if (!spec) {
    throw new Error(`Unknown role for PDF: ${role}`);
  }

  const doc = await loadActiveAgreementDocument(spec.documentType, language);
  const replacements = await buildRoleAgreementReplacements();
  const title = roleKey === 'trader'
    ? 'Signalgeber-Vereinbarung (Trader)'
    : 'Investor-Vereinbarung (Pool-Mirror-Trade)';

  const html = buildAgreementHtml({
    title,
    version: version || doc.version,
    acceptedAt,
    userId,
    documentHash,
    ipAddress,
    sections: doc.sections,
    replacements,
  });

  const pdfServiceBase = normalizeString(process.env.PDF_SERVICE_URL || 'http://pdf-service:8083');
  const endpoint = `${pdfServiceBase.replace(/\/$/, '')}/api/pdf/legal-agreement`;

  try {
    return await postJsonForPdf(endpoint, { html });
  } catch (err) {
    console.warn(`[RoleAgreementPdf] PDF service unavailable (${err.message}); using HTML fallback`);
    return Buffer.from(html, 'utf8');
  }
}

module.exports = {
  generateRoleAgreementPdf,
  buildAgreementHtml,
};
