'use strict';

const { round2 } = require('../../../utils/accountingHelper/shared');
const { TRADER_COLLECTION_BILL_SCHEMA_VERSION } = require('../../../utils/accountingHelper/traderCollectionBillBelegSnapshot');
const { calculateOrderFees } = require('../../../utils/helpers');
const { parseInstrumentFromTrade } = require('../../../utils/traderAccountStatementPresentation');
const {
  settlementFromInvoice,
  settlementFromOrderLike,
} = require('../../../utils/belegSettlementFields');

function formatInstrumentLine(instrument) {
  const parts = [];
  if (instrument.wknOrIsin) parts.push(instrument.wknOrIsin);
  if (instrument.securitiesDirection) parts.push(instrument.securitiesDirection);
  if (instrument.underlyingAsset) parts.push(instrument.underlyingAsset);
  if (instrument.strikePrice) parts.push(`${instrument.strikePrice} Pkt.`);
  if (instrument.issuer) parts.push(instrument.issuer);
  return parts.join(' - ');
}

function feesAreMissing(meta) {
  const fees = meta.fees;
  if (!fees || typeof fees !== 'object') return true;
  const total = round2(Number(fees.totalFees) || 0);
  const order = round2(Number(fees.orderFee) || 0);
  const exchange = round2(Number(fees.exchangeFee) || 0);
  const foreign = round2(Number(fees.foreignCosts) || 0);
  return total <= 0 && order <= 0 && exchange <= 0 && foreign <= 0;
}

function settlementIsMissing(meta) {
  return !String(meta.valueDate || '').trim()
    && !String(meta.closingDate || '').trim()
    && !String(meta.tradingVenue || '').trim();
}

async function loadTradeInvoice(tradeId, executionType) {
  const q = new Parse.Query('Invoice');
  q.equalTo('tradeId', tradeId);
  if (String(executionType).toLowerCase() === 'sell') {
    q.containedIn('invoiceType', ['sell_invoice', 'sell']);
  } else {
    q.containedIn('invoiceType', ['buy_invoice', 'buy']);
  }
  q.descending('invoiceDate');
  q.limit(1);
  return q.first({ useMasterKey: true });
}

function mergeSettlement(meta, settlement) {
  if (!settlement || typeof settlement !== 'object') return;
  if (!String(meta.instrumentLine || '').trim() && settlement.instrumentLine) {
    meta.instrumentLine = settlement.instrumentLine;
  }
  if (!String(meta.valueDate || '').trim() && settlement.valueDate) {
    meta.valueDate = settlement.valueDate;
  }
  if (!String(meta.closingDate || '').trim() && settlement.closingDate) {
    meta.closingDate = settlement.closingDate;
  }
  if (!String(meta.tradingVenue || '').trim() && settlement.tradingVenue) {
    meta.tradingVenue = settlement.tradingVenue;
  }
}

/**
 * Ergänzt Trader-Collection-Bill-Metadaten aus Trade/Invoice (wie iOS TradeStatement),
 * ohne den Parse-Datensatz zu mutieren. Keine hardcodierten Depot-/Lager-Platzhalter.
 */
async function enrichTraderDocumentMetadata(doc) {
  const type = String(doc.get('type') || '');
  if (type !== 'traderCollectionBill' && type !== 'trade_execution_document') {
    return doc.get('metadata') || {};
  }

  const meta = { ...(doc.get('metadata') || {}) };
  const tradeId = String(doc.get('tradeId') || '').trim();
  if (!tradeId) return meta;

  const executionType = String(meta.executionType || 'buy').toLowerCase();
  const needsInstrument = !String(meta.instrumentLine || '').trim();
  const needsFees = feesAreMissing(meta);
  const needsQty = meta.quantity == null || Number(meta.quantity) <= 0;
  const needsPrice = !(Number(meta.price) > 0);
  const needsSettlement = settlementIsMissing(meta);

  if (!needsInstrument && !needsFees && !needsQty && !needsPrice && !needsSettlement) {
    return meta;
  }

  try {
    const invoice = await loadTradeInvoice(tradeId, executionType);
    if (invoice) {
      mergeSettlement(meta, settlementFromInvoice(invoice));
    }
  } catch {
    // Invoice optional
  }

  try {
    const trade = await new Parse.Query('Trade').get(tradeId, { useMasterKey: true });
    const buyOrder = trade.get('buyOrder') || {};
    const orderLike = executionType === 'sell'
      ? (trade.get('sellOrder') || (trade.get('sellOrders') || [])[0] || buyOrder)
      : buyOrder;

    if (needsSettlement) {
      mergeSettlement(meta, settlementFromOrderLike(orderLike));
    }

    if (needsInstrument && !String(meta.instrumentLine || '').trim()) {
      const instrument = parseInstrumentFromTrade(trade, null);
      const line = formatInstrumentLine(instrument);
      if (line) meta.instrumentLine = line;
      if (!meta.symbol && instrument.wknOrIsin) meta.symbol = instrument.wknOrIsin;
    }

    if (needsQty) {
      const qty = Number(
        meta.quantity
        || trade.get('quantity')
        || orderLike.quantity
        || orderLike.executedQuantity
        || 0,
      );
      if (qty > 0) meta.quantity = qty;
    }

    if (needsPrice) {
      const price = Number(meta.price || orderLike.price || 0);
      if (price > 0) meta.price = price;
    }

    const grossAmount = round2(
      Number(meta.amount) > 0
        ? meta.amount
        : Math.abs(Number(orderLike.totalAmount || orderLike.amount || trade.get('buyAmount') || 0)),
    );
    if (grossAmount > 0 && !Number(meta.amount)) {
      meta.amount = grossAmount;
    }

    if (needsFees && grossAmount > 0) {
      const feeConfig = trade.get('feeConfig') || {};
      const orderFees = calculateOrderFees(grossAmount, true, feeConfig);
      meta.fees = {
        orderFee: round2(orderFees.orderFee || 0),
        exchangeFee: round2(orderFees.exchangeFee || 0),
        foreignCosts: round2(orderFees.foreignCosts || 0),
        totalFees: round2(orderFees.totalFees || 0),
      };
      meta.totalWithFees = executionType === 'buy'
        ? round2(grossAmount + (orderFees.totalFees || 0))
        : round2(Math.max(0, grossAmount - (orderFees.totalFees || 0)));
      if (!String(meta.tradingVenue || '').trim()) {
        meta.tradingVenue = 'XETRA';
      }
    }
  } catch {
    // Trade gelöscht / nicht lesbar
  }

  if (!meta.belegSchemaVersion) {
    meta.belegSchemaVersion = TRADER_COLLECTION_BILL_SCHEMA_VERSION;
    meta.belegKind = 'traderCollectionBill';
  }

  return meta;
}

module.exports = {
  enrichTraderDocumentMetadata,
  formatInstrumentLine,
  loadTradeInvoice,
};
