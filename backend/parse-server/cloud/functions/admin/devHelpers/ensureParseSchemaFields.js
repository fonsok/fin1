'use strict';

/**
 * Fügt per Parse REST (Master-Key) fehlende Felder zum Class-Schema hinzu.
 * Client-Saves dürfen kein addField auslösen — beforeSave setzt u. a. businessCaseId auf Investment.
 */

const { requireAdminRole } = require('../../../utils/permissions');

function parseServerRestBase() {
  const port = Number(process.env.PORT || 1337);
  const raw = (process.env.PARSE_SERVER_INTERNAL_URL || `http://127.0.0.1:${port}/parse`).trim();
  return raw.replace(/\/$/, '');
}

/**
 * @param {string} className
 * @param {Record<string, { type: string }>} fields
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

async function ensureInvestmentBusinessCaseIdSchema() {
  return putParseSchemaFields('Investment', {
    businessCaseId: { type: 'String' },
  });
}

/** Eigenbelege (Document) setzen businessCaseId — ohne Schema-Spalte schlägt save() fehl → keine RSV-Buchung. */
async function ensureDocumentBusinessCaseIdSchema() {
  return putParseSchemaFields('Document', {
    businessCaseId: { type: 'String' },
    /** Mehrzeiliger Eigenbeleg-/Buchungstext (Reservierung GoB), Anzeige in App ohne PDF. */
    accountingSummaryText: { type: 'String' },
  });
}

async function ensureGoBInvestmentEscrowSchemaFields() {
  const investment = await ensureInvestmentBusinessCaseIdSchema();
  const document = await ensureDocumentBusinessCaseIdSchema();
  return { investment, document };
}

function registerEnsureInvestmentSchemaParseFields() {
  Parse.Cloud.define('updateInvestmentClassSchemaFields', async (request) => {
    requireAdminRole(request);
    const result = await ensureGoBInvestmentEscrowSchemaFields();
    const okInv = Boolean(result.investment.ok || result.investment.skipped);
    const okDoc = Boolean(result.document.ok || result.document.skipped);
    return { success: okInv && okDoc, result };
  });

  const { round2 } = require('../../../utils/accountingHelper/shared');
  const investmentEscrow = require('../../../utils/accountingHelper/investmentEscrow');

  /** Repariert fehlende Reserve-Leg (AVA→RSV) für Investments im Status reserved, sofern noch kein leg=reserve existiert. */
  Parse.Cloud.define('repairMissingInvestmentReserveEscrow', async (request) => {
    requireAdminRole(request);
    const limit = Math.min(Math.max(Number(request.params?.limit) || 50, 1), 200);
    const q = new Parse.Query('Investment');
    q.equalTo('status', 'reserved');
    q.descending('createdAt');
    q.limit(limit);
    const investments = await q.find({ useMasterKey: true });

    const out = { scanned: investments.length, repaired: [], skipped: [], errors: [] };
    for (const inv of investments) {
      const id = inv.id;
      if (!id) {
        out.errors.push({ reason: 'no_id' });
        continue;
      }
      if (await investmentEscrow.hasEscrowLeg(id, 'reserve')) {
        out.skipped.push(id);
        continue;
      }
      try {
        const br = await investmentEscrow.bookReserve({
          investorId: inv.get('investorId'),
          amount: round2(inv.get('amount')),
          investmentId: id,
          investmentNumber: inv.get('investmentNumber') || '',
          parseInvestment: inv,
        });
        if (br && br.ok === false) {
          out.errors.push({ id, reason: br.reason, detail: br.detail });
          continue;
        }
        if (await investmentEscrow.hasEscrowLeg(id, 'reserve')) {
          out.repaired.push(id);
        } else {
          out.errors.push({ id, reason: 'reserve_leg_still_missing', bookReserve: br || null });
        }
      } catch (e) {
        out.errors.push({ id, reason: e.message });
      }
    }
    return out;
  });
}

module.exports = {
  putParseSchemaFields,
  ensureInvestmentBusinessCaseIdSchema,
  ensureDocumentBusinessCaseIdSchema,
  ensureGoBInvestmentEscrowSchemaFields,
  registerEnsureInvestmentSchemaParseFields,
};
