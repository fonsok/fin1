'use strict';

/**
 * Parse REST Schema API (Master-Key): fehlende Felder zur Klasse hinzufügen.
 * Kein Client-`addField` — nur Server-seitig.
 */

function parseServerRestBase() {
  const port = Number(process.env.PORT || 1337);
  const raw = (process.env.PARSE_SERVER_INTERNAL_URL || `http://127.0.0.1:${port}/parse`).trim();
  return raw.replace(/\/$/, '');
}

/**
 * @param {string} className
 * @param {Record<string, { type: string }>} fields
 * @returns {Promise<{ ok: boolean, skipped?: boolean, message?: string, status?: number, body?: unknown, note?: string }>}
 */
async function putParseSchemaFields(className, fields) {
  const appId = process.env.PARSE_SERVER_APPLICATION_ID || 'fin1-app-id';
  const masterKey = process.env.PARSE_SERVER_MASTER_KEY;
  if (!masterKey) {
    return {
      ok: false,
      skipped: true,
      message: 'PARSE_SERVER_MASTER_KEY fehlt in der Umgebung — Schema-Update übersprungen.',
    };
  }
  const base = parseServerRestBase();
  const url = `${base}/schemas/${className}`;
  const res = await fetch(url, {
    method: 'PUT',
    headers: {
      'X-Parse-Application-Id': appId,
      'X-Parse-Master-Key': masterKey,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({ className, fields }),
  });
  const text = await res.text();
  let body;
  try {
    body = JSON.parse(text);
  } catch {
    body = { _raw: text };
  }
  if (res.ok) {
    return { ok: true, status: res.status, body };
  }
  const errBlob = JSON.stringify(body).toLowerCase();
  if (
    res.status === 400 &&
    (errBlob.includes('already') ||
      errBlob.includes('exists') ||
      errBlob.includes('field exists') ||
      errBlob.includes('duplicate'))
  ) {
    return { ok: true, status: res.status, note: 'field_likely_already_present', body };
  }
  return { ok: false, status: res.status, body };
}

module.exports = {
  putParseSchemaFields,
};
