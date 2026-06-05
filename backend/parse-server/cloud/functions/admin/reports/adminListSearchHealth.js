'use strict';

const { requirePermission } = require('../../../utils/permissions');
const { createAdminListSearchIndexes } = require('../../../utils/schemaMigration/createAdminListSearchIndexes');

async function listIndexNames(collection) {
  const uri = process.env.PARSE_SERVER_DATABASE_URI;
  if (!uri) return { ok: false, error: 'PARSE_SERVER_DATABASE_URI missing' };

  const { MongoClient } = require('mongodb');
  const client = new MongoClient(uri.trim(), { maxPoolSize: 2 });
  await client.connect();
  try {
    const indexes = await client.db().collection(collection).indexes();
    return {
      ok: true,
      names: indexes.map((i) => i.name),
      hasTextOnBlob: indexes.some(
        (i) => i.name && String(i.name).includes('adminSearchBlob_text'),
      ),
      hasPrefixOnBlob: indexes.some(
        (i) => i.key && Object.keys(i.key).length === 1 && i.key.adminSearchBlob === 1,
      ),
    };
  } finally {
    await client.close();
  }
}

async function handleGetAdminListSearchHealth(request) {
  if (!request.master) {
    requirePermission(request, 'getFinancialDashboard');
  }

  const [investment, trade] = await Promise.all([
    listIndexNames('Investment'),
    listIndexNames('Trade'),
  ]);

  const sampleInv = await new Parse.Query('Investment')
    .exists('adminSearchBlob')
    .limit(1)
    .first({ useMasterKey: true })
    .catch(() => null);
  const sampleTrade = await new Parse.Query('Trade')
    .exists('adminSearchBlob')
    .limit(1)
    .first({ useMasterKey: true })
    .catch(() => null);

  const healthy = Boolean(
    investment.ok
    && trade.ok
    && investment.hasTextOnBlob
    && trade.hasTextOnBlob
    && investment.hasPrefixOnBlob
    && trade.hasPrefixOnBlob,
  );

  return {
    healthy,
    investment,
    trade,
    samples: {
      investmentHasBlob: Boolean(sampleInv && sampleInv.get('adminSearchBlob')),
      tradeHasBlob: Boolean(sampleTrade && sampleTrade.get('adminSearchBlob')),
    },
    repairHint: healthy
      ? null
      : 'Run createAdminListSearchIndexes (master) and ./scripts/backfill-trade-summary-flags.sh',
  };
}

async function handleEnsureAdminListSearchIndexes(request) {
  if (!request.master) {
    requirePermission(request, 'getFinancialDashboard');
  }
  return createAdminListSearchIndexes();
}

module.exports = {
  handleGetAdminListSearchHealth,
  handleEnsureAdminListSearchIndexes,
};
