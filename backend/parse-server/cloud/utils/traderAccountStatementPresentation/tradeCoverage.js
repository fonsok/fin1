'use strict';

function tradeCoverageKeys(tradeId, tradeNumber, tradeNumberYear) {
  const keys = [];
  if (tradeId) {
    const trimmed = String(tradeId).trim();
    if (trimmed) keys.push(`id:${trimmed}`);
  }
  const year = Number(tradeNumberYear);
  if (tradeNumber !== undefined && tradeNumber !== null && tradeNumber !== '') {
    if (Number.isFinite(year) && year > 0) {
      keys.push(`num:${year}:${tradeNumber}`);
    }
    keys.push(`num:${tradeNumber}`);
  }
  return keys;
}

function markTradeCovered(set, tradeId, tradeNumber, tradeNumberYear) {
  for (const key of tradeCoverageKeys(tradeId, tradeNumber, tradeNumberYear)) {
    set.add(key);
  }
}

function isTradeCovered(set, tradeId, tradeNumber, tradeNumberYear) {
  return tradeCoverageKeys(tradeId, tradeNumber, tradeNumberYear).some((key) => set.has(key));
}

/** Per sell leg — partial sells share tradeId/tradeNumber but have distinct TSC / order. */
function sellLegCoverageKeys({
  referenceDocumentId,
  referenceDocumentNumber,
  orderId,
  stmtEntryId,
  invoiceId,
}) {
  const keys = [];
  const refId = String(referenceDocumentId || '').trim();
  if (refId) keys.push(`sell:refid:${refId}`);
  const refNum = String(referenceDocumentNumber || '').trim();
  if (refNum) keys.push(`sell:refnum:${refNum}`);
  const oid = String(orderId || '').trim();
  if (oid) keys.push(`sell:order:${oid}`);
  const sid = String(stmtEntryId || '').trim();
  if (sid) keys.push(`sell:stmt:${sid}`);
  const iid = String(invoiceId || '').trim();
  if (iid) keys.push(`sell:inv:${iid}`);
  return keys;
}

function markSellLegCovered(set, fields) {
  for (const key of sellLegCoverageKeys(fields)) {
    set.add(key);
  }
}

function isSellLegCovered(set, fields) {
  return sellLegCoverageKeys(fields).some((key) => set.has(key));
}

function sellCoverageFromStmtLeg(leg) {
  return {
    referenceDocumentId: leg.get('referenceDocumentId'),
    referenceDocumentNumber: leg.get('referenceDocumentNumber'),
    stmtEntryId: leg.id,
  };
}

module.exports = {
  tradeCoverageKeys,
  markTradeCovered,
  isTradeCovered,
  sellLegCoverageKeys,
  markSellLegCovered,
  isSellLegCovered,
  sellCoverageFromStmtLeg,
};
