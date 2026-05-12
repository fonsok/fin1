'use strict';

const {
  applyLedgerSnapshotToEntry,
  mergeMetadataWithSnapshot,
} = require('../../../utils/accountingHelper/accountMappingResolver');
const { resolveDocumentRefForFeeRefund } = require('../../../utils/accountingHelper/documents');

function round2(value) {
  return Math.round(value * 100) / 100;
}

async function getCurrentBalance(targetId) {
  const WalletTransaction = Parse.Object.extend('WalletTransaction');
  const lastTxQuery = new Parse.Query(WalletTransaction);
  lastTxQuery.equalTo('userId', targetId);
  lastTxQuery.equalTo('status', 'completed');
  lastTxQuery.descending('completedAt');
  const lastTx = await lastTxQuery.first({ useMasterKey: true });
  return lastTx ? (lastTx.get('balanceAfter') || 0) : 0;
}

async function createWalletCorrectionTransaction({
  userId,
  transactionType,
  amount,
  referenceId,
  description,
  metadata,
}) {
  const currentBalance = await getCurrentBalance(userId);
  const WalletTransaction = Parse.Object.extend('WalletTransaction');
  const tx = new WalletTransaction();
  tx.set('userId', userId);
  tx.set('transactionType', transactionType);
  tx.set('amount', amount);
  tx.set('balanceBefore', currentBalance);
  tx.set('balanceAfter', currentBalance + amount);
  tx.set('status', 'completed');
  tx.set('completedAt', new Date());
  tx.set('referenceType', 'correction');
  tx.set('referenceId', referenceId);
  tx.set('description', description);
  tx.set('metadata', metadata || {});
  await tx.save(null, { useMasterKey: true });
}

async function createAppLedgerEntry({
  account,
  side,
  amount,
  userId,
  userRole,
  transactionType,
  referenceId,
  referenceType,
  description,
  metadata,
}) {
  const AppLedgerEntry = Parse.Object.extend('AppLedgerEntry');
  const entry = new AppLedgerEntry();
  entry.set('account', account);
  const snapshot = applyLedgerSnapshotToEntry(entry, account);
  entry.set('side', side);
  entry.set('amount', round2(amount));
  entry.set('userId', userId);
  entry.set('userRole', userRole);
  entry.set('transactionType', transactionType);
  entry.set('referenceId', referenceId);
  entry.set('referenceType', referenceType);
  entry.set('description', description);
  entry.set('metadata', mergeMetadataWithSnapshot(metadata || {}, snapshot));
  await entry.save(null, { useMasterKey: true });
}

async function applyCorrectionRequest({ metadata, requestId, approverId }) {
  const correctionType = metadata.correctionType;
  const targetId = metadata.targetId;
  const amount = parseFloat(metadata.newValue) || 0;
  const reason = metadata.reason || 'Korrekturbuchung';
  let applied = false;

  if (correctionType === 'fee_refund' && targetId && amount > 0) {
    await createWalletCorrectionTransaction({
      userId: targetId,
      transactionType: 'refund',
      amount,
      referenceId: requestId,
      description: `Gebührenerstattung: ${reason}`,
      metadata: { fourEyesRequestId: requestId, correctionType, approvedBy: approverId },
    });

    const vatRate = 0.19;
    const netAmount = amount / (1 + vatRate);
    const vatAmount = amount - netAmount;

    let feeRefundDocRefs = {};
    try {
      feeRefundDocRefs = await resolveDocumentRefForFeeRefund(targetId, amount, {
        invoiceId: metadata.invoiceId,
        batchId: metadata.batchId,
      });
    } catch (err) {
      console.warn('resolveDocumentRefForFeeRefund failed:', err.message);
    }
    const feeRefundBelegMeta = {
      fourEyesRequestId: requestId,
      businessReference: `4-Augen Gebührenerstattung · Antrag ${requestId}`,
      ...feeRefundDocRefs,
    };

    await createAppLedgerEntry({
      account: 'PLT-REV-PSC',
      side: 'debit',
      amount: netAmount,
      userId: targetId,
      userRole: 'investor',
      transactionType: 'reversal',
      referenceId: requestId,
      referenceType: 'refund',
      description: `Storno Appgebühr – ${reason}`,
      metadata: {
        step: 'revenue_reversal',
        ...feeRefundBelegMeta,
      },
    });

    await createAppLedgerEntry({
      account: 'PLT-TAX-VAT',
      side: 'debit',
      amount: vatAmount,
      userId: targetId,
      userRole: 'investor',
      transactionType: 'reversal',
      referenceId: requestId,
      referenceType: 'refund',
      description: `Storno USt – ${reason}`,
      metadata: {
        step: 'vat_reversal',
        ...feeRefundBelegMeta,
      },
    });

    applied = true;
    console.log(`✅ Fee refund of €${amount} applied to user ${targetId} via 4-eyes approval`);
  } else if (correctionType === 'balance_adjustment' && targetId && amount > 0) {
    await createWalletCorrectionTransaction({
      userId: targetId,
      transactionType: 'adjustment',
      amount,
      referenceId: requestId,
      description: `Kontokorrektur: ${reason}`,
      metadata: { fourEyesRequestId: requestId, correctionType, approvedBy: approverId },
    });

    applied = true;
    console.log(`✅ Balance adjustment of €${amount} applied to user ${targetId}`);
  } else if (correctionType === 'vat_remittance' && amount > 0) {
    await createAppLedgerEntry({
      account: 'PLT-TAX-VAT',
      side: 'debit',
      amount,
      userId: 'SYSTEM',
      userRole: 'app',
      transactionType: 'vatRemittance',
      referenceId: requestId,
      referenceType: 'vat_remittance',
      description: `USt-Abführung Finanzamt – ${reason}`,
      metadata: {
        step: 'vat_liability_reduction',
        fourEyesRequestId: requestId,
        businessReference: `4-Augen USt-Abführung · Antrag ${requestId}`,
      },
    });

    await createAppLedgerEntry({
      account: 'PLT-CLR-VAT',
      side: 'credit',
      amount,
      userId: 'SYSTEM',
      userRole: 'app',
      transactionType: 'vatRemittance',
      referenceId: requestId,
      referenceType: 'vat_remittance',
      description: `USt-Zahlung Verrechnungskonto – ${reason}`,
      metadata: {
        step: 'settlement',
        fourEyesRequestId: requestId,
        businessReference: `4-Augen USt-Abführung · Antrag ${requestId}`,
      },
    });

    applied = true;
    console.log(`✅ VAT remittance of €${amount} recorded via 4-eyes approval`);
  }

  return { applied, correctionType, targetId, amount, reason };
}

module.exports = {
  applyCorrectionRequest,
};
