'use strict';

const { round2 } = require('../shared');
const { formatDeClosingDate } = require('../../belegSettlementFields');
const { formatEuroDe } = require('./shared');

function formatTraderCollectionBillSummaryText({ label, docNumber, tradeNumber, metadata }) {
  const ex = String(metadata.executionType || 'buy').toLowerCase();
  const section = ex === 'sell' ? 'VERKAUF' : 'KAUF';
  const wertpapier = String(metadata.instrumentLine || '').trim()
    || (metadata.symbol ? String(metadata.symbol) : '');
  const fees = metadata.fees || {};
  const traderLine = String(metadata.traderDisplayName || '').trim();
  const lines = [
    label,
    `Belegnummer: ${docNumber}`,
    `Trade Nr.: ${tradeNumber}`,
    traderLine ? `Trader: ${traderLine}` : '',
    '',
    section,
    wertpapier ? `Wertpapier: ${wertpapier}` : '',
    metadata.quantity > 0 ? `Ordervolumen: ${metadata.quantity} St.` : '',
    metadata.quantity > 0 ? `davon ausgef.: ${metadata.quantity} St.` : '',
    metadata.price > 0 ? `Kurs (Ask): ${formatEuroDe(metadata.price)}` : '',
    metadata.amount > 0 ? `Kurswert: ${formatEuroDe(metadata.amount)}` : '',
    '',
    fees.orderFee > 0 ? `Ordergebühr: ${formatEuroDe(fees.orderFee)}` : '',
    fees.exchangeFee > 0 ? `Handelsplatzgebühr: ${formatEuroDe(fees.exchangeFee)}` : '',
    fees.foreignCosts > 0 ? `Fremdkostenpauschale: ${formatEuroDe(fees.foreignCosts)}` : '',
    fees.totalFees > 0 && !fees.orderFee ? `Gebühren gesamt: ${formatEuroDe(fees.totalFees)}` : '',
    '',
    `Σ ${section}: ${formatEuroDe(ex === 'buy' ? -metadata.totalWithFees : metadata.totalWithFees)}`,
    ...(metadata.partialSell?.isPartialSell
      ? [
        '',
        'TEILVERKAUF',
        metadata.partialSell.eventIndex != null && metadata.partialSell.totalSellEvents != null
          ? `Reihenfolge: Teilverkauf ${metadata.partialSell.eventIndex} von ${metadata.partialSell.totalSellEvents}`
          : (metadata.partialSell.eventIndex != null
            ? `Reihenfolge: Teilverkauf #${metadata.partialSell.eventIndex}`
            : ''),
        metadata.partialSell.executedAt
          ? `Ausgeführt am: ${formatDeClosingDate(metadata.partialSell.executedAt)}`
          : '',
        metadata.partialSell.sellOrderId
          ? `Verkaufsorder: ${metadata.partialSell.sellOrderId}`
          : '',
        metadata.partialSell.orderQuantity > 0
          ? `Dieser Verkauf: ${metadata.partialSell.orderQuantity} St.`
          : '',
        metadata.partialSell.cumulativeSoldQuantity > 0 && metadata.partialSell.buyQuantity > 0
          ? `Verkauft (kumulativ): ${metadata.partialSell.cumulativeSoldQuantity} von ${metadata.partialSell.buyQuantity} St.`
          : '',
        metadata.partialSell.remainingQuantity != null
          ? `Verbleibend: ${metadata.partialSell.remainingQuantity} St.`
          : '',
        metadata.partialSell.sellVolumeProgress != null
          ? `Fortschritt: ${round2(metadata.partialSell.sellVolumeProgress * 100).toFixed(1)} %`
          : '',
      ].filter(Boolean)
      : []),
    metadata.valueDate ? `Valuta: ${metadata.valueDate}` : '',
    metadata.closingDate ? `Schlusstag: ${metadata.closingDate}` : '',
    metadata.tradingVenue ? `Handelsplatz: ${metadata.tradingVenue}` : '',
  ];
  return lines.filter((line) => line !== '').join('\n');
}

module.exports = {
  formatTraderCollectionBillSummaryText,
};
