'use strict';

const { round2 } = require('../accountingHelper/shared');
const {
  isMirrorPoolOrderLeg,
  isMirrorPoolTradeLeg,
} = require('../../services/poolMirrorActivation/poolActivationPolicy');
const { TRADE_CASH_ENTRY_TYPES } = require('./shared');
const { tradeCoverageKeys, markTradeCovered, isTradeCovered } = require('./tradeCoverage');
const { belegRank, deduplicatedTraderCashLegs } = require('./cashLegDedup');
const {
  isSettlementTradeInvoice,
  invoiceTransactionType,
  invoiceOccurredAt,
} = require('./invoices');
const {
  parseInstrumentFromTrade,
  parseInstrumentFromInvoice,
  resolveSellOrderForStatementLeg,
  resolveInstrumentForDisplayEvent,
} = require('./instruments');
const { tradeStatementTitle } = require('./instrumentTitles');

function allocatedTradingFees(feesEntry, tradeBuyGross, tradeSellGross, forBuySide) {
  if (!feesEntry) return 0;
  const totalFees = Math.abs(Number(feesEntry.get('amount') || 0));
  if (totalFees <= 0) return 0;
  const denominator = tradeBuyGross + tradeSellGross;
  if (denominator <= 0.005) return totalFees;
  const sideGross = forBuySide ? tradeBuyGross : tradeSellGross;
  if (sideGross <= 0) return 0;
  return round2(totalFees * (sideGross / denominator));
}

function preferredBackendBeleg(tradeId, tradeNumber, entryType, cashLegRows) {
  const matches = cashLegRows.filter((row) => {
    if (String(row.get('entryType') || '') !== entryType) return false;
    if (tradeId && String(row.get('tradeId') || '').trim() === String(tradeId).trim()) return true;
    if (tradeNumber != null && row.get('tradeNumber') === tradeNumber) return true;
    return false;
  });
  if (!matches.length) return { referenceDocumentId: null, referenceDocumentNumber: null };
  const best = matches.reduce((a, b) => (
    belegRank(a.get('referenceDocumentNumber') || '') >= belegRank(b.get('referenceDocumentNumber') || '')
      ? a
      : b
  ));
  return {
    referenceDocumentId: best.get('referenceDocumentId') || null,
    referenceDocumentNumber: best.get('referenceDocumentNumber') || null,
  };
}

function signedNetAmount(transactionType, netAmount) {
  const absAmount = Math.abs(Number(netAmount) || 0);
  return transactionType === 'sell' ? absAmount : -absAmount;
}

function buildDisplayEventFromInvoice(invoice, cashLegRows, instrumentContext = {}) {
  const transactionType = invoiceTransactionType(invoice);
  if (!transactionType) return null;

  const { tradeById = new Map(), orderByTradeId = new Map() } = instrumentContext;
  const tradeId = invoice.get('tradeId');
  const trade = tradeId ? tradeById.get(tradeId) : null;
  const order = tradeId ? orderByTradeId.get(tradeId) : null;
  const invoiceInstrument = parseInstrumentFromInvoice(invoice);
  const instrument = resolveInstrumentForDisplayEvent(
    trade,
    order,
    transactionType,
    invoiceInstrument,
  );
  const beleg = preferredBackendBeleg(
    invoice.get('tradeId'),
    invoice.get('tradeNumber'),
    transactionType === 'sell' ? 'trade_sell' : 'trade_buy',
    cashLegRows,
  );
  const netAmount = Math.abs(Number(invoice.get('totalAmount') || 0));
  const tradeNumber = invoice.get('tradeNumber');
  const tradeNumberStr = tradeNumber != null ? String(tradeNumber) : '';

  return {
    objectId: `invoice-display:${invoice.id}:${transactionType}`,
    entryType: transactionType === 'sell' ? 'trade_sell' : 'trade_buy',
    amount: signedNetAmount(transactionType, netAmount),
    at: invoiceOccurredAt(invoice),
    tradeId: invoice.get('tradeId') || null,
    tradeNumber: tradeNumber ?? null,
    referenceDocumentId: beleg.referenceDocumentId,
    referenceDocumentNumber: beleg.referenceDocumentNumber || invoice.get('invoiceNumber') || null,
    description: `Netto ${transactionType === 'sell' ? 'Verkauf' : 'Kauf'} (Rechnung ${invoice.get('invoiceNumber') || ''})`,
    source: 'customer_display',
    statementTitle: tradeStatementTitle(transactionType, instrument),
    transactionTypeLabel: transactionType,
    wknOrIsin: instrument.wknOrIsin || null,
    underlyingAsset: instrument.underlyingAsset || null,
    securitiesDirection: instrument.securitiesDirection || null,
    quantity: instrument.quantity || null,
    strikePrice: instrument.strikePrice || null,
    issuer: instrument.issuer || null,
    displayAmountMode: 'netCash',
    netAmount,
    instrumentResolvedFromTrade: Boolean(trade),
  };
}

function buildDisplayEventsFromBackendLegs({
  legs,
  feesEntry,
  tradeBuyGross,
  tradeSellGross,
  transactionType,
  tradeInstrument,
  instrumentResolvedFromTrade = false,
}) {
  const legGrossTotal = legs.reduce((sum, leg) => sum + Math.abs(Number(leg.get('amount') || 0)), 0);
  if (legGrossTotal <= 0) return [];

  const feeShare = allocatedTradingFees(
    feesEntry,
    tradeBuyGross,
    tradeSellGross,
    transactionType === 'buy',
  );
  const net = Math.max(0, round2(legGrossTotal - feeShare));
  const representative = legs.reduce((best, leg) => {
    const bestAt = best.get('createdAt') || new Date(0);
    const legAt = leg.get('createdAt') || new Date(0);
    return legAt.getTime() >= bestAt.getTime() ? leg : best;
  }, legs[0]);

  const instrument = tradeInstrument || { wknOrIsin: '', securitiesDirection: '', underlyingAsset: '' };
  const tradeNumber = representative.get('tradeNumber');
  const hasInstrument = Boolean(instrument.wknOrIsin || instrument.securitiesDirection || instrument.underlyingAsset);

  return [{
    objectId: `stmt-display:${representative.id}`,
    entryType: transactionType === 'sell' ? 'trade_sell' : 'trade_buy',
    amount: signedNetAmount(transactionType, net),
    at: representative.get('createdAt') || new Date(),
    tradeId: representative.get('tradeId') || null,
    tradeNumber: tradeNumber ?? null,
    referenceDocumentId: representative.get('referenceDocumentId') || null,
    referenceDocumentNumber: representative.get('referenceDocumentNumber') || null,
    description: representative.get('description') || '',
    source: 'customer_display',
    statementTitle: hasInstrument
      ? tradeStatementTitle(transactionType, instrument)
      : (tradeNumber != null
        ? `${transactionType === 'sell' ? 'VERKAUF' : 'KAUF'} · Trade #${String(tradeNumber).padStart(3, '0')}`
        : (transactionType === 'sell' ? 'VERKAUF' : 'KAUF')),
    transactionTypeLabel: transactionType,
    wknOrIsin: instrument.wknOrIsin || null,
    underlyingAsset: instrument.underlyingAsset || null,
    securitiesDirection: instrument.securitiesDirection || null,
    quantity: instrument.quantity || null,
    strikePrice: instrument.strikePrice || null,
    issuer: instrument.issuer || null,
    displayAmountMode: 'netCash',
    netAmount: net,
    instrumentResolvedFromTrade,
  }];
}

function isTraderCustomerVisibleTrade(tradeId, tradeById, orderByTradeId) {
  if (!tradeId) return true;
  const trade = tradeById.get(tradeId);
  if (trade && isMirrorPoolTradeLeg(trade)) return false;
  const order = orderByTradeId.get(tradeId);
  if (order && isMirrorPoolOrderLeg(order)) return false;
  return true;
}

function buildNetTradeDisplayEvents(stmtEntries, invoices, instrumentContext = {}) {
  const { tradeById = new Map(), orderByTradeId = new Map() } = instrumentContext;
  const cashLegRows = deduplicatedTraderCashLegs(
    stmtEntries.filter((row) => TRADE_CASH_ENTRY_TYPES.has(String(row.get('entryType') || ''))),
  );

  const feesByTradeKey = new Map();
  for (const row of stmtEntries) {
    if (String(row.get('entryType') || '') !== 'trading_fees') continue;
    for (const key of tradeCoverageKeys(row.get('tradeId'), row.get('tradeNumber'))) {
      feesByTradeKey.set(key, row);
    }
  }

  const events = [];
  const coveredBuy = new Set();
  const coveredSell = new Set();

  const settlementInvoices = invoices
    .filter(isSettlementTradeInvoice)
    .sort((a, b) => {
      const ta = invoiceOccurredAt(a).getTime();
      const tb = invoiceOccurredAt(b).getTime();
      return ta - tb;
    });

  for (const invoice of settlementInvoices) {
    const invoiceTradeId = invoice.get('tradeId');
    if (!isTraderCustomerVisibleTrade(invoiceTradeId, tradeById, orderByTradeId)) {
      continue;
    }
    const event = buildDisplayEventFromInvoice(invoice, cashLegRows, instrumentContext);
    if (!event) continue;
    const alreadyCovered = event.transactionTypeLabel === 'buy'
      ? isTradeCovered(coveredBuy, event.tradeId, event.tradeNumber)
      : isTradeCovered(coveredSell, event.tradeId, event.tradeNumber);
    if (alreadyCovered) continue;
    events.push(event);
    if (event.transactionTypeLabel === 'buy') {
      markTradeCovered(coveredBuy, event.tradeId, event.tradeNumber);
    } else {
      markTradeCovered(coveredSell, event.tradeId, event.tradeNumber);
    }
  }

  const legsByTrade = new Map();
  for (const leg of cashLegRows) {
    const key = tradeCoverageKeys(leg.get('tradeId'), leg.get('tradeNumber'))[0]
      || `stmt:${leg.id}`;
    if (!legsByTrade.has(key)) legsByTrade.set(key, []);
    legsByTrade.get(key).push(leg);
  }

  for (const [, legs] of legsByTrade) {
    const tradeId = legs[0]?.get('tradeId') || null;
    if (!isTraderCustomerVisibleTrade(tradeId, tradeById, orderByTradeId)) {
      continue;
    }
    const tradeNumber = legs[0]?.get('tradeNumber') ?? null;
    const feeKey = tradeCoverageKeys(tradeId, tradeNumber).find((k) => feesByTradeKey.has(k));
    const feesEntry = feeKey ? feesByTradeKey.get(feeKey) : null;

    const buyLegs = legs.filter((leg) => leg.get('entryType') === 'trade_buy');
    const sellLegs = legs.filter((leg) => leg.get('entryType') === 'trade_sell');
    const tradeBuyGross = buyLegs.reduce((sum, leg) => sum + Math.abs(Number(leg.get('amount') || 0)), 0);
    const tradeSellGross = sellLegs.reduce((sum, leg) => sum + Math.abs(Number(leg.get('amount') || 0)), 0);

    const trade = tradeId ? tradeById.get(tradeId) : null;
    const order = tradeId ? orderByTradeId.get(tradeId) : null;
    const buyInstrument = parseInstrumentFromTrade(trade, order, { transactionType: 'buy' });

    if (buyLegs.length > 0 && !isTradeCovered(coveredBuy, tradeId, tradeNumber)) {
      events.push(...buildDisplayEventsFromBackendLegs({
        legs: buyLegs,
        feesEntry,
        tradeBuyGross,
        tradeSellGross,
        transactionType: 'buy',
        tradeInstrument: buyInstrument,
        instrumentResolvedFromTrade: Boolean(trade),
      }));
    }

    if (sellLegs.length > 0 && !isTradeCovered(coveredSell, tradeId, tradeNumber)) {
      for (const sellLeg of sellLegs) {
        const sellOrder = resolveSellOrderForStatementLeg(trade, sellLeg);
        const sellInstrument = parseInstrumentFromTrade(trade, order, {
          transactionType: 'sell',
          sellOrder,
        });
        events.push(...buildDisplayEventsFromBackendLegs({
          legs: [sellLeg],
          feesEntry,
          tradeBuyGross,
          tradeSellGross,
          transactionType: 'sell',
          tradeInstrument: sellInstrument,
          instrumentResolvedFromTrade: Boolean(trade),
        }));
      }
    }
  }

  return events;
}

module.exports = {
  buildNetTradeDisplayEvents,
  isTraderCustomerVisibleTrade,
};
