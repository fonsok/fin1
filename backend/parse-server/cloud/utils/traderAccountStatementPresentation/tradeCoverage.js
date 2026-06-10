'use strict';

function tradeCoverageKeys(tradeId, tradeNumber) {
  const keys = [];
  if (tradeId) {
    const trimmed = String(tradeId).trim();
    if (trimmed) keys.push(`id:${trimmed}`);
  }
  if (tradeNumber !== undefined && tradeNumber !== null && tradeNumber !== '') {
    keys.push(`num:${tradeNumber}`);
  }
  return keys;
}

function markTradeCovered(set, tradeId, tradeNumber) {
  for (const key of tradeCoverageKeys(tradeId, tradeNumber)) {
    set.add(key);
  }
}

function isTradeCovered(set, tradeId, tradeNumber) {
  return tradeCoverageKeys(tradeId, tradeNumber).some((key) => set.has(key));
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
