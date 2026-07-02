'use strict';

const { round2 } = require('../accountingHelper/shared');
const {
  formatTradeNumberLabel,
  resolveTradeNumberPresentation,
} = require('../tradeNumberAllocation');
const {
  isMirrorPoolOrderLeg,
  isMirrorPoolTradeLeg,
} = require('../../services/poolMirrorActivation/poolActivationPolicy');
const { TRADE_CASH_ENTRY_TYPES } = require('./shared');
const {
  tradeCoverageKeys,
  markTradeCovered,
  isTradeCovered,
  markSellLegCovered,
  isSellLegCovered,
  sellCoverageFromStmtLeg,
} = require('./tradeCoverage');
const {
  belegRank,
  isTraderExecutionBelegNumber,
  deduplicatedTraderCashLegs,
} = require('./cashLegDedup');
const {
  isSettlementTradeInvoice,
  invoiceTransactionType,
  invoiceOccurredAt,
} = require('./invoices');
const {
  parseInstrumentFromTrade,
  parseInstrumentFromInvoice,
  resolveInstrumentForDisplayEvent,
} = require('./instruments');
const {
  parseOrderToSnapshot,
  resolveOrderForTradeSide,
} = require('./orderContext');
const {
  readCustomerDisplaySnapshotFromEntry,
  applyCustomerDisplaySnapshotToEvent,
} = require('./customerDisplaySnapshot');
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

function matchingCashLegsForTrade(tradeId, tradeNumber, entryType, cashLegRows) {
  return cashLegRows.filter((row) => {
    if (String(row.get('entryType') || '') !== entryType) return false;
    if (tradeId && String(row.get('tradeId') || '').trim() === String(tradeId).trim()) return true;
    if (tradeNumber != null && row.get('tradeNumber') === tradeNumber) return true;
    return false;
  });
}

function preferredBackendBeleg(tradeId, tradeNumber, entryType, cashLegRows) {
  const matches = matchingCashLegsForTrade(tradeId, tradeNumber, entryType, cashLegRows);
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

function resolveBackendBelegForInvoice(invoice, cashLegRows, transactionType) {
  const entryType = transactionType === 'sell' ? 'trade_sell' : 'trade_buy';
  const matches = matchingCashLegsForTrade(
    invoice.get('tradeId'),
    invoice.get('tradeNumber'),
    entryType,
    cashLegRows,
  );
  if (!matches.length) {
    return { referenceDocumentId: null, referenceDocumentNumber: null };
  }
  if (transactionType !== 'sell' || matches.length === 1) {
    return preferredBackendBeleg(
      invoice.get('tradeId'),
      invoice.get('tradeNumber'),
      entryType,
      cashLegRows,
    );
  }

  const netAmount = Math.abs(Number(invoice.get('totalAmount') || 0));
  if (netAmount > 0) {
    const byAmount = matches.filter((row) => (
      Math.abs(Math.abs(Number(row.get('amount') || 0)) - netAmount) < 0.02
    ));
    if (byAmount.length === 1) {
      const leg = byAmount[0];
      return {
        referenceDocumentId: leg.get('referenceDocumentId') || null,
        referenceDocumentNumber: leg.get('referenceDocumentNumber') || null,
      };
    }
    if (byAmount.length > 1) {
      const tscLeg = byAmount.find((row) => (
        isTraderExecutionBelegNumber(row.get('referenceDocumentNumber') || '')
      ));
      if (tscLeg) {
        return {
          referenceDocumentId: tscLeg.get('referenceDocumentId') || null,
          referenceDocumentNumber: tscLeg.get('referenceDocumentNumber') || null,
        };
      }
    }
  }

  return preferredBackendBeleg(
    invoice.get('tradeId'),
    invoice.get('tradeNumber'),
    entryType,
    cashLegRows,
  );
}

function signedNetAmount(transactionType, netAmount) {
  const absAmount = Math.abs(Number(netAmount) || 0);
  return transactionType === 'sell' ? absAmount : -absAmount;
}

function buildDisplayEventFromInvoice(invoice, cashLegRows, instrumentContext = {}) {
  const transactionType = invoiceTransactionType(invoice);
  if (!transactionType) return null;

  const { tradeById = new Map() } = instrumentContext;
  const tradeId = invoice.get('tradeId');
  const trade = tradeId ? tradeById.get(tradeId) : null;
  const orderId = String(invoice.get('orderId') || '').trim() || null;
  const order = resolveOrderForTradeSide(instrumentContext, tradeId, transactionType, {
    orderId,
    trade,
  });
  const invoiceInstrument = parseInstrumentFromInvoice(invoice);
  const sellOrder = transactionType === 'sell' && order?.get
    ? parseOrderToSnapshot(order)
    : null;
  const instrument = resolveInstrumentForDisplayEvent(
    trade,
    order,
    transactionType,
    invoiceInstrument,
    { sellOrder },
  );
  const beleg = resolveBackendBelegForInvoice(invoice, cashLegRows, transactionType);
  const netAmount = Math.abs(Number(invoice.get('totalAmount') || 0));
  const tradePresentation = trade
    ? resolveTradeNumberPresentation(trade)
    : {
      tradeNumber: invoice.get('tradeNumber') ?? null,
      tradeNumberYear: null,
      label: formatTradeNumberLabel(invoice.get('tradeNumber'), null),
    };

  return {
    objectId: `invoice-display:${invoice.id}:${transactionType}`,
    entryType: transactionType === 'sell' ? 'trade_sell' : 'trade_buy',
    amount: signedNetAmount(transactionType, netAmount),
    at: invoiceOccurredAt(invoice),
    tradeId: invoice.get('tradeId') || null,
    tradeNumber: tradePresentation.tradeNumber ?? null,
    tradeNumberYear: tradePresentation.tradeNumberYear ?? null,
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
    orderId,
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
  trade = null,
}) {
  const legGrossTotal = legs.reduce((sum, leg) => sum + Math.abs(Number(leg.get('amount') || 0)), 0);
  if (legGrossTotal <= 0) return [];

  const net = transactionType === 'sell'
    ? round2(legGrossTotal)
    : Math.max(0, round2(legGrossTotal - allocatedTradingFees(
      feesEntry,
      tradeBuyGross,
      tradeSellGross,
      true,
    )));
  const representative = legs.reduce((best, leg) => {
    const bestAt = best.get('createdAt') || new Date(0);
    const legAt = leg.get('createdAt') || new Date(0);
    return legAt.getTime() >= bestAt.getTime() ? leg : best;
  }, legs[0]);

  const bookingSnapshot = readCustomerDisplaySnapshotFromEntry(representative);
  const instrument = tradeInstrument || { wknOrIsin: '', securitiesDirection: '', underlyingAsset: '' };
  const tradePresentation = trade
    ? resolveTradeNumberPresentation(trade)
    : {
      tradeNumber: representative.get('tradeNumber') ?? null,
      tradeNumberYear: null,
      label: formatTradeNumberLabel(representative.get('tradeNumber'), null),
    };
  const tradeNumber = tradePresentation.tradeNumber;
  const hasInstrument = Boolean(instrument.wknOrIsin || instrument.securitiesDirection || instrument.underlyingAsset);

  const baseEvent = {
    objectId: `stmt-display:${representative.id}`,
    entryType: transactionType === 'sell' ? 'trade_sell' : 'trade_buy',
    amount: signedNetAmount(transactionType, net),
    at: representative.get('createdAt') || new Date(),
    tradeId: representative.get('tradeId') || null,
    tradeNumber: tradeNumber ?? null,
    tradeNumberYear: tradePresentation.tradeNumberYear ?? null,
    referenceDocumentId: representative.get('referenceDocumentId') || null,
    referenceDocumentNumber: representative.get('referenceDocumentNumber') || null,
    description: representative.get('description') || '',
    source: 'customer_display',
    statementTitle: hasInstrument
      ? tradeStatementTitle(transactionType, instrument)
      : (tradePresentation.label
        ? `${transactionType === 'sell' ? 'VERKAUF' : 'KAUF'} · ${tradePresentation.label}`
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
  };

  return [applyCustomerDisplaySnapshotToEvent(baseEvent, bookingSnapshot)];
}

function isTraderCustomerVisibleTrade(tradeId, tradeById, buyOrderByTradeId) {
  if (!tradeId) return true;
  const trade = tradeById.get(tradeId);
  if (trade && isMirrorPoolTradeLeg(trade)) return false;
  const buyOrder = buyOrderByTradeId.get(tradeId);
  if (buyOrder && isMirrorPoolOrderLeg(buyOrder)) return false;
  return true;
}

function buildNetTradeDisplayEvents(stmtEntries, invoices, instrumentContext = {}) {
  const { tradeById = new Map(), buyOrderByTradeId = new Map() } = instrumentContext;
  const cashLegRows = deduplicatedTraderCashLegs(
    stmtEntries.filter((row) => TRADE_CASH_ENTRY_TYPES.has(String(row.get('entryType') || ''))),
  );

  const feesByTradeKey = new Map();
  for (const row of stmtEntries) {
    if (String(row.get('entryType') || '') !== 'trading_fees') continue;
    for (const key of tradeCoverageKeys(
      row.get('tradeId'),
      row.get('tradeNumber'),
      row.get('tradeNumberYear'),
    )) {
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
    if (!isTraderCustomerVisibleTrade(invoiceTradeId, tradeById, buyOrderByTradeId)) {
      continue;
    }
    const event = buildDisplayEventFromInvoice(invoice, cashLegRows, instrumentContext);
    if (!event) continue;
    if (event.transactionTypeLabel === 'buy') {
      if (isTradeCovered(coveredBuy, event.tradeId, event.tradeNumber, event.tradeNumberYear)) continue;
      events.push(event);
      markTradeCovered(coveredBuy, event.tradeId, event.tradeNumber, event.tradeNumberYear);
      continue;
    }

    if (isSellLegCovered(coveredSell, {
      referenceDocumentId: event.referenceDocumentId,
      referenceDocumentNumber: event.referenceDocumentNumber,
      orderId: event.orderId,
      invoiceId: invoice.id,
    })) {
      continue;
    }
    events.push(event);
    markSellLegCovered(coveredSell, {
      referenceDocumentId: event.referenceDocumentId,
      referenceDocumentNumber: event.referenceDocumentNumber,
      orderId: event.orderId,
      invoiceId: invoice.id,
    });
  }

  const legsByTrade = new Map();
  for (const leg of cashLegRows) {
    const key = tradeCoverageKeys(
      leg.get('tradeId'),
      leg.get('tradeNumber'),
      leg.get('tradeNumberYear'),
    )[0]
      || `stmt:${leg.id}`;
    if (!legsByTrade.has(key)) legsByTrade.set(key, []);
    legsByTrade.get(key).push(leg);
  }

  for (const [, legs] of legsByTrade) {
    const tradeId = legs[0]?.get('tradeId') || null;
    if (!isTraderCustomerVisibleTrade(tradeId, tradeById, buyOrderByTradeId)) {
      continue;
    }
    const trade = tradeId ? tradeById.get(tradeId) : null;
    const tradeNumber = legs[0]?.get('tradeNumber') ?? null;
    const tradeNumberYear = trade?.get?.('tradeNumberYear') ?? null;
    const feeKey = tradeCoverageKeys(tradeId, tradeNumber, tradeNumberYear).find((k) => feesByTradeKey.has(k));
    const feesEntry = feeKey ? feesByTradeKey.get(feeKey) : null;

    const buyLegs = legs.filter((leg) => leg.get('entryType') === 'trade_buy');
    const sellLegs = legs.filter((leg) => leg.get('entryType') === 'trade_sell');
    const tradeBuyGross = buyLegs.reduce((sum, leg) => sum + Math.abs(Number(leg.get('amount') || 0)), 0);
    const tradeSellGross = sellLegs.reduce((sum, leg) => sum + Math.abs(Number(leg.get('amount') || 0)), 0);

    const buyOrder = resolveOrderForTradeSide(instrumentContext, tradeId, 'buy');
    const buyInstrument = parseInstrumentFromTrade(trade, buyOrder, { transactionType: 'buy' });

    if (buyLegs.length > 0 && !isTradeCovered(coveredBuy, tradeId, tradeNumber, tradeNumberYear)) {
      events.push(...buildDisplayEventsFromBackendLegs({
        legs: buyLegs,
        feesEntry,
        tradeBuyGross,
        tradeSellGross,
        transactionType: 'buy',
        tradeInstrument: buyInstrument,
        instrumentResolvedFromTrade: Boolean(trade),
        trade,
      }));
    }

    for (const sellLeg of sellLegs) {
      if (isSellLegCovered(coveredSell, sellCoverageFromStmtLeg(sellLeg))) {
        continue;
      }
      const sellOrderMatch = resolveOrderForTradeSide(instrumentContext, tradeId, 'sell', {
        trade,
        stmtLeg: sellLeg,
      });
      const sellOrderSnap = sellOrderMatch?.get
        ? parseOrderToSnapshot(sellOrderMatch)
        : sellOrderMatch;
      const sellInstrument = parseInstrumentFromTrade(trade, sellOrderMatch, {
        transactionType: 'sell',
        sellOrder: sellOrderSnap,
      });
      const legEvents = buildDisplayEventsFromBackendLegs({
        legs: [sellLeg],
        feesEntry,
        tradeBuyGross,
        tradeSellGross,
        transactionType: 'sell',
        tradeInstrument: sellInstrument,
        instrumentResolvedFromTrade: Boolean(trade),
        trade,
      });
      if (!legEvents.length) continue;
      events.push(...legEvents);
      markSellLegCovered(coveredSell, sellCoverageFromStmtLeg(sellLeg));
    }
  }

  return events;
}

module.exports = {
  buildNetTradeDisplayEvents,
  isTraderCustomerVisibleTrade,
};
