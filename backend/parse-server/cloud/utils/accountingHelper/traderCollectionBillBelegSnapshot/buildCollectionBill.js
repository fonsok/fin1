'use strict';

const { round2 } = require('../shared');
const { calculateOrderFees } = require('../../helpers');
const { buildPartialSellSnapshot } = require('./partialSellSnapshot');
const { parseInstrumentFromTrade } = require('../../traderAccountStatementPresentation/instruments');
const {
  formatDeValueDate,
  formatDeClosingDate,
  settlementFromInvoice,
  settlementFromOrderLike,
  securitiesDescriptionFromLineItems,
} = require('../../belegSettlementFields');
const { TRADER_COLLECTION_BILL_SCHEMA_VERSION } = require('./shared');
const {
  formatInstrumentLine,
  orderLikeFromOrder,
  assertTotalWithFees,
} = require('./snapshotHelpers');
const { formatTraderCollectionBillSummaryText } = require('./summaryText');
const { buildTraderStatementCustomerDisplay } = require('../traderStatementCustomerDisplay');
const { finalizeTraderBelegMetadata } = require('../belegMetadataMoney');

/**
 * @param {object} params
 * @param {Parse.Object} params.trade
 * @param {Parse.Object|object} [params.order]
 * @param {'buy'|'sell'} params.executionType
 * @param {number} params.grossAmount — Kurswert (positiv)
 * @param {object} [params.feeConfig]
 * @param {string} params.label — z. B. Kaufabrechnung
 * @param {string} params.docNumber — accountingDocumentNumber
 * @param {number|string} params.tradeNumber
 * @param {Parse.Object} [params.invoice] — optional; Wertpapierzeile aus Invoice bevorzugt
 * @param {{ traderId?: string, traderDisplayName?: string|null, traderUsername?: string|null }} [params.traderParty]
 * @returns {{ metadata: object, accountingSummaryText: string, booking: object }}
 */
function buildTraderCollectionBillBelegSnapshot({
  trade,
  order,
  executionType,
  grossAmount,
  feeConfig,
  label,
  docNumber,
  tradeNumber,
  invoice,
  traderParty,
}) {
  const ex = String(executionType || 'buy').toLowerCase();
  if (ex !== 'buy' && ex !== 'sell') {
    throw new Error(`Trader collection bill snapshot: invalid executionType "${executionType}"`);
  }

  const gross = round2(Math.abs(Number(grossAmount) || 0));
  if (gross <= 0) {
    throw new Error('Trader collection bill snapshot: grossAmount must be > 0 (GoB fail-closed)');
  }

  const orderLike = orderLikeFromOrder(order, trade, ex);
  const feesCalc = calculateOrderFees(gross, true, feeConfig || trade.get('feeConfig') || {});
  const fees = {
    orderFee: round2(feesCalc.orderFee || 0),
    exchangeFee: round2(feesCalc.exchangeFee || 0),
    foreignCosts: round2(feesCalc.foreignCosts || 0),
    totalFees: round2(feesCalc.totalFees || 0),
  };
  const totalWithFees = ex === 'buy'
    ? round2(gross + fees.totalFees)
    : round2(Math.max(0, gross - fees.totalFees));
  assertTotalWithFees(ex, gross, fees, totalWithFees, { tradeId: trade.id, docNumber });

  const qty = Number(
    orderLike.quantity
    || trade.get('quantity')
    || 0,
  );
  const price = Number(orderLike.price || 0);
  const symbol = String(trade.get('symbol') || orderLike.wkn || '').trim();

  let instrumentLine = '';
  if (invoice) {
    const fromInv = settlementFromInvoice(invoice);
    instrumentLine = fromInv.instrumentLine
      || securitiesDescriptionFromLineItems(invoice.get('lineItems'));
  }
  if (!instrumentLine) {
    instrumentLine = formatInstrumentLine(parseInstrumentFromTrade(trade, order || null));
  }

  const settlement = invoice
    ? settlementFromInvoice(invoice)
    : settlementFromOrderLike(orderLike);
  const bookedAt = orderLike.executedAt
    || orderLike.createdAt
    || trade.get('createdAt')
    || new Date();
  const tradingVenue = settlement.tradingVenue
    || (fees.exchangeFee > 0 ? 'XETRA' : null);
  const valueDate = settlement.valueDate || formatDeValueDate(bookedAt);
  const closingDate = settlement.closingDate || formatDeClosingDate(bookedAt);

  const party = traderParty && typeof traderParty === 'object' ? traderParty : {};
  const traderIdSnap = String(party.traderId || '').trim() || null;
  const traderDisplayNameSnap = String(party.traderDisplayName || '').trim() || null;
  const traderUsernameSnap = String(party.traderUsername || '').trim() || null;

  const buyQty = Number(trade.get('quantity') || trade.get('buyOrder')?.quantity || 0);
  const tradeStatus = String(trade.get('status') || '');
  const sellOrderId = String(
    orderLike.id || order?.id || order?.objectId || order?.orderId || '',
  ).trim() || null;
  const partialSellContext = ex === 'sell'
    ? buildPartialSellSnapshot({
      trade,
      order,
      orderLike,
      sellOrderId,
      buyQty,
      tradeStatus,
    })
    : { isPartialSell: false, partialSell: null };
  const isPartialSell = partialSellContext.isPartialSell;

  const metadata = finalizeTraderBelegMetadata({
    belegSchemaVersion: TRADER_COLLECTION_BILL_SCHEMA_VERSION,
    belegKind: 'traderCollectionBill',
    belegLabel: label,
    traderId: traderIdSnap,
    traderDisplayName: traderDisplayNameSnap,
    traderUsername: traderUsernameSnap,
    executionType: ex,
    symbol: symbol || null,
    instrumentLine: instrumentLine || null,
    amount: gross,
    quantity: qty > 0 ? qty : null,
    price: price > 0 ? price : null,
    orderId: orderLike.id || order?.id || order?.objectId || null,
    sellOrderId,
    wkn: orderLike.wkn || symbol || null,
    fees,
    totalWithFees,
    valueDate,
    closingDate,
    tradingVenue,
    tradeNumber,
    tradeStatus: tradeStatus || null,
    generatedAt: new Date().toISOString(),
    ...(partialSellContext.partialSell ? { partialSell: partialSellContext.partialSell } : {}),
  }, { tradeId: trade.id, tradeNumber, docNumber, executionType: ex });

  const accountingSummaryText = formatTraderCollectionBillSummaryText({
    label,
    docNumber,
    tradeNumber,
    metadata,
  });

  const customerDisplay = buildTraderStatementCustomerDisplay({
    trade,
    order,
    orderLike,
    executionType: ex,
    metadata,
  });

  return {
    metadata,
    accountingSummaryText,
    customerDisplay,
    booking: {
      grossAmount: gross,
      totalWithFees,
      signedTotal: ex === 'buy' ? -totalWithFees : totalWithFees,
      fees,
    },
  };
}

module.exports = {
  buildTraderCollectionBillBelegSnapshot,
};
