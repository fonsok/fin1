'use strict';

const { parseInstrumentFromTrade } = require('../traderAccountStatementPresentation/instruments');
const { tradeStatementTitle } = require('../traderAccountStatementPresentation/instrumentTitles');

const CUSTOMER_DISPLAY_SCHEMA_VERSION = 1;

function resolveBelegQuantity(metadata, executionType) {
  const ex = String(executionType || 'buy').toLowerCase();
  if (ex === 'sell' && Number(metadata?.partialSell?.orderQuantity) > 0) {
    return Number(metadata.partialSell.orderQuantity);
  }
  return Number(metadata?.quantity || 0);
}

function parseInstrumentLine(line) {
  const components = String(line || '')
    .split(' - ')
    .map((part) => part.trim())
    .filter(Boolean);
  const strikePart = components.find((part) => /^strike\b/i.test(part)) || '';
  return {
    wknOrIsin: components[0] || '',
    securitiesDirection: components[1] || '',
    underlyingAsset: components[2] || '',
    strikePrice: strikePart || components[3] || '',
    issuer: components[4] || '',
  };
}

/**
 * Booking-time customer display — same inputs as `buildTraderCollectionBillBelegSnapshot`.
 */
function buildTraderStatementCustomerDisplay({
  trade,
  order,
  orderLike,
  executionType,
  metadata,
}) {
  const tx = String(executionType || 'buy').toLowerCase();
  const sellOrderHint = tx === 'sell' ? (orderLike || null) : null;
  const instrument = parseInstrumentFromTrade(trade, order, {
    transactionType: tx,
    sellOrder: sellOrderHint,
  });
  const qtyNum = resolveBelegQuantity(metadata, tx) || Number(instrument.quantity || 0);
  const quantity = qtyNum > 0 ? String(qtyNum) : (instrument.quantity || '');
  const display = {
    schemaVersion: CUSTOMER_DISPLAY_SCHEMA_VERSION,
    transactionType: tx,
    wknOrIsin: instrument.wknOrIsin || String(metadata?.wkn || metadata?.symbol || '').trim(),
    securitiesDirection: instrument.securitiesDirection || '',
    underlyingAsset: instrument.underlyingAsset || '',
    strikePrice: instrument.strikePrice || '',
    issuer: instrument.issuer || '',
    quantity,
  };
  return {
    ...display,
    statementTitle: tradeStatementTitle(tx, display),
  };
}

/**
 * Rebuild display from persisted beleg metadata (existing TSC/TBC Document).
 */
function customerDisplayFromPersistedBelegMetadata(metadata, executionType) {
  if (!metadata || typeof metadata !== 'object') return null;
  const tx = String(executionType || metadata.executionType || 'buy').toLowerCase();
  const fromLine = parseInstrumentLine(metadata.instrumentLine);
  const qtyNum = resolveBelegQuantity(metadata, tx);
  const quantity = qtyNum > 0 ? String(qtyNum) : '';
  const display = {
    schemaVersion: CUSTOMER_DISPLAY_SCHEMA_VERSION,
    transactionType: tx,
    wknOrIsin: fromLine.wknOrIsin || String(metadata.wkn || metadata.symbol || '').trim(),
    securitiesDirection: fromLine.securitiesDirection || '',
    underlyingAsset: fromLine.underlyingAsset || '',
    strikePrice: fromLine.strikePrice || '',
    issuer: fromLine.issuer || '',
    quantity,
  };
  if (!display.wknOrIsin && !display.underlyingAsset && !quantity) return null;
  return {
    ...display,
    statementTitle: tradeStatementTitle(tx, display),
  };
}

function isCustomerDisplaySnapshot(snapshot) {
  return snapshot
    && typeof snapshot === 'object'
    && Number(snapshot.schemaVersion) === CUSTOMER_DISPLAY_SCHEMA_VERSION;
}

function instrumentFieldsFromCustomerDisplaySnapshot(snapshot) {
  if (!isCustomerDisplaySnapshot(snapshot)) return null;
  return {
    wknOrIsin: snapshot.wknOrIsin || '',
    securitiesDirection: snapshot.securitiesDirection || '',
    underlyingAsset: snapshot.underlyingAsset || '',
    strikePrice: snapshot.strikePrice || '',
    issuer: snapshot.issuer || '',
    quantity: snapshot.quantity || '',
  };
}

module.exports = {
  CUSTOMER_DISPLAY_SCHEMA_VERSION,
  buildTraderStatementCustomerDisplay,
  customerDisplayFromPersistedBelegMetadata,
  isCustomerDisplaySnapshot,
  instrumentFieldsFromCustomerDisplaySnapshot,
};
