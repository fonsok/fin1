'use strict';

/**
 * Investor position amount — display resolution (NOT ledger line items).
 *
 * GoB monetary SSOT hierarchy (see Documentation/BOOKING_AND_BELEG_SSOT.md):
 *   1. Collection Bill `metadata.totalBuyCost` (settled / partial-sell — same as Ledger settlement)
 *   2. `Investment.poolTradingAmount` (post-activation snapshot — same as RSV→PTR escrow split)
 *   3. `Investment.amount` (reserved nominal — same as reserve escrow leg)
 *
 * App Ledger / Account Statement show **individual booking legs** (reserve, deploy, payout, …).
 * Summary Report & investment tables show **one position amount** per investment using this module.
 */

const DISPLAY_AMOUNT_EPSILON = 0.005;

function bookedTotalBuyCostFromMetadata(metadata = {}) {
  const fromTotal = Number(metadata.totalBuyCost);
  if (Number.isFinite(fromTotal) && fromTotal > DISPLAY_AMOUNT_EPSILON) {
    return fromTotal;
  }
  const fromPool = Number(metadata.poolTradingAmount);
  if (Number.isFinite(fromPool) && fromPool > DISPLAY_AMOUNT_EPSILON) {
    return fromPool;
  }
  const nominal = Number(metadata.investmentNominal);
  const residual = Number(metadata.residualAmount);
  if (Number.isFinite(nominal) && Number.isFinite(residual)) {
    const activeAmount = nominal - residual;
    if (activeAmount > DISPLAY_AMOUNT_EPSILON) {
      return activeAmount;
    }
  }
  return 0;
}

function resolveInvestmentDisplayAmountFromFields(fields = {}) {
  const nominal = Number(fields.amount) || 0;
  const status = String(fields.status || '').trim().toLowerCase();
  const reservationStatus = String(fields.reservationStatus || '').trim().toLowerCase();
  const isReserved = status === 'reserved' || reservationStatus === 'reserved';
  if (isReserved) {
    return nominal;
  }
  const poolTradingAmount = Number(fields.poolTradingAmount) || 0;
  if (poolTradingAmount > DISPLAY_AMOUNT_EPSILON) {
    return poolTradingAmount;
  }
  return nominal;
}

function resolveInvestmentPositionAmountFromFields(fields = {}) {
  const nominal = Number(fields.amount) || 0;
  const status = String(fields.status || '').trim().toLowerCase();
  const reservationStatus = String(fields.reservationStatus || '').trim().toLowerCase();
  const isReserved = status === 'reserved' || reservationStatus === 'reserved';
  if (isReserved) {
    return nominal;
  }
  const canonicalTotalBuyCost = Number(fields.canonicalTotalBuyCost) || 0;
  if (canonicalTotalBuyCost > DISPLAY_AMOUNT_EPSILON) {
    return canonicalTotalBuyCost;
  }
  return resolveInvestmentDisplayAmountFromFields(fields);
}

function resolveInvestmentDisplayAmount(inv) {
  return resolveInvestmentDisplayAmountFromFields({
    amount: inv.get('amount'),
    status: inv.get('status'),
    reservationStatus: inv.get('reservationStatus'),
    poolTradingAmount: inv.get('poolTradingAmount'),
  });
}

function resolveInvestmentPositionAmount(inv, canonicalTotalBuyCost = null) {
  return resolveInvestmentPositionAmountFromFields({
    amount: inv.get('amount'),
    status: inv.get('status'),
    reservationStatus: inv.get('reservationStatus'),
    poolTradingAmount: inv.get('poolTradingAmount'),
    canonicalTotalBuyCost,
  });
}

function investmentReservedMongoExpression() {
  const statusLower = { $toLower: { $ifNull: ['$status', ''] } };
  const reservationLower = { $toLower: { $ifNull: ['$reservationStatus', ''] } };
  return {
    $or: [
      { $eq: [statusLower, 'reserved'] },
      { $eq: [reservationLower, 'reserved'] },
    ],
  };
}

function activatedInvestmentAmountMongoExpression() {
  const nominal = { $ifNull: ['$amount', 0] };
  const poolTradingAmount = { $ifNull: ['$poolTradingAmount', 0] };
  return {
    $cond: [
      { $gt: [poolTradingAmount, DISPLAY_AMOUNT_EPSILON] },
      poolTradingAmount,
      nominal,
    ],
  };
}

/** Mongo `$addFields` — tiers 2/3 only (no Collection Bill join). */
function investmentDisplayAmountMongoExpression() {
  return {
    $cond: [
      investmentReservedMongoExpression(),
      { $ifNull: ['$amount', 0] },
      activatedInvestmentAmountMongoExpression(),
    ],
  };
}

function metadataBookedTotalBuyCostMongoExpr(metaExpr) {
  return {
    $let: {
      vars: { meta: metaExpr },
      in: {
        $cond: [
          { $gt: [{ $ifNull: ['$$meta.totalBuyCost', 0] }, DISPLAY_AMOUNT_EPSILON] },
          { $ifNull: ['$$meta.totalBuyCost', 0] },
          {
            $cond: [
              { $gt: [{ $ifNull: ['$$meta.poolTradingAmount', 0] }, DISPLAY_AMOUNT_EPSILON] },
              { $ifNull: ['$$meta.poolTradingAmount', 0] },
              {
                $let: {
                  vars: {
                    active: {
                      $subtract: [
                        { $ifNull: ['$$meta.investmentNominal', 0] },
                        { $ifNull: ['$$meta.residualAmount', 0] },
                      ],
                    },
                  },
                  in: {
                    $cond: [{ $gt: ['$$active', DISPLAY_AMOUNT_EPSILON] }, '$$active', 0],
                  },
                },
              },
            ],
          },
        ],
      },
    },
  };
}

/** Sum booked buy-side amounts from joined Collection Bill documents. */
function sumCollectionBillTotalBuyCostMongoExpr(billsField = '$collectionBills') {
  return {
    $reduce: {
      input: { $ifNull: [billsField, []] },
      initialValue: 0,
      in: {
        $add: [
          '$$value',
          metadataBookedTotalBuyCostMongoExpr({ $ifNull: ['$$this.metadata', {}] }),
        ],
      },
    },
  };
}

/** Full position amount — requires `canonicalTotalBuyCost` field (e.g. after `$lookup`). */
function investmentPositionAmountMongoExpression(
  canonicalTotalBuyCostField = '$canonicalTotalBuyCost',
) {
  const canonical = { $ifNull: [canonicalTotalBuyCostField, 0] };
  return {
    $cond: [
      investmentReservedMongoExpression(),
      { $ifNull: ['$amount', 0] },
      {
        $cond: [
          { $gt: [canonical, DISPLAY_AMOUNT_EPSILON] },
          canonical,
          activatedInvestmentAmountMongoExpression(),
        ],
      },
    ],
  };
}

const COLLECTION_BILL_TYPES = ['investorCollectionBill', 'investor_collection_bill'];

/** `$lookup` investor Collection Bills for each Investment row (Summary Report overview KPI). */
function investmentCollectionBillsLookupStage() {
  return {
    $lookup: {
      from: 'Document',
      let: { invId: '$_id' },
      pipeline: [
        {
          $match: {
            $expr: {
              $and: [
                { $eq: [{ $toString: '$investmentId' }, { $toString: '$$invId' }] },
                { $in: ['$type', COLLECTION_BILL_TYPES] },
              ],
            },
          },
        },
        { $project: { metadata: 1 } },
      ],
      as: 'collectionBills',
    },
  };
}

module.exports = {
  DISPLAY_AMOUNT_EPSILON,
  COLLECTION_BILL_TYPES,
  bookedTotalBuyCostFromMetadata,
  resolveInvestmentDisplayAmountFromFields,
  resolveInvestmentPositionAmountFromFields,
  resolveInvestmentDisplayAmount,
  resolveInvestmentPositionAmount,
  investmentReservedMongoExpression,
  activatedInvestmentAmountMongoExpression,
  investmentDisplayAmountMongoExpression,
  metadataBookedTotalBuyCostMongoExpr,
  sumCollectionBillTotalBuyCostMongoExpr,
  investmentPositionAmountMongoExpression,
  investmentCollectionBillsLookupStage,
};
