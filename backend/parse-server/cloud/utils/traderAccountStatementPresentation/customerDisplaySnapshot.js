'use strict';

const {
  instrumentFieldsFromCustomerDisplaySnapshot,
  isCustomerDisplaySnapshot,
} = require('../accountingHelper/traderStatementCustomerDisplay');

function readCustomerDisplaySnapshotFromEntry(entry) {
  if (!entry?.get) return null;
  const snapshot = entry.get('customerDisplaySnapshot');
  return isCustomerDisplaySnapshot(snapshot) ? snapshot : null;
}

function applyCustomerDisplaySnapshotToEvent(event, snapshot) {
  if (!isCustomerDisplaySnapshot(snapshot)) return event;
  const instrument = instrumentFieldsFromCustomerDisplaySnapshot(snapshot);
  if (!instrument) return event;
  return {
    ...event,
    statementTitle: snapshot.statementTitle || event.statementTitle,
    transactionTypeLabel: snapshot.transactionType || event.transactionTypeLabel,
    wknOrIsin: instrument.wknOrIsin || null,
    underlyingAsset: instrument.underlyingAsset || null,
    securitiesDirection: instrument.securitiesDirection || null,
    quantity: instrument.quantity || null,
    strikePrice: instrument.strikePrice || null,
    issuer: instrument.issuer || null,
    instrumentResolvedFromTrade: true,
  };
}

module.exports = {
  readCustomerDisplaySnapshotFromEntry,
  applyCustomerDisplaySnapshotToEvent,
};
