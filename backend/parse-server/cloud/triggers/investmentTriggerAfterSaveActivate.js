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

async function handleInvestmentAfterSaveActivated(investment) {
  const investorId = investment.get('investorId');
  const traderId = investment.get('traderId');
  const amount = investment.get('amount');
  const businessCaseId = String(investment.get('businessCaseId') || '').trim();

  try {
    await investmentEscrow.bookDeployToTrading({
      investorId,
      amount: round2(amount),
      investmentId: investment.id,
      investmentNumber: investment.get('investmentNumber') || '',
      businessCaseId,
    });
  } catch (err) {
    console.error(`❌ investmentEscrow.bookDeployToTrading failed ${investment.id}:`, err.message);
  }

  try {
    await createNotification(investorId, 'investment_activated', 'investment',
      'Investment aktiviert',
      `Ihr Investment ${investment.get('investmentNumber')} ist jetzt aktiv.`);
  } catch (err) {
    console.error(`❌ createNotification (investment_activated) failed ${investment.id}:`, err.message);
  }

  try {
    await processWalletTransaction(investorId, 'investment', -amount,
      `Investment ${investment.get('investmentNumber')}`,
      'investment', investment.id);
  } catch (err) {
    console.error(`❌ processWalletTransaction (investment activation) failed ${investment.id}:`, err.message);
  }

  try {
    const receipt = await createWalletReceiptDocument({
      userId: investorId,
      receiptType: 'investment',
      amount: -amount,
      description: `Investment Aktivierung ${investment.get('investmentNumber')}`,
      referenceType: 'Investment',
      referenceId: investment.id,
      metadata: {
        investmentNumber: investment.get('investmentNumber'),
        traderId,
        businessCaseId,
      },
      businessCaseId,
    });
    const receiptRef = resolveDocumentReference(receipt, { context: 'investment_activate' });

    await bookAccountStatementEntry({
      userId: investorId,
      entryType: 'investment_activate',
      amount: -Math.abs(amount),
      investmentId: investment.id,
      investmentNumber: investment.get('investmentNumber') || '',
      description: `Investment ${investment.get('investmentNumber')} aktiviert`,
      ...receiptRef,
      businessCaseId,
    });
  } catch (err) {
    console.error(`❌ GoB receipt failed for investment activation ${investment.id}:`, err.message);
  }

  try {
    const chargeTotal = investment.get('serviceChargeTotal') || 0;
    if (chargeTotal > 0) {
      await Parse.Cloud.run(
        'bookAppServiceCharge',
        { investmentId: investment.id },
        { useMasterKey: true },
      );
    }
  } catch (err) {
    console.error(`❌ bookAppServiceCharge (afterSave Investment activation) ${investment.id}:`, err.message);
  }
}

module.exports = {
  handleInvestmentAfterSaveActivated,
};
