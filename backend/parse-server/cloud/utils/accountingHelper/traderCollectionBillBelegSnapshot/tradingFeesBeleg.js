'use strict';

const { round2 } = require('../shared');
const {
  TRADER_COLLECTION_BILL_SCHEMA_VERSION,
  TOLERANCE,
  formatEuroDe,
} = require('./shared');
const { finalizeTraderBelegMetadata } = require('../belegMetadataMoney');

/**
 * GoB companion for `trading_fees` ledger rows — not a Kauf-/Verkaufs-TBC/TSC.
 * Fees are already on buy/sell trader collection bills; this is an internal fee summary Beleg.
 */
function buildTradingFeesBelegSnapshot({
  trade,
  totalFees,
  feeBreakdown,
  label,
  docNumber,
  tradeNumber,
}) {
  const total = round2(Math.abs(Number(totalFees) || 0));
  if (total <= 0) {
    throw new Error('Trading fees beleg snapshot: totalFees must be > 0 (GoB fail-closed)');
  }
  const breakdown = feeBreakdown && typeof feeBreakdown === 'object' ? feeBreakdown : {};
  const fees = {
    orderFee: round2(Number(breakdown.orderFee) || 0),
    exchangeFee: round2(Number(breakdown.exchangeFee) || 0),
    foreignCosts: round2(Number(breakdown.foreignCosts) || 0),
    totalFees: total,
  };
  const sumParts = round2(fees.orderFee + fees.exchangeFee + fees.foreignCosts);
  if (sumParts > 0 && Math.abs(sumParts - total) > TOLERANCE) {
    console.warn(
      `⚠️ Trading fees beleg: breakdown sum €${sumParts} ≠ total €${total} (trade #${tradeNumber})`,
    );
  }

  const metadata = finalizeTraderBelegMetadata({
    belegSchemaVersion: TRADER_COLLECTION_BILL_SCHEMA_VERSION,
    belegKind: 'traderTradingFees',
    belegLabel: label,
    executionType: 'fees',
    symbol: String(trade.get('symbol') || '').trim() || null,
    amount: total,
    fees,
    totalWithFees: total,
    tradeNumber,
    generatedAt: new Date().toISOString(),
  }, { tradeId: trade.id, tradeNumber, docNumber, executionType: 'fees' });

  const lines = [
    label,
    `Belegnummer: ${docNumber}`,
    `Trade Nr.: ${tradeNumber}`,
    '',
    'GEBÜHREN (Handel)',
    fees.orderFee > 0 ? `Ordergebühr: ${formatEuroDe(fees.orderFee)}` : '',
    fees.exchangeFee > 0 ? `Handelsplatzgebühr: ${formatEuroDe(fees.exchangeFee)}` : '',
    fees.foreignCosts > 0 ? `Fremdkostenpauschale: ${formatEuroDe(fees.foreignCosts)}` : '',
    `Σ Gebühren: ${formatEuroDe(-total)}`,
  ];

  return {
    metadata,
    accountingSummaryText: lines.filter((line) => line !== '').join('\n'),
    booking: {
      grossAmount: total,
      totalWithFees: total,
      signedTotal: -total,
      fees,
    },
  };
}

module.exports = {
  buildTradingFeesBelegSnapshot,
};
