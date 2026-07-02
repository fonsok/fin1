'use strict';

const { formatTradeNumberForDisplay } = require('../tradeNumberAllocation');
const { iso } = require('./shared');

function timelineRowMatchesEntryType(row, entryType) {
  if (!entryType) return true;
  return String(row.entryType || '') === entryType;
}

function buildTraderDisplayApiRow(event, canonicalUserId) {
  const tradeNumber = event.tradeNumber;
  const tradeNumberYear = event.tradeNumberYear;
  const formattedTradeNumber = formatTradeNumberForDisplay(tradeNumber, tradeNumberYear);

  return {
    objectId: event.objectId,
    userId: canonicalUserId,
    entryType: event.entryType,
    amount: event.amount,
    balanceBefore: event.balanceBefore,
    balanceAfter: event.balanceAfter,
    tradeId: event.tradeId,
    tradeNumber: tradeNumber != null ? Number(tradeNumber) : null,
    tradeNumberYear: tradeNumberYear != null ? Number(tradeNumberYear) : null,
    investmentId: null,
    investmentNumber: null,
    businessReference: formattedTradeNumber ? `TRD-${formattedTradeNumber}` : null,
    description: event.description,
    source: event.source,
    referenceDocumentId: event.referenceDocumentId,
    referenceDocumentNumber: event.referenceDocumentNumber,
    createdAt: iso(event.at),
    statementTitle: event.statementTitle,
    transactionType: event.transactionTypeLabel,
    wknOrIsin: event.wknOrIsin,
    underlyingAsset: event.underlyingAsset,
    securitiesDirection: event.securitiesDirection,
    quantity: event.quantity,
    strikePrice: event.strikePrice,
    issuer: event.issuer,
    displayAmountMode: event.displayAmountMode,
    netAmount: event.netAmount,
  };
}

/**
 * API-Zeilen: chronologisch aufsteigend (älteste zuerst), Pagination danach.
 */
function traderCustomerTimelineToApiRows(user, timeline, opts = {}) {
  const { entryType = null, limit = 50, skip = 0 } = opts;
  const filtered = entryType
    ? timeline.filter((row) => timelineRowMatchesEntryType(row, entryType))
    : timeline;
  const page = filtered.slice(skip, skip + limit);
  const canonicalUserId = user.get('stableId') || user.id;
  const rows = page.map((row) => buildTraderDisplayApiRow(row, canonicalUserId));
  return {
    rows,
    total: filtered.length,
    hasMore: skip + rows.length < filtered.length,
  };
}

module.exports = {
  traderCustomerTimelineToApiRows,
};
