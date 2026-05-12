'use strict';

/**
 * Eröffnungs-/Stichtagssalden fürs App-Hauptbuch (netDebitMinusCredit pro Konto, wie Ledger-Aggregation).
 *
 * Parse-Klasse: LedgerOpeningSnapshot
 * - effectiveDate: Date — Salden gelten „per Ende dieses Tages“ (UTC); Abstimmung nutzt letzten Snapshot mit effectiveDate < Periodenbeginn.
 * - label, notes, balances (Object), source
 */

const { round2 } = require('./shared');

function normalizeBalancesObject(balances) {
  if (!balances || typeof balances !== 'object') {
    throw new Parse.Error(Parse.Error.INVALID_QUERY, 'balances muss ein Objekt { KONTocode: { netDebitMinusCredit: number } } sein.');
  }
  const out = {};
  for (const [code, raw] of Object.entries(balances)) {
    const k = String(code || '').trim();
    if (!k) continue;
    const n = typeof raw === 'number' && Number.isFinite(raw)
      ? raw
      : Number(raw && raw.netDebitMinusCredit);
    if (!Number.isFinite(n)) {
      throw new Parse.Error(Parse.Error.INVALID_QUERY, `Ungültiger Saldo für Konto ${k}`);
    }
    out[k] = { netDebitMinusCredit: round2(n) };
  }
  if (Object.keys(out).length === 0) {
    throw new Parse.Error(Parse.Error.INVALID_QUERY, 'mindestens ein Kontosaldo erforderlich');
  }
  return out;
}

async function saveLedgerOpeningSnapshot({ effectiveDate, label, notes, balances, source }) {
  const d = effectiveDate instanceof Date ? effectiveDate : new Date(effectiveDate);
  if (Number.isNaN(d.getTime())) {
    throw new Parse.Error(Parse.Error.INVALID_QUERY, 'effectiveDate ungültig');
  }
  const norm = normalizeBalancesObject(balances);
  const Snap = Parse.Object.extend('LedgerOpeningSnapshot');
  const row = new Snap();
  row.set('effectiveDate', d);
  row.set('label', String(label || '').trim() || `Snapshot ${d.toISOString().slice(0, 10)}`);
  row.set('notes', String(notes || '').trim());
  row.set('balances', norm);
  row.set('source', String(source || 'admin'));
  await row.save(null, { useMasterKey: true });
  return row;
}

async function listLedgerOpeningSnapshots({ limit = 40 } = {}) {
  const q = new Parse.Query('LedgerOpeningSnapshot');
  q.descending('effectiveDate');
  q.limit(Math.min(Math.max(Number(limit) || 40, 1), 200));
  const rows = await q.find({ useMasterKey: true });
  return rows.map((r) => ({
    objectId: r.id,
    effectiveDate: r.get('effectiveDate'),
    label: r.get('label') || '',
    notes: r.get('notes') || '',
    balances: r.get('balances') || {},
    source: r.get('source') || '',
    createdAt: r.get('createdAt'),
  }));
}

/**
 * Letzter Snapshot strikt vor `periodStart` (typisch: Periodenbeginn 00:00 UTC).
 */
async function getLatestLedgerOpeningSnapshotBefore(periodStart) {
  const t = periodStart instanceof Date ? periodStart : new Date(periodStart);
  if (Number.isNaN(t.getTime())) return null;
  const q = new Parse.Query('LedgerOpeningSnapshot');
  q.lessThan('effectiveDate', t);
  q.descending('effectiveDate');
  q.limit(1);
  const row = await q.first({ useMasterKey: true });
  if (!row) return null;
  return {
    objectId: row.id,
    effectiveDate: row.get('effectiveDate'),
    label: row.get('label') || '',
    notes: row.get('notes') || '',
    balances: row.get('balances') || {},
    source: row.get('source') || '',
    createdAt: row.get('createdAt'),
  };
}

module.exports = {
  saveLedgerOpeningSnapshot,
  listLedgerOpeningSnapshots,
  getLatestLedgerOpeningSnapshotBefore,
  normalizeBalancesObject,
};
