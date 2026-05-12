'use strict';

const investmentEscrow = require('../utils/accountingHelper/investmentEscrow');
const { round2 } = require('../utils/accountingHelper/shared');
const { bookAccountStatementEntry } = require('../utils/accountingHelper/statements');
const { createWalletReceiptDocument } = require('../utils/accountingHelper/documents');
const { resolveDocumentReference } = require('../utils/accountingHelper/documentReferenceResolver');
const {
  formatCurrency,
  createNotification,
  processWalletTransaction,
} = require('./investmentTriggerHelpers');

async function handleInvestmentAfterSaveCompleted(investment, oldStatus) {
  const investorId = investment.get('investorId');
  const profit = investment.get('profit') || 0;
  const finalValue = investment.get('currentValue');
  const businessCaseId = String(investment.get('businessCaseId') || '').trim();

  await createNotification(investorId, 'investment_completed', 'investment',
    'Investment abgeschlossen',
    `Ihr Investment wurde abgeschlossen. Gewinn: ${formatCurrency(profit)}`);

  await processWalletTransaction(investorId, 'investment_return', finalValue,
    `Investment Rückzahlung ${investment.get('investmentNumber')}`,
    'investment', investment.id);

  const existingReturn = await new Parse.Query('AccountStatement')
    .equalTo('investmentId', investment.id)
    .equalTo('entryType', 'investment_return')
    .equalTo('source', 'backend')
    .first({ useMasterKey: true });

  if (!existingReturn) {
    try {
      const receipt = await createWalletReceiptDocument({
        userId: investorId,
        receiptType: 'investment_return',
        amount: finalValue,
        description: `Investment Rückzahlung ${investment.get('investmentNumber')}`,
        referenceType: 'Investment',
        referenceId: investment.id,
        metadata: {
          investmentNumber: investment.get('investmentNumber'),
          profit,
          finalValue,
          businessCaseId,
        },
        businessCaseId,
      });
      const receiptRef = resolveDocumentReference(receipt, { context: 'investment_return' });

      await bookAccountStatementEntry({
        userId: investorId,
        entryType: 'investment_return',
        amount: Math.abs(finalValue),
        investmentId: investment.id,
        investmentNumber: investment.get('investmentNumber') || '',
        description: `Investment ${investment.get('investmentNumber')} Rückzahlung`,
        ...receiptRef,
        businessCaseId,
      });
    } catch (err) {
      console.error(`❌ GoB receipt failed for investment return ${investment.id}:`, err.message);
    }
  }

  try {
    const invNo = investment.get('investmentNumber') || '';
    const fv = round2(finalValue || 0);
    if (oldStatus === 'reserved') {
      await investmentEscrow.bookReleaseReservedOnComplete({
        investorId,
        amount: fv,
        investmentId: investment.id,
        investmentNumber: invNo,
        businessCaseId,
      });
    } else if (['active', 'executing', 'paused', 'closing'].includes(oldStatus)) {
      await investmentEscrow.bookReleaseTrading({
        investorId,
        amount: fv,
        investmentId: investment.id,
        investmentNumber: invNo,
        reason: 'complete',
        businessCaseId,
      });
    }
  } catch (err) {
    console.error(`❌ investmentEscrow release on complete failed ${investment.id}:`, err.message);
  }
}

module.exports = {
  handleInvestmentAfterSaveCompleted,
};
