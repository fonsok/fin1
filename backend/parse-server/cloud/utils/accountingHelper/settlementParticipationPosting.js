'use strict';

const { round2 } = require('./shared');
const { bookAccountStatementEntry, bookSettlementEntry } = require('./statements');
const { calculateWithholdingBundle, resolveUserTaxProfile } = require('./taxation');
const { createCollectionBillDocument, createWalletReceiptDocument } = require('./documents');
const { resolveDocumentReference } = require('./documentReferenceResolver');
const { computeInvestorBuyLeg, computeInvestorSellLeg, deriveMirrorTradeBasis } = require('./legs');
const { sumStatementAmounts, getStatementSumsByType } = require('./settlementQueries');
const { bookInvestorTaxEntries } = require('./settlementTaxEntries');
const { createCommissionRecord, createNotification, formatCurrency } = require('./settlementSupport');

async function settleNewParticipation({
  participation,
  investment,
  trade,
  traderId,
  tradeNumber,
  commissionRate,
  feeConfig,
  tradeBuyPrice,
  tradeSellPrice,
  taxConfig,
  proportionalProfitShare,
  proportionalCommission,
  proportionalNetProfit,
  rawOwnership,
  ownershipRatio,
  businessCaseId,
}) {
  const investorId = investment.get('investorId');
  const investmentCapital = investment.get('amount') || 0;
  const investmentNumber = investment.get('investmentNumber') || investment.id;

  let buyLeg = null;
  let sellLeg = null;
  if (tradeBuyPrice > 0 && investmentCapital > 0) {
    buyLeg = computeInvestorBuyLeg(investmentCapital, tradeBuyPrice, feeConfig);
    if (buyLeg && tradeSellPrice > 0) {
      sellLeg = computeInvestorSellLeg(buyLeg.quantity, tradeSellPrice, 1.0, feeConfig);
    }
  }

  let profitShare = proportionalProfitShare;
  let commission = proportionalCommission;
  let netProfit = proportionalNetProfit;
  let basis = 'proportional';
  const mirror = deriveMirrorTradeBasis(buyLeg, sellLeg, commissionRate);
  if (mirror) {
    profitShare = mirror.grossProfit;
    commission = mirror.commission;
    netProfit = mirror.netProfit;
    basis = 'mirror';
  }

  console.log(`  📊 Participation ${participation.id}: ownership=${rawOwnership} (ratio=${ownershipRatio.toFixed(4)}), profit=€${profitShare}, comm=€${commission}, net=€${netProfit} [${basis}]`);

  participation.set('profitShare', profitShare);
  participation.set('commissionAmount', commission);
  participation.set('commissionRate', commissionRate);
  participation.set('grossReturn', netProfit);
  participation.set('profitBasis', basis);
  participation.set('isSettled', true);
  participation.set('settledAt', new Date());
  await participation.save(null, { useMasterKey: true });

  const investorProfile = await resolveUserTaxProfile(investorId);
  const taxBreakdown = calculateWithholdingBundle({
    taxableAmount: netProfit,
    taxConfig,
    userProfile: investorProfile,
  });

  const existingActivation = await new Parse.Query('AccountStatement')
    .equalTo('investmentId', investment.id)
    .equalTo('entryType', 'investment_activate')
    .equalTo('source', 'backend')
    .first({ useMasterKey: true });

  if (!existingActivation && investmentCapital > 0) {
    const invBc = String(investment.get('businessCaseId') || '').trim();
    const activateReceipt = await createWalletReceiptDocument({
      userId: investorId,
      receiptType: 'investment',
      amount: -investmentCapital,
      description: `Investment ${investmentNumber} aktiviert – Abbuchung vom Anlagekonto`,
      referenceType: 'Investment',
      referenceId: investment.id,
      metadata: { investmentNumber, traderId, businessCaseId: invBc || businessCaseId },
      businessCaseId: invBc || businessCaseId,
    });
    const activateReceiptRef = resolveDocumentReference(activateReceipt, { context: 'investment_activate' });
    await bookAccountStatementEntry({
      userId: investorId,
      entryType: 'investment_activate',
      amount: -Math.abs(investmentCapital),
      investmentId: investment.id,
      investmentNumber,
      description: `Investment ${investmentNumber} aktiviert`,
      ...activateReceiptRef,
      businessCaseId: invBc || businessCaseId,
    });
  }

  const collectionBill = await createCollectionBillDocument({
    investorId,
    investmentId: investment.id,
    trade,
    ownershipPercentage: round2(ownershipRatio * 100),
    grossProfit: profitShare,
    commission,
    netProfit,
    commissionRate,
    investmentCapital,
    buyLeg,
    sellLeg,
    taxBreakdown,
    businessCaseId,
  });
  const collectionBillRef = resolveDocumentReference(collectionBill, { context: 'investor_collection_bill' });

  const grossReturn = investmentCapital + profitShare;
  const alreadyReturned = await sumStatementAmounts({
    userId: investorId,
    tradeId: trade.id,
    investmentId: investment.id,
    entryType: 'investment_return',
    absolute: true,
  });
  const remainingGrossReturn = round2(Math.abs(grossReturn) - alreadyReturned);
  if (remainingGrossReturn > 0) {
    await bookAccountStatementEntry({
      userId: investorId,
      entryType: 'investment_return',
      amount: remainingGrossReturn,
      tradeId: trade.id,
      tradeNumber,
      investmentId: investment.id,
      investmentNumber,
      description: `Abrechnung Trade #${tradeNumber} – Rückzahlung ${investmentNumber}`,
      ...collectionBillRef,
      businessCaseId,
    });
  }

  if (commission > 0) {
    const alreadyCommissionDebited = await sumStatementAmounts({
      userId: investorId,
      tradeId: trade.id,
      investmentId: investment.id,
      entryType: 'commission_debit',
      absolute: true,
    });
    const remainingCommission = round2(Math.abs(commission) - alreadyCommissionDebited);
    if (remainingCommission > 0) {
      await bookSettlementEntry({
        userId: investorId,
        userRole: 'investor',
        entryType: 'commission_debit',
        amount: -Math.abs(remainingCommission),
        tradeId: trade.id,
        tradeNumber,
        investmentId: investment.id,
        investmentNumber,
        description: `Provision Trade #${tradeNumber} (${(commissionRate * 100).toFixed(0)}%)`,
        ...collectionBillRef,
        businessCaseId,
      });
    }
  }

  const alreadyTaxDebitsByType = await getStatementSumsByType({
    userId: investorId,
    tradeId: trade.id,
    investmentId: investment.id,
    entryTypes: ['withholding_tax_debit', 'solidarity_surcharge_debit', 'church_tax_debit'],
    absolute: true,
  });
  const remainingTaxBreakdown = {
    withholdingTax: Math.max(0, round2((taxBreakdown.withholdingTax || 0) - (alreadyTaxDebitsByType.withholding_tax_debit || 0))),
    solidaritySurcharge: Math.max(0, round2((taxBreakdown.solidaritySurcharge || 0) - (alreadyTaxDebitsByType.solidarity_surcharge_debit || 0))),
    churchTax: Math.max(0, round2((taxBreakdown.churchTax || 0) - (alreadyTaxDebitsByType.church_tax_debit || 0))),
  };
  remainingTaxBreakdown.totalTax = round2(
    remainingTaxBreakdown.withholdingTax
    + remainingTaxBreakdown.solidaritySurcharge
    + remainingTaxBreakdown.churchTax
  );
  if (remainingTaxBreakdown.totalTax > 0) {
    await bookInvestorTaxEntries({
      investorId,
      investmentId: investment.id,
      investmentNumber,
      trade,
      tradeNumber,
      collectionBillId: collectionBillRef.referenceDocumentId,
      collectionBillNumber: collectionBillRef.referenceDocumentNumber,
      taxBreakdown: remainingTaxBreakdown,
      bookSettlementEntry,
      businessCaseId,
    });
  }

  const updatedCurrentValue = (investment.get('currentValue') || 0) + netProfit;
  const updatedProfit = (investment.get('profit') || 0) + netProfit;
  const updatedCommission = (investment.get('totalCommissionPaid') || 0) + commission;
  const updatedTradeCount = (investment.get('numberOfTrades') || 0) + 1;
  investment.set('currentValue', round2(updatedCurrentValue));
  investment.set('profit', round2(updatedProfit));
  investment.set('totalCommissionPaid', round2(updatedCommission));
  investment.set('numberOfTrades', updatedTradeCount);

  const initialValue = investment.get('initialValue') || investmentCapital;
  if (initialValue > 0) {
    investment.set('profitPercentage', round2((updatedProfit / initialValue) * 100));
  }
  const currentStatus = investment.get('status') || 'reserved';
  if (currentStatus !== 'completed') {
    investment.set('status', 'completed');
    if (!investment.get('completedAt')) {
      investment.set('completedAt', new Date().toISOString());
    }
  }
  await investment.save(null, { useMasterKey: true });

  if (buyLeg && buyLeg.residualAmount > 0) {
    await bookAccountStatementEntry({
      userId: investorId,
      entryType: 'residual_return',
      amount: round2(buyLeg.residualAmount),
      tradeId: trade.id,
      tradeNumber,
      investmentId: investment.id,
      investmentNumber,
      description: `Restbetrag Trade #${tradeNumber} (Rundungsdifferenz Stückkauf)`,
      ...collectionBillRef,
      businessCaseId,
    });
  }

  await createCommissionRecord(traderId, investment, trade, participation, commission);
  await createNotification(
    investorId,
    'investment_profit',
    'investment',
    'Gewinn erzielt',
    `Ihr Investment hat einen Gewinn von ${formatCurrency(netProfit - taxBreakdown.totalTax)} nach Steuerabzug erzielt.`
  );

  return {
    investorId,
    investmentId: investment.id,
    grossProfit: profitShare,
    commission,
    taxWithheld: taxBreakdown.totalTax,
  };
}

module.exports = {
  settleNewParticipation,
};
