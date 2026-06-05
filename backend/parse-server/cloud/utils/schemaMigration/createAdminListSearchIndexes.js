'use strict';

/**
 * MongoDB text + compound indexes for admin Summary Report lists (self-hosted).
 * Atlas Search is optional; `$text` on `adminSearchBlob` is the SSOT for substring/word search.
 */
async function createAdminListSearchIndexes() {
  const uri = process.env.PARSE_SERVER_DATABASE_URI;
  if (!uri || typeof uri !== 'string' || !uri.trim()) {
    return { ok: false, skipped: true, reason: 'PARSE_SERVER_DATABASE_URI missing' };
  }

  const { MongoClient } = require('mongodb');
  const client = new MongoClient(uri.trim(), { maxPoolSize: 2 });
  await client.connect();

  const results = {};
  try {
    const db = client.db();

    const ensureText = async (collection, indexSpec, name) => {
      try {
        await db.collection(collection).createIndex(indexSpec, {
          name,
          default_language: 'none',
          background: true,
        });
        return 'created';
      } catch (e) {
        const msg = e && e.message ? String(e.message) : '';
        if (msg.includes('already exists') || msg.includes('same name')) return 'already_present';
        throw e;
      }
    };

    const ensureBtree = async (collection, name) => {
      try {
        await db.collection(collection).createIndex(
          { adminSearchBlob: 1 },
          { name, background: true },
        );
        return 'created';
      } catch (e) {
        const msg = e && e.message ? String(e.message) : '';
        if (msg.includes('already exists') || msg.includes('same name')) return 'already_present';
        throw e;
      }
    };

    results.Investment_adminSearchBlob_text = await ensureText(
      'Investment',
      { adminSearchBlob: 'text' },
      'Investment_adminSearchBlob_text',
    );
    results.Trade_adminSearchBlob_text = await ensureText(
      'Trade',
      { adminSearchBlob: 'text' },
      'Trade_adminSearchBlob_text',
    );
    results.Investment_adminSearchBlob_prefix = await ensureBtree(
      'Investment',
      'Investment_adminSearchBlob_prefix',
    );
    results.Trade_adminSearchBlob_prefix = await ensureBtree(
      'Trade',
      'Trade_adminSearchBlob_prefix',
    );

    try {
      await db.collection('Trade').createIndex(
        { hasPoolParticipation: 1, createdAt: -1 },
        { name: 'Trade_poolParticipation_createdAt', background: true },
      );
      results.Trade_poolParticipation_createdAt = 'created';
    } catch (e) {
      const msg = e && e.message ? String(e.message) : '';
      results.Trade_poolParticipation_createdAt = msg.includes('already exists')
        ? 'already_present'
        : `error:${msg}`;
    }

    try {
      await db.collection('Investment').createIndex(
        { status: 1, createdAt: -1 },
        { name: 'Investment_status_createdAt', background: true },
      );
      results.Investment_status_createdAt = 'created';
    } catch (e) {
      const msg = e && e.message ? String(e.message) : '';
      results.Investment_status_createdAt = msg.includes('already exists')
        ? 'already_present'
        : `error:${msg}`;
    }
  } finally {
    await client.close();
  }

  return { ok: true, indexes: results };
}

module.exports = {
  createAdminListSearchIndexes,
};
