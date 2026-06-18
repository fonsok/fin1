'use strict';

const {
  resolveInvestmentPositionAmount,
  bookedTotalBuyCostFromMetadata,
} = require('../../../utils/investmentDisplayAmount');

// SSOT: returnPercentage comes from the canonical CollectionBill metadata (ROI2).
// Position amount: resolveInvestmentPositionAmount (Beleg totalBuyCost → poolTradingAmount → nominal).
// See: Documentation/BOOKING_AND_BELEG_SSOT.md, RETURN_CALCULATION_SCHEMAS.md, ADR-006.

function mapInvestmentRow(inv, commissionRate, canonicalByInvestmentId = null) {
  const canonical = canonicalByInvestmentId?.[inv.id];
  const amount = resolveInvestmentPositionAmount(inv, canonical?.totalBuyCost);
  const currentValue = inv.get('currentValue') || amount;
  const grossProfit = currentValue - amount;
  const commission = grossProfit > 0 ? grossProfit * commissionRate : 0;
  const netProfit = grossProfit - commission;

  const canonicalReturn =
    canonical && typeof canonical.returnPercentage === 'number'
      ? canonical.returnPercentage
      : null;
  const fallbackReturn = amount > 0 ? (netProfit / amount) * 100 : 0;
  const returnPercentage = canonicalReturn != null ? canonicalReturn : fallbackReturn;

  return {
    investmentId: inv.id,
    investmentNumber: inv.get('investmentNumber') || inv.id.substring(0, 8),
    investorId: inv.get('investorId') || '',
    investorName: inv.get('investorName') || 'N/A',
    traderId: inv.get('traderId') || '',
    traderName: inv.get('traderName') || 'N/A',
    amount,
    currentValue,
    grossProfit,
    returnPercentage,
    commission,
    status: inv.get('status') || 'unknown',
    createdAt: inv.get('createdAt'),
  };
}

/**
 * Loads Collection Bill canonical metrics per investment (single batch query).
 * Matches iOS `ServerCalculatedReturnResolver` aggregation rules.
 */
async function loadCanonicalBillMetricsByInvestmentId(investmentIds) {
  if (!Array.isArray(investmentIds) || investmentIds.length === 0) {
    return {};
  }
  const query = new Parse.Query('Document');
  query.containedIn('type', ['investorCollectionBill', 'investor_collection_bill']);
  query.containedIn('investmentId', investmentIds);
  query.limit(Math.max(1000, investmentIds.length * 5));
  const docs = await query.find({ useMasterKey: true });

  const buckets = {};
  for (const d of docs) {
    const metadata = d.get('metadata') || {};
    const invId = d.get('investmentId');
    if (!invId) continue;

    if (!buckets[invId]) {
      buckets[invId] = {
        weighted: 0,
        invested: 0,
        sum: 0,
        count: 0,
        totalBuyCost: 0,
      };
    }
    const bucket = buckets[invId];

    const bookedBuy = bookedTotalBuyCostFromMetadata(metadata);
    if (bookedBuy > 0.005) {
      bucket.totalBuyCost += bookedBuy;
    }

    const pct = metadata.returnPercentage;
    if (typeof pct !== 'number' || !Number.isFinite(pct)) continue;

    const buyAmount = metadata.buyLeg?.amount || 0;
    const buyFees = metadata.buyLeg?.fees?.totalFees || 0;
    const invested = buyAmount + buyFees;
    if (invested > 0) {
      bucket.weighted += pct * invested;
      bucket.invested += invested;
    } else {
      bucket.sum += pct;
      bucket.count += 1;
    }
  }

  const result = {};
  for (const invId of Object.keys(buckets)) {
    const b = buckets[invId];
    let returnPercentage;
    if (b.invested > 0) {
      returnPercentage = b.weighted / b.invested;
    } else if (b.count > 0) {
      returnPercentage = b.sum / b.count;
    }
    result[invId] = {
      ...(returnPercentage != null ? { returnPercentage } : {}),
      ...(b.totalBuyCost > 0.005 ? { totalBuyCost: b.totalBuyCost } : {}),
    };
  }
  return result;
}

/** @deprecated Use loadCanonicalBillMetricsByInvestmentId — kept for tests. */
async function loadCanonicalReturnByInvestmentId(investmentIds) {
  const metrics = await loadCanonicalBillMetricsByInvestmentId(investmentIds);
  const result = {};
  for (const [invId, row] of Object.entries(metrics)) {
    if (typeof row.returnPercentage === 'number') {
      result[invId] = row.returnPercentage;
    }
  }
  return result;
}

module.exports = {
  mapInvestmentRow,
  loadCanonicalBillMetricsByInvestmentId,
  loadCanonicalReturnByInvestmentId,
};
