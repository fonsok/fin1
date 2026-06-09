'use strict';

const { getFinancialConfig } = require('../configHelper/index.js');
const { tradeEconomicsSnapshot } = require('./tradeLegEconomics');
const { toPersistedLegEconomics } = require('./legEconomicsPersistShared');

async function resolveFeeConfig(options = {}) {
  if (options.feeConfig) return options.feeConfig;
  return getFinancialConfig();
}

/**
 * Compute domain snapshot and freeze on Trade.legEconomicsSnapshot (write-path SSOT).
 * @returns {boolean} true when snapshot was applied
 */
async function applyLegEconomicsSnapshotToTrade(trade, options = {}) {
  if (!trade?.id && !trade?.get) return false;
  const feeConfig = await resolveFeeConfig(options);
  const snap = tradeEconomicsSnapshot(trade, options.participations || null, {
    feeConfig,
    traderReference: options.traderReference || null,
    applyPoolMirror: Boolean(options.applyPoolMirror),
    preferPersisted: false,
  });
  const persisted = toPersistedLegEconomics(snap);
  if (!persisted) return false;
  trade.set('legEconomicsSnapshot', persisted);
  return true;
}

function mapParticipationsForLegEconomics(participations) {
  if (!Array.isArray(participations)) return [];
  return participations.map((p) => {
    const get = p.get ? (key) => p.get(key) : (key) => p[key];
    const buySnapshot = get('buySnapshot') || null;
    return {
      investmentId: get('investmentId') || '',
      investmentStatus: String(get('investmentStatus') || 'active').toLowerCase(),
      investmentCapital: Number(
        buySnapshot?.investmentAmount
        || get('allocatedAmount')
        || get('investmentCapital')
        || 0,
      ),
      buySnapshot,
      investorId: get('investorId') || '',
    };
  });
}

async function refreshPoolMirrorLegEconomicsPersistence(mirrorTrade, options = {}) {
  if (!mirrorTrade?.id) return false;
  const feeConfig = await resolveFeeConfig(options);

  const parts = await new Parse.Query('PoolTradeParticipation')
    .equalTo('tradeId', mirrorTrade.id)
    .limit(500)
    .find({ useMasterKey: true });
  const participations = mapParticipationsForLegEconomics(parts);
  if (!participations.length) return false;

  let traderReference = options.traderReference || null;
  if (!traderReference) {
    const { getTraderTradeForPairedMirrorLeg } = require('../pairedTradeMirrorSync');
    const traderTrade = await getTraderTradeForPairedMirrorLeg(mirrorTrade);
    if (traderTrade) {
      traderReference = tradeEconomicsSnapshot(traderTrade, null, { feeConfig, preferPersisted: true });
    }
  }

  return applyLegEconomicsSnapshotToTrade(mirrorTrade, {
    feeConfig,
    participations,
    traderReference,
    applyPoolMirror: true,
  });
}

module.exports = {
  applyLegEconomicsSnapshotToTrade,
  mapParticipationsForLegEconomics,
  refreshPoolMirrorLegEconomicsPersistence,
};
