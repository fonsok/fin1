'use strict';

const { round2 } = require('../shared');
const {
  ensureServiceChargeInvoiceDocument,
  resolveDocumentRefsFromInvoiceIfOwned,
} = require('./serviceChargeInvoice');

function buildDocRefsFromLedgerRow(row) {
  const meta = row.get('metadata') || {};
  let refId = String(meta.referenceDocumentId || '').trim();
  let refNo = String(meta.referenceDocumentNumber || meta.invoiceNumber || '').trim();
  const invId = String(meta.invoiceId || '').trim();
  return { refId, refNo, invId, meta };
}

async function finalizeLedgerDocRefs(refId, refNo, invId) {
  const rid = String(refId || '').trim();
  const rno = String(refNo || '').trim();
  if (rid && rno) {
    return { referenceDocumentId: rid, referenceDocumentNumber: rno };
  }
  let outId = rid;
  let outNo = rno;
  if (!outId && invId) {
    try {
      const Invoice = Parse.Object.extend('Invoice');
      const inv = await new Parse.Query(Invoice).get(invId, { useMasterKey: true });
      const ensured = await ensureServiceChargeInvoiceDocument(inv);
      if (ensured && ensured.id) {
        outId = String(ensured.id).trim();
      }
      if (!outNo) {
        outNo = String(inv.get('invoiceNumber') || '').trim();
      }
    } catch (_) {
      // leave refs empty
    }
  }
  if (outId || outNo) {
    return {
      ...(outId ? { referenceDocumentId: outId } : {}),
      ...(outNo ? { referenceDocumentNumber: outNo } : {}),
    };
  }
  return {};
}

async function findDocRefsFromLiabilityRows(rows, gross) {
  for (const row of rows) {
    const { refId, refNo, invId, meta } = buildDocRefsFromLedgerRow(row);
    const rowAmount = round2(Number(row.get('amount')) || 0);
    const metaGross = round2(parseFloat(String(meta.grossAmount ?? '')));
    const grossOk = (Number.isFinite(metaGross) && metaGross === gross)
      || (rowAmount === gross);
    if (!grossOk) {
      continue;
    }
    const finalized = await finalizeLedgerDocRefs(refId, refNo, invId);
    if (Object.keys(finalized).length > 0) {
      return finalized;
    }
  }
  return {};
}

async function fetchChargeLiabilityRows(userId, {
  referenceId,
  amount,
  limit,
} = {}) {
  const hasAmount = Number.isFinite(amount) && amount > 0;
  const defaultLimit = referenceId && hasAmount ? 5 : (hasAmount ? 12 : 20);
  const lim = Math.min(Math.max(Number(limit) || defaultLimit, 1), 30);

  const AppLedgerEntry = Parse.Object.extend('AppLedgerEntry');
  const q = new Parse.Query(AppLedgerEntry);
  q.equalTo('userId', userId);
  q.equalTo('transactionType', 'appServiceCharge');
  q.equalTo('account', 'CLT-LIAB-AVA');
  q.equalTo('side', 'debit');
  if (referenceId) {
    q.equalTo('referenceId', referenceId);
  }
  if (hasAmount) {
    q.equalTo('amount', round2(amount));
  }
  q.descending('createdAt');
  q.limit(lim);
  return q.find({ useMasterKey: true });
}

/**
 * For 4-eyes fee_refund: resolve Beleg refs. Priority:
 * 1) explicit `invoiceId` (must belong to userId and match gross),
 * 2) `batchId` + same gross on CLT-LIAB-AVA (`amount` + `referenceId`),
 * 3) gross-only on recent CLT-LIAB-AVA rows — only when no `batchId` was given
 *    (avoids matching another batch with the same gross). New requests should
 *    include `invoiceId` or `batchId` (enforced in createCorrectionRequest).
 *
 * @param {string} userId
 * @param {number} grossRefundAmount
 * @param {{ invoiceId?: string, batchId?: string }} [options]
 */
async function resolveDocumentRefForFeeRefund(userId, grossRefundAmount, options = {}) {
  const uid = String(userId || '').trim();
  const gross = round2(Number(grossRefundAmount));
  if (!uid || !Number.isFinite(gross) || gross <= 0) {
    return {};
  }

  const invoiceIdOpt = String(options.invoiceId || '').trim();
  const batchIdOpt = String(options.batchId || '').trim();

  if (invoiceIdOpt) {
    try {
      const Invoice = Parse.Object.extend('Invoice');
      const inv = await new Parse.Query(Invoice).get(invoiceIdOpt, { useMasterKey: true });
      const fromInv = await resolveDocumentRefsFromInvoiceIfOwned(inv, uid, gross);
      if (Object.keys(fromInv).length > 0) {
        return fromInv;
      }
    } catch (_) {
      // fall through to ledger paths
    }
  }

  if (batchIdOpt) {
    const batchRows = await fetchChargeLiabilityRows(uid, {
      referenceId: batchIdOpt,
      amount: gross,
      limit: 5,
    });
    const fromBatch = await findDocRefsFromLiabilityRows(batchRows, gross);
    if (Object.keys(fromBatch).length > 0) {
      return fromBatch;
    }
    return {};
  }

  const allRows = await fetchChargeLiabilityRows(uid, { amount: gross, limit: 12 });
  return findDocRefsFromLiabilityRows(allRows, gross);
}

module.exports = {
  resolveDocumentRefForFeeRefund,
};
