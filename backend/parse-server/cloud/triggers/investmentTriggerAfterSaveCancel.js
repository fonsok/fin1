'use strict';

const investmentEscrow = require('../utils/accountingHelper/investmentEscrow');
const { round2 } = require('../utils/accountingHelper/shared');
const { bookAccountStatementEntry } = require('../utils/accountingHelper/statements');
const { createWalletReceiptDocument } = require('../utils/accountingHelper/documents');
const { resolveDocumentReference } = require('../utils/accountingHelper/documentReferenceResolver');
const {
  createNotification,
  processWalletTransaction,
} = require('./investmentTriggerHelpers');

async function handleInvestmentAfterSaveCancelled(investment, oldStatus, amount) {
  const investorId = investment.get('investorId');
  const businessCaseId = String(investment.get('businessCaseId') || '').trim();

  const activeLike = ['active', 'executing', 'paused', 'closing'];
  if (activeLike.includes(oldStatus)) {
    const refundAmount = investment.get('currentValue');
    await processWalletTransaction(investorId, 'refund', refundAmount,
      `Investment Stornierung ${investment.get('investmentNumber')}`,
      'investment', investment.id);

    try {
      const receipt = await createWalletReceiptDocument({
        userId: investorId,
        receiptType: 'refund',
        amount: refundAmount,
        description: `Investment Stornierung ${investment.get('investmentNumber')}`,
        referenceType: 'Investment',
        referenceId: investment.id,
        metadata: {
          investmentNumber: investment.get('investmentNumber'),
          refundAmount,
          businessCaseId,
        },
        businessCaseId,
      });
      const receiptRef = resolveDocumentReference(receipt, { context: 'investment_refund' });

      await bookAccountStatementEntry({
        userId: investorId,
        entryType: 'investment_refund',
        amount: Math.abs(refundAmount),
        investmentId: investment.id,
        investmentNumber: investment.get('investmentNumber') || '',
        description: `Investment ${investment.get('investmentNumber')} Stornierung/Rückerstattung`,
        ...receiptRef,
        businessCaseId,
      });
    } catch (err) {
      console.error(`❌ GoB receipt failed for investment refund ${investment.id}:`, err.message);
    }

    try {
      await investmentEscrow.bookReleaseTrading({
        investorId,
        amount: round2(refundAmount || 0),
        investmentId: investment.id,
        investmentNumber: investment.get('investmentNumber') || '',
        reason: 'refund',
        businessCaseId,
      });
    } catch (err) {
      console.error(`❌ investmentEscrow.bookReleaseTrading (refund) failed ${investment.id}:`, err.message);
    }
  }

  if (oldStatus === 'reserved') {
    const refundReserved = round2(amount);
    if (refundReserved > 0) {
      try {
        await investmentEscrow.bookReleaseReservation({
          investorId,
          amount: refundReserved,
          investmentId: investment.id,
          investmentNumber: investment.get('investmentNumber') || '',
          businessCaseId,
        });
      } catch (err) {
        console.error(`❌ investmentEscrow.bookReleaseReservation failed ${investment.id}:`, err.message);
      }

      try {
        await processWalletTransaction(investorId, 'refund', refundReserved,
          `Investment Reservierung aufgehoben ${investment.get('investmentNumber')}`,
          'investment', investment.id);

        const receipt = await createWalletReceiptDocument({
          userId: investorId,
          receiptType: 'refund',
          amount: refundReserved,
          description: `Investment Reservierung aufgehoben ${investment.get('investmentNumber')}`,
          referenceType: 'Investment',
          referenceId: investment.id,
          metadata: {
            investmentNumber: investment.get('investmentNumber'),
            reason: 'reserved_cancel',
            businessCaseId,
          },
          businessCaseId,
        });
        const receiptRef = resolveDocumentReference(receipt, { context: 'investment_reserved_cancel_refund' });

        await bookAccountStatementEntry({
          userId: investorId,
          entryType: 'investment_refund',
          amount: Math.abs(refundReserved),
          investmentId: investment.id,
          investmentNumber: investment.get('investmentNumber') || '',
          description: `Reservierung storniert ${investment.get('investmentNumber')}`,
          ...receiptRef,
          businessCaseId,
        });
      } catch (err) {
        console.error(`❌ GoB refund failed for reserved cancel ${investment.id}:`, err.message);
      }
    }
  }

  await createNotification(investorId, 'investment_cancelled', 'investment',
    'Investment storniert',
    `Ihr Investment ${investment.get('investmentNumber')} wurde storniert.`,
    'high');
}

module.exports = {
  handleInvestmentAfterSaveCancelled,
};
