'use strict';

const { isServiceChargeInvoiceType } = require('../../utils/serviceChargeInvoiceTypes');
const { logPermissionCheck } = require('../../utils/permissions');

async function handleGetRoundingDifferences(request) {
  const { status, limit = 50, skip = 0 } = request.params;

  const query = new Parse.Query('RoundingDifference');

  if (status) {
    query.equalTo('status', status);
  } else {
    query.containedIn('status', ['open', 'under_review']);
  }

  query.descending('occurredAt');
  query.limit(limit);
  query.skip(skip);

  const differences = await query.find({ useMasterKey: true });
  const total = await query.count({ useMasterKey: true });

  return { differences: differences.map(d => d.toJSON()), total };
}

async function handleCreateCorrectionRequest(request) {
  const {
    correctionType,
    targetId,
    targetType,
    reason,
    oldValue,
    newValue,
    invoiceId,
    batchId,
  } = request.params;

  if (!correctionType || !targetId || !targetType || !reason) {
    throw new Parse.Error(
      Parse.Error.INVALID_VALUE,
      'correctionType, targetId, targetType, and reason required',
    );
  }

  if (correctionType === 'fee_refund') {
    const refundGross = Number(newValue);
    if (!Number.isFinite(refundGross) || refundGross <= 0) {
      throw new Parse.Error(
        Parse.Error.INVALID_VALUE,
        'Gebührenerstattung: newValue muss ein positiver Betrag (EUR) sein.',
      );
    }
  }

  const cleanInvoiceId = invoiceId != null && String(invoiceId).trim()
    ? String(invoiceId).trim()
    : '';
  const cleanBatchId = batchId != null && String(batchId).trim()
    ? String(batchId).trim()
    : '';

  if (correctionType === 'fee_refund' && !cleanInvoiceId && !cleanBatchId) {
    throw new Parse.Error(
      Parse.Error.INVALID_VALUE,
      'Gebührenerstattung: Bitte invoiceId oder batchId angeben (eindeutige Zuordnung zur App-Service-Rechnung).',
    );
  }

  if (correctionType === 'fee_refund' && cleanInvoiceId && cleanBatchId) {
    const Invoice = Parse.Object.extend('Invoice');
    let inv;
    try {
      inv = await new Parse.Query(Invoice).get(cleanInvoiceId, { useMasterKey: true });
    } catch (_) {
      throw new Parse.Error(
        Parse.Error.OBJECT_NOT_FOUND,
        'Gebührenerstattung: Rechnung (invoiceId) nicht gefunden.',
      );
    }
    if (!isServiceChargeInvoiceType(String(inv.get('invoiceType') || ''))) {
      throw new Parse.Error(
        Parse.Error.INVALID_VALUE,
        'Gebührenerstattung: Die angegebene Rechnung ist keine App-Servicegebühr (invoiceType).',
      );
    }
    const invUser = String(inv.get('userId') || inv.get('customerId') || '').trim();
    const target = String(targetId || '').trim();
    if (!invUser || !target || invUser !== target) {
      throw new Parse.Error(
        Parse.Error.INVALID_VALUE,
        'Gebührenerstattung: Rechnung gehört nicht zur angegebenen User-ID (targetId).',
      );
    }
    const invBatch = String(inv.get('batchId') || '').trim();
    if (!invBatch || invBatch !== cleanBatchId) {
      throw new Parse.Error(
        Parse.Error.INVALID_VALUE,
        'Gebührenerstattung: batchId stimmt nicht mit dem Batch der Rechnung überein.',
      );
    }
  }

  const FourEyesRequest = Parse.Object.extend('FourEyesRequest');
  const fourEyesReq = new FourEyesRequest();
  fourEyesReq.set('requestType', 'correction');
  fourEyesReq.set('requesterId', request.user.id);
  fourEyesReq.set('requesterRole', request.user.get('role'));
  fourEyesReq.set('status', 'pending');
  fourEyesReq.set('expiresAt', new Date(Date.now() + 7 * 24 * 60 * 60 * 1000));

  fourEyesReq.set('metadata', {
    correctionType,
    targetId,
    targetType,
    reason,
    oldValue,
    newValue,
    ...(cleanInvoiceId ? { invoiceId: cleanInvoiceId } : {}),
    ...(cleanBatchId ? { batchId: cleanBatchId } : {}),
  });
  await fourEyesReq.save(null, { useMasterKey: true });

  await logPermissionCheck(request, 'createCorrectionRequest', targetType, targetId);

  return {
    success: true,
    fourEyesRequestId: fourEyesReq.id,
    message: 'Correction request created. Awaiting 4-eyes approval.',
  };
}

async function handleGetCorrectionRequests(request) {
  const { status, limit = 50, skip = 0 } = request.params;

  const query = new Parse.Query('FourEyesRequest');
  query.equalTo('requestType', 'correction');

  if (status) {
    query.equalTo('status', status);
  }

  query.descending('createdAt');
  query.limit(limit);
  query.skip(skip);

  const requests = await query.find({ useMasterKey: true });

  const corrections = requests.map(req => {
    const metadata = req.get('metadata') || {};
    return {
      objectId: req.id,
      type: metadata.correctionType || 'unknown',
      amount: metadata.newValue || 0,
      currency: 'EUR',
      reason: metadata.reason || '',
      status: req.get('status'),
      requestedBy: req.get('requesterId'),
      createdAt: req.get('createdAt').toISOString(),
    };
  });

  return { corrections };
}

module.exports = {
  handleGetRoundingDifferences,
  handleCreateCorrectionRequest,
  handleGetCorrectionRequests,
};
