'use strict';

/**
 * Phase 3b: Atomarer Kundensaldo (`UserCashBalance.currentBalance`) via MongoDB `$inc`
 * und `findOneAndUpdate` mit `returnDocument: 'before'`, damit `balanceBefore` /
 * `balanceAfter` für `AccountStatement` ohne Read-Modify-Write-Race gesetzt werden.
 *
 * - `ensureUserCashBalanceSeeded`: fehlende Zeile wird aus dem letzten `AccountStatement`
 *   (desc `createdAt`) gesetzt — nötig für Bestands-User ohne Counter-Zeile.
 * - `advanceUserCashBalanceAtomic`: `$inc` + Pre-Image → `{ balanceBefore, balanceAfter }`.
 * - `compensateUserCashBalanceAdvance`: bei fehlgeschlagenem Statement-Save `$inc` mit
 *   negativem Betrag (best effort; Fehler werden auditiert).
 *
 * Nutzt dieselbe `PARSE_SERVER_DATABASE_URI` wie Parse Server (gleicher Prozess).
 */

const { MongoClient } = require('mongodb');
const {
  euroToCents,
  centsToEuro,
  normalizeEuro,
  addCents,
} = require('./moneyCents');
const { audit } = require('../structuredLogger');

let fin1MongoPromise;

function getDatabaseUri() {
  const uri = process.env.PARSE_SERVER_DATABASE_URI;
  if (!uri || typeof uri !== 'string' || !uri.trim()) return null;
  return uri.trim();
}

async function getFin1MongoDb() {
  const uri = getDatabaseUri();
  if (!uri) {
    throw new Error(
      'PARSE_SERVER_DATABASE_URI is missing — atomic UserCashBalance (Phase 3b) cannot run.',
    );
  }
  if (!fin1MongoPromise) {
    fin1MongoPromise = (async () => {
      const client = new MongoClient(uri, { maxPoolSize: 10 });
      await client.connect();
      return { client, db: client.db() };
    })();
  }
  const { client, db } = await fin1MongoPromise;
  return { client, db };
}

async function getUserCashBalanceCollection() {
  const { db } = await getFin1MongoDb();
  return db.collection('UserCashBalance');
}

async function getAccountStatementMongoCollection() {
  const { db } = await getFin1MongoDb();
  return db.collection('AccountStatement');
}

/** Nur für Tests: Mongo-Verbindung schließen. */
async function __resetUserCashBalanceMongoForTests() {
  if (!fin1MongoPromise) return;
  try {
    const { client } = await fin1MongoPromise;
    await client.close();
  } catch {
    // ignore
  }
  fin1MongoPromise = null;
}

/**
 * Legt eine `UserCashBalance`-Zeile an, wenn noch keine existiert, mit `currentBalance`
 * = letztes `AccountStatement.balanceAfter` (oder 0). Idempotent; Duplikat-Save wird
 * ignoriert (paralleles Seed).
 *
 * @param {string} userId
 */
async function ensureUserCashBalanceSeeded(userId) {
  const uid = String(userId || '').trim();
  if (!uid) {
    throw new Error('ensureUserCashBalanceSeeded: userId is required');
  }

  const q = new Parse.Query('UserCashBalance');
  q.equalTo('userId', uid);
  const existing = await q.first({ useMasterKey: true });
  if (existing) return;

  const lastEntry = await new Parse.Query('AccountStatement')
    .equalTo('userId', uid)
    .descending('createdAt')
    .first({ useMasterKey: true });

  const seed = normalizeEuro(lastEntry ? Number(lastEntry.get('balanceAfter') || 0) : 0);

  const row = new Parse.Object('UserCashBalance');
  row.set('userId', uid);
  row.set('currentBalance', seed);
  try {
    await row.save(null, { useMasterKey: true });
  } catch (err) {
    const code = err && err.code;
    const msg = err && err.message ? String(err.message) : '';
    if (code === 137 || code === 11000 || msg.toLowerCase().includes('duplicate')) {
      return;
    }
    throw err;
  }
}

/**
 * @param {{ userId: string, amount: number }} params
 * @returns {Promise<{ balanceBefore: number, balanceAfter: number }>}
 */
async function advanceUserCashBalanceAtomic({ userId, amount }) {
  const uid = String(userId || '').trim();
  if (!uid) {
    throw new Error('advanceUserCashBalanceAtomic: userId is required');
  }
  if (!Number.isFinite(Number(amount))) {
    throw new Error(`advanceUserCashBalanceAtomic: invalid amount (${amount})`);
  }

  const amountCents = euroToCents(Number(amount));
  const amt = centsToEuro(amountCents);

  await ensureUserCashBalanceSeeded(uid);

  const coll = await getUserCashBalanceCollection();
  const result = await coll.findOneAndUpdate(
    { userId: uid },
    { $inc: { currentBalance: amt } },
    { upsert: true, returnDocument: 'before' },
  );

  const prev = result != null && Object.prototype.hasOwnProperty.call(result, 'value')
    ? result.value
    : null;

  let balanceBeforeEuro = 0;
  if (prev && prev.currentBalance !== undefined && prev.currentBalance !== null) {
    const n = Number(prev.currentBalance);
    if (Number.isFinite(n)) balanceBeforeEuro = normalizeEuro(n);
  }

  const balanceBeforeCents = euroToCents(balanceBeforeEuro);
  const balanceAfterCents = addCents(balanceBeforeCents, amountCents);

  return {
    balanceBefore: centsToEuro(balanceBeforeCents),
    balanceAfter: centsToEuro(balanceAfterCents),
  };
}

/**
 * Rollback eines `advance`-Schritts nach fehlgeschlagenem `AccountStatement.save`.
 *
 * @param {{ userId: string, amount: number }} params
 */
async function compensateUserCashBalanceAdvance({ userId, amount }) {
  const uid = String(userId || '').trim();
  if (!uid || !Number.isFinite(Number(amount))) return true;

  const amt = centsToEuro(euroToCents(Number(amount)));

  try {
    const coll = await getUserCashBalanceCollection();
    await coll.findOneAndUpdate(
      { userId: uid },
      { $inc: { currentBalance: -amt } },
      { upsert: false },
    );
    return true;
  } catch (err) {
    audit.error('accountstatement.balance.advanceRollbackFailure', {
      userId: uid,
      amount: amt,
      error: err && err.message ? err.message : String(err),
      message: 'compensateUserCashBalanceAdvance failed after AccountStatement save failure',
    });
    return false;
  }
}

/**
 * Liest den autoritativen Kundensaldo (`UserCashBalance.currentBalance`).
 * Seedet die Zeile bei Bedarf aus dem letzten `AccountStatement`.
 *
 * @param {string} userId
 * @returns {Promise<number>}
 */
async function readUserCashBalanceForUser(userId) {
  const uid = String(userId || '').trim();
  if (!uid) {
    throw new Error('readUserCashBalanceForUser: userId is required');
  }

  await ensureUserCashBalanceSeeded(uid);

  const q = new Parse.Query('UserCashBalance');
  q.equalTo('userId', uid);
  const row = await q.first({ useMasterKey: true });
  return normalizeEuro(row ? Number(row.get('currentBalance') || 0) : 0);
}

module.exports = {
  ensureUserCashBalanceSeeded,
  advanceUserCashBalanceAtomic,
  compensateUserCashBalanceAdvance,
  readUserCashBalanceForUser,
  getDatabaseUri,
  getFin1MongoDb,
  getUserCashBalanceCollection,
  getAccountStatementMongoCollection,
  __resetUserCashBalanceMongoForTests,
};
