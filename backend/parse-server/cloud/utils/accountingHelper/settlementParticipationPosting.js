'use strict';

const { round2 } = require('./shared');
const { bookAccountStatementEntry, bookSettlementEntry } = require('./statements');
const { bookInvestorCommissionClearingGL } = require('./settlementGLPoster');
const { calculateWithholdingBundle, resolveUserTaxProfile } = require('./taxation');
const { createCollectionBillDocument } = require('./documents');
const { resolveDocumentReference } = require('./documentReferenceResolver');
const {
  computeInvestorBuyLeg,
  computeInvestorSellLeg,
  deriveMirrorTradeBasis,
  applyPoolCapitalSplitToBuyLeg,
} = require('./legs');
const { splitCommissionFromGrossProfit } = require('./commissionSplit');
const { sumStatementAmounts, getStatementSumsByType } = require('./settlementQueries');
const { bookInvestorTaxEntries } = require('./settlementTaxEntries');
const { createCommissionRecord, createNotification, formatCurrency } = require('./settlementSupport');
const {
  bookReserveCapitalTradeSplit,
  bookTradeSettlementPayout,
  hasEscrowLeg,
  resolveActivationCapitalSplitAmounts,
} = require('./investmentEscrow');

async function settleNewParticipation({
  participation,
  investment,
  trade,
  traderId,
  tradeNumber,
  commissionRates,
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

  if (participation.get('isSettled')) {
    const priorBillQ = new Parse.Query('Document');
    priorBillQ.equalTo('tradeId', trade.id);
    priorBillQ.equalTo('investmentId', investment.id);
    priorBillQ.equalTo('type', 'investorCollectionBill');
    priorBillQ.equalTo('source', 'backend');
    const priorBill = await priorBillQ.first({ useMasterKey: true });
    if (!priorBill) {
      participation.set('isSettled', false);
      participation.unset('settledAt');
      await participation.save(null, { useMasterKey: true });
    }
  }

  let buyLeg = null;
  let sellLeg = null;
  if (tradeBuyPrice > 0 && investmentCapital > 0) {
    buyLeg = computeInvestorBuyLeg(investmentCapital, tradeBuyPrice, feeConfig);
    const capitalSplit = await resolveActivationCapitalSplitAmounts(investment, trade, investmentCapital);
    if (buyLeg && capitalSplit.tradingAmount > 0) {
      buyLeg = applyPoolCapitalSplitToBuyLeg(
        buyLeg,
        capitalSplit.tradingAmount,
        capitalSplit.residualAmt,
        capitalSplit.poolPieces,
      );
    }
    if (buyLeg && tradeSellPrice > 0) {
      sellLeg = computeInvestorSellLeg(buyLeg.quantity, tradeSellPrice, 1.0, feeConfig);
    }
  }

  const totalCommissionRate = commissionRates.totalRate;
  let profitShare = proportionalProfitShare;
  let basis = 'proportional';
  let split = splitCommissionFromGrossProfit(profitShare, commissionRates);
  let commission = split.commission;
  let traderCommission = split.traderCommission;
  let appCommission = split.appCommission;
  let netProfit = split.netProfit;
  const mirror = deriveMirrorTradeBasis(buyLeg, sellLeg, totalCommissionRate);
  if (mirror) {
    profitShare = mirror.grossProfit;
    split = splitCommissionFromGrossProfit(profitShare, commissionRates);
    commission = split.commission;
    traderCommission = split.traderCommission;
    appCommission = split.appCommission;
    netProfit = split.netProfit;
    basis = 'mirror';
  }

  console.log(
    `  📊 Participation ${participation.id}: ownership=${rawOwnership} (ratio=${ownershipRatio.toFixed(4)}), `
    + `profit=€${profitShare}, comm=€${commission} (trader €${traderCommission}, app €${appCommission}), `
    + `net=€${netProfit} [${basis}]`,
  );

  const investorProfile = await resolveUserTaxProfile(investorId);
  const taxBreakdown = calculateWithholdingBundle({
    taxableAmount: netProfit,
    taxConfig,
    userProfile: investorProfile,
  });

  const collectionBill = await createCollectionBillDocument({
    investorId,
    investmentId: investment.id,
    trade,
    ownershipPercentage: round2(ownershipRatio * 100),
    grossProfit: profitShare,
    commission,
    traderCommission,
    appCommission,
    netProfit,
    commissionRate: totalCommissionRate,
    traderCommissionRate: commissionRates.traderRate,
    appCommissionRate: commissionRates.appRate,
    investmentCapital,
    buyLeg,
    sellLeg,
    taxBreakdown,
    businessCaseId,
    allowIdempotentUpsert: true,
  });
  const collectionBillRef = resolveDocumentReference(collectionBill, { context: 'investor_collection_bill' });

  participation.set('profitShare', profitShare);
  participation.set('commissionAmount', commission);
  participation.set('commissionRate', totalCommissionRate);
  participation.set('traderCommissionAmount', traderCommission);
  participation.set('appCommissionAmount', appCommission);
  participation.set('grossReturn', netProfit);
  participation.set('profitBasis', basis);
  participation.set('isSettled', true);
  participation.set('settledAt', new Date());
  await participation.save(null, { useMasterKey: true });

  const beleg = collectionBill.get('metadata') || {};
  const transferAmount = round2(beleg.transferAmount ?? 0);
  if (transferAmount <= 0) {
    throw new Error(
      `GoB fail-closed: Collection bill ${collectionBillRef.referenceDocumentNumber || collectionBill.id} `
      + 'missing transferAmount',
    );
  }
  const bookedResidual = round2(beleg.residualAmount ?? (buyLeg && buyLeg.residualAmount) ?? 0);
  const poolTradingAmount = round2(beleg.poolTradingAmount ?? beleg.totalBuyCost ?? 0);

  const alreadyReturned = await sumStatementAmounts({
    userId: investorId,
    tradeId: trade.id,
    investmentId: investment.id,
    entryType: 'investment_return',
    absolute: true,
  });
  const remainingTransfer = round2(Math.abs(transferAmount) - alreadyReturned);
  if (remainingTransfer > 0) {
    await bookAccountStatementEntry({
      userId: investorId,
      entryType: 'investment_return',
      amount: remainingTransfer,
      tradeId: trade.id,
      tradeNumber,
      investmentId: investment.id,
      investmentNumber,
      description: `Abrechnung Trade #${tradeNumber} – Überweisungsbetrag ${investmentNumber}`,
      ...collectionBillRef,
      businessCaseId,
    });
  }

  await bookTradeSettlementPayout({
    investorId,
    investmentId: investment.id,
    investmentNumber,
    tradeId: trade.id,
    tradeNumber,
    tradingAmount: poolTradingAmount,
    netProfit: round2(beleg.netProfit ?? netProfit),
    transferAmount,
    businessCaseId,
    collectionBillRef,
  });

  if (commission > 0) {
    await bookInvestorCommissionClearingGL({
      userId: investorId,
      tradeId: trade.id,
      tradeNumber,
      investmentId: investment.id,
      investmentNumber,
      commission,
      description: `Provision Trade #${tradeNumber} (${(totalCommissionRate * 100).toFixed(0)}%)`,
      referenceDocumentId: collectionBillRef.referenceDocumentId,
      referenceDocumentNumber: collectionBillRef.referenceDocumentNumber,
      businessCaseId,
    });
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
  if (buyLeg && investmentCapital > 0) {
    const splitAlreadyBooked = await hasEscrowLeg(
      investment.id,
      'reserveCapitalTradeSplit',
      { tradeId: trade.id },
    );
    if (!splitAlreadyBooked) {
      await bookReserveCapitalTradeSplit({
        investorId,
        nominal: round2(beleg.investmentNominal ?? investmentCapital),
        tradingAmount: poolTradingAmount,
        availableAmount: bookedResidual,
        investmentId: investment.id,
        investmentNumber,
        tradeId: trade.id,
        tradeNumber,
        businessCaseId,
      });
    }
    if (bookedResidual > 0) {
      const existingResidualStmt = await new Parse.Query('AccountStatement')
        .equalTo('userId', investorId)
        .equalTo('investmentId', investment.id)
        .equalTo('tradeId', trade.id)
        .equalTo('entryType', 'residual_return')
        .equalTo('source', 'backend')
        .first({ useMasterKey: true });
      if (!existingResidualStmt) {
        await bookAccountStatementEntry({
          userId: investorId,
          entryType: 'residual_return',
          amount: bookedResidual,
          tradeId: trade.id,
          tradeNumber,
          investmentId: investment.id,
          investmentNumber,
          description: investmentNumber
            ? `Restbetrag aus Investment ${investmentNumber}`
            : `Restbetrag aus Investment (Rundungsdifferenz Stückkauf)`,
          ...collectionBillRef,
          businessCaseId,
        });
      }
    }
  }

  const currentStatus = investment.get('status') || 'reserved';
  if (currentStatus !== 'completed') {
    investment.set('status', 'completed');
    if (!investment.get('completedAt')) {
      investment.set('completedAt', new Date().toISOString());
    }
  }
  await investment.save(null, { useMasterKey: true });

  await createCommissionRecord(traderId, investment, trade, participation, traderCommission);
  await createNotification(
    investorId,
    'investment_profit',
    'investment',
    'Gewinn erzielt',
    `Ihr Investment hat einen Gewinn von ${formatCurrency(netProfit - taxBreakdown.totalTax)} nach Steuerabzug erzielt.`
  );

  return {
    investorId,
    investorName: String(investment.get('investorName') || participation.get('investorName') || '').trim() || null,
    investmentId: investment.id,
    grossProfit: profitShare,
    commission,
    traderCommission,
    appCommission,
    taxWithheld: taxBreakdown.totalTax,
  };
}

module.exports = {
  settleNewParticipation,
};
