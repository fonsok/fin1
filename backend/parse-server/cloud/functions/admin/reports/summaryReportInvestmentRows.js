'use strict';

// SSOT: returnPercentage comes from the canonical CollectionBill metadata (ROI2).
// If no bill is present yet (active/ongoing investment, or pre-settlement), we fall
// back to the ROI2 formula `((grossProfit − commission) / amount) × 100` — identical
// to the formula used by `computeCollectionBillReturnPercentage`.
// See: Documentation/RETURN_CALCULATION_SCHEMAS.md and
// Documentation/ADR-006-Server-Owned-Return-Percentage-Contract.md

function mapInvestmentRow(inv, commissionRate, canonicalReturnByInvestmentId = null) {
  const amount = inv.get('amount') || 0;
  const currentValue = inv.get('currentValue') || amount;
  const grossProfit = currentValue - amount;
  const commission = grossProfit > 0 ? grossProfit * commissionRate : 0;
  const netProfit = grossProfit - commission;

  const canonicalReturn =
    canonicalReturnByInvestmentId && typeof canonicalReturnByInvestmentId[inv.id] === 'number'
      ? canonicalReturnByInvestmentId[inv.id]
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

// Loads canonical `metadata.returnPercentage` from investorCollectionBill documents
// for a batch of investment IDs. If an investment has multiple bills, we compute the
// weighted average by buyLeg invested amount (matches ServerCalculatedReturnResolver).
async function loadCanonicalReturnByInvestmentId(investmentIds) {
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
    const pct = metadata.returnPercentage;
    if (typeof pct !== 'number' || !Number.isFinite(pct)) continue;
    const invId = d.get('investmentId');
    if (!invId) continue;
    const buyAmount = metadata.buyLeg?.amount || 0;
    const buyFees = metadata.buyLeg?.fees?.totalFees || 0;
    const invested = buyAmount + buyFees;
    if (!buckets[invId]) buckets[invId] = { weighted: 0, invested: 0, sum: 0, count: 0 };
    const bucket = buckets[invId];
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
    if (b.invested > 0) {
      result[invId] = b.weighted / b.invested;
    } else if (b.count > 0) {
      result[invId] = b.sum / b.count;
    }
  }
  return result;
}

module.exports = {
  mapInvestmentRow,
  loadCanonicalReturnByInvestmentId,
};
