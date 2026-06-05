// Shared finance SSOT helpers for mongosh ops scripts (mirror-basis drift, reconcile, backfill).
// Keep in sync with parse-server/cloud/utils/configHelper + accountingHelper/legs.js.
// Loaded via `cat lib + script | mongosh` (see run-finance-integrity-snapshots.sh).

const DEFAULT_COMMISSION_RATE = 0.10;

function round2(n) {
  return Math.round(n * 100) / 100;
}

function isNum(v) {
  return typeof v === 'number' && Number.isFinite(v);
}

function eq2(a, b) {
  return isNum(a) && isNum(b) && Math.abs(round2(a) - round2(b)) < 0.01;
}

function loadCommissionRate() {
  // SSOT order matches Parse `getTraderCommissionRate()`:
  // 1) active Configuration doc, 2) legacy Config.financial, 3) default.
  try {
    const activeCursor = db.getCollection('Configuration')
      .find({ isActive: true })
      .sort({ updatedAt: -1 })
      .limit(1);
    const activeCfg = activeCursor.hasNext() ? activeCursor.next() : null;
    if (activeCfg && isNum(activeCfg.traderCommissionRate)) {
      return activeCfg.traderCommissionRate;
    }
  } catch (e) { /* fall through */ }
  try {
    const configCollection = db.getCollection('Config');
    const cfg = configCollection.findOne({ _id: 'production' }) || configCollection.findOne({});
    if (!cfg) return DEFAULT_COMMISSION_RATE;
    if (cfg.financial && isNum(cfg.financial.traderCommissionRate)) {
      return cfg.financial.traderCommissionRate;
    }
    if (isNum(cfg.traderCommissionRate)) return cfg.traderCommissionRate;
    if (cfg.params && isNum(cfg.params.traderCommissionRate)) return cfg.params.traderCommissionRate;
    if (cfg.params && cfg.params.traderCommissionRate && isNum(cfg.params.traderCommissionRate.value)) {
      return cfg.params.traderCommissionRate.value;
    }
  } catch (e) { /* fall through */ }
  return DEFAULT_COMMISSION_RATE;
}

function resolveCommissionRate(meta) {
  if (meta && isNum(meta.commissionRate)) return meta.commissionRate;
  return loadCommissionRate();
}

function deriveMirrorTradeBasis(buyLeg, sellLeg, commissionRate) {
  if (!buyLeg || !sellLeg) return null;
  const totalBuyCost = round2(
    (buyLeg.amount || 0) + ((buyLeg.fees && buyLeg.fees.totalFees) || 0),
  );
  const netSellAmount = round2(
    (sellLeg.amount || 0) - ((sellLeg.fees && sellLeg.fees.totalFees) || 0),
  );
  const grossProfit = round2(netSellAmount - totalBuyCost);
  const commission = grossProfit > 0 ? round2(grossProfit * commissionRate) : 0;
  const netProfit = round2(grossProfit - commission);
  const returnPercentage = totalBuyCost > 0
    ? round2((netProfit / totalBuyCost) * 100)
    : null;
  return {
    totalBuyCost,
    netSellAmount,
    grossProfit,
    commission,
    netProfit,
    returnPercentage,
  };
}

function writeOpsHealthSnapshot(snapshot) {
  const healthColl = db.getCollection('OpsHealthSnapshot');
  const now = new Date();
  const doc = Object.assign({ runAt: now, updatedAt: now }, snapshot);
  healthColl.replaceOne({ _id: doc._id }, doc, { upsert: true });
  return doc._id;
}
