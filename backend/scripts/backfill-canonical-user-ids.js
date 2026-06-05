#!/usr/bin/env node
/* eslint-disable no-console */
//
// Backfill legacy person keys `user:email@test.com` → Parse `_User.objectId` on
// all fachlichen FK fields. Run once per environment after deploying write guards.
//
// Usage:
//   MONGO_URL='mongodb://...' node backend/scripts/backfill-canonical-user-ids.js
//   APPLY=1 MONGO_URL='...' node backend/scripts/backfill-canonical-user-ids.js
//
// On server (parse-server container has mongodb in node_modules under /app):
//   docker exec -e APPLY=1 -e MONGO_URL='mongodb://admin:PASS@mongodb:27017/fin1?authSource=admin' \
//     fin1-parse-server node /app/scripts/backfill-canonical-user-ids.js

'use strict';

const { MongoClient } = require('mongodb');

const mongoUrl = process.env.MONGO_URL
  || 'mongodb://admin:QgQl3nnPdIuA7ZxIq9IviL3OItM5FLTI@localhost:27017/fin1?authSource=admin';
const apply = process.env.APPLY === '1' || process.env.APPLY === 'true';

const USER_FIELD_UPDATES = [
  { collection: 'Investment', field: 'investorId' },
  { collection: 'AppLedgerEntry', field: 'userId' },
  { collection: 'AccountStatement', field: 'userId' },
  { collection: 'Invoice', field: 'userId' },
  { collection: 'Invoice', field: 'investorId' },
  { collection: 'Document', field: 'userId' },
  { collection: 'BankContraPosting', field: 'investorId' },
  { collection: 'WalletTransaction', field: 'userId' },
  { collection: 'Notification', field: 'userId' },
  { collection: 'PoolTradeParticipation', field: 'investorId' },
];

function isLegacyUserKey(value) {
  return typeof value === 'string' && value.startsWith('user:') && value.includes('@');
}

async function buildEmailToObjectIdMap(db) {
  const map = new Map();
  const users = await db.collection('_User').find(
    { email: { $type: 'string' } },
    { projection: { email: 1 } },
  ).toArray();
  for (const u of users) {
    const email = String(u.email || '').trim().toLowerCase();
    if (!email) continue;
    const oid = String(u._id);
    map.set(`user:${email}`, oid);
    map.set(email, oid);
  }
  return map;
}

async function countLegacy(db, spec, map) {
  const filter = { [spec.field]: { $regex: /^user:/ } };
  const rows = await db.collection(spec.collection).find(filter, { projection: { [spec.field]: 1 } }).toArray();
  let mappable = 0;
  let orphan = 0;
  for (const row of rows) {
    const raw = row[spec.field];
    if (map.has(String(raw).toLowerCase()) || map.has(String(raw))) {
      mappable += 1;
    } else {
      orphan += 1;
    }
  }
  return { total: rows.length, mappable, orphan };
}

async function backfillCollection(db, spec, map) {
  const filter = { [spec.field]: { $regex: /^user:/ } };
  const cursor = db.collection(spec.collection).find(filter);
  let scanned = 0;
  let updated = 0;
  let skipped = 0;
  const bulk = [];

  while (await cursor.hasNext()) {
    const row = await cursor.next();
    scanned += 1;
    const raw = String(row[spec.field] || '');
    const canonical = map.get(raw.toLowerCase()) || map.get(raw);
    if (!canonical) {
      skipped += 1;
      continue;
    }
    if (canonical === raw) continue;
    bulk.push({
      updateOne: {
        filter: { _id: row._id },
        update: { $set: { [spec.field]: canonical } },
      },
    });
    if (bulk.length >= 500) {
      if (apply) await db.collection(spec.collection).bulkWrite(bulk, { ordered: false });
      updated += bulk.length;
      bulk.length = 0;
    }
  }
  if (bulk.length > 0) {
    if (apply) await db.collection(spec.collection).bulkWrite(bulk, { ordered: false });
    updated += bulk.length;
  }
  return { scanned, updated, skipped };
}

async function backfillSequenceCounters(db, map) {
  const filter = { key: { $regex: /user:[^@]+@[^@]+/ } };
  const rows = await db.collection('SequenceCounter').find(filter).toArray();
  let updated = 0;
  for (const row of rows) {
    const key = String(row.key || '');
    const match = key.match(/user:([^@]+@[^@]+)$/);
    if (!match) continue;
    const legacy = `user:${match[1].toLowerCase()}`;
    const canonical = map.get(legacy);
    if (!canonical) continue;
    const newKey = key.replace(/user:[^@]+@[^@]+$/, canonical);
    if (newKey === key) continue;
    console.log(`  SequenceCounter: ${key} → ${newKey}`);
    if (apply) {
      await db.collection('SequenceCounter').updateOne(
        { _id: row._id },
        { $set: { key: newKey } },
      );
    }
    updated += 1;
  }
  return updated;
}

async function backfillUserStableId(db) {
  const users = await db.collection('_User').find({}).toArray();
  let updated = 0;
  for (const u of users) {
    const oid = String(u._id);
    const stable = u.stableId;
    if (stable === oid) continue;
    if (isLegacyUserKey(stable) || !stable) {
      if (apply) {
        await db.collection('_User').updateOne({ _id: u._id }, { $set: { stableId: oid } });
      }
      updated += 1;
    }
  }
  return updated;
}

async function main() {
  console.log(`Mode: ${apply ? 'APPLY' : 'DRY-RUN (set APPLY=1 to write)'}`);
  const client = new MongoClient(mongoUrl);
  await client.connect();
  const db = client.db();
  const map = await buildEmailToObjectIdMap(db);
  console.log(`Resolved ${map.size / 2} users (email → objectId)\n`);

  for (const spec of USER_FIELD_UPDATES) {
    const label = `${spec.collection}.${spec.field}`;
    const counts = await countLegacy(db, spec, map);
    console.log(`${label}: legacy=${counts.total} mappable=${counts.mappable} orphan=${counts.orphan}`);
    if (counts.mappable > 0) {
      const result = await backfillCollection(db, spec, map);
      console.log(`  → scanned=${result.scanned} wouldUpdate=${result.updated} skipped=${result.skipped}`);
    }
  }

  const seq = await backfillSequenceCounters(db, map);
  console.log(`\nSequenceCounter keys rewritten: ${seq}`);
  const users = await backfillUserStableId(db);
  console.log(`_User.stableId aligned to objectId: ${users}`);

  await client.close();
  console.log('\nDone.');
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
