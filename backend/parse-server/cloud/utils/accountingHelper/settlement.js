'use strict';

const { calculateOrderFees } = require('../helpers');
const { getTraderCommissionRate, loadConfig } = require('../configHelper/index.js');
const { round2 } = require('./shared');
const { bookAccountStatementEntry } = require('./statements');
const { calculateWithholdingBundle, resolveUserTaxProfile } = require('./taxation');
const {
  createCreditNoteDocument,
  createCollectionBillDocument,
  createWalletReceiptDocument,
  createTradeExecutionDocument,
} = require('./documents');
const { computeInvestorBuyLeg, computeInvestorSellLeg } = require('./legs');

// ============================================================================
// Unified trade settlement — SINGLE SOURCE OF TRUTH for all financial numbers
//
// GoB compliance: Every AccountStatement entry carries a referenceDocumentId
// (Keine Buchung ohne Beleg)
//
// Flow:
//   1. Compute net trading profit (gross - trading fees)
//   2. For each PoolTradeParticipation:
//      a. Compute investor profit share (from ownership ratio)
//      b. Compute commission
//      c. Update PoolTradeParticipation (mark settled)
//      d. Find and update Investment
//      e. Create Collection Bill document (Beleg)
//      f. Book AccountStatement entries WITH referenceDocumentId
//      g. Book residual_return if buy-leg has residual
//      h. Create Commission record
//      i. Notify investor
//   3. Create Credit Note document (Beleg)
//   4. Book trader commission_credit WITH referenceDocumentId
// ============================================================================

async function settleAndDistribute(trade) {
  const traderId = trade.get('traderId');
  const tradeNumber = trade.get('tradeNumber');
  const rawGrossProfit = trade.get('grossProfit') || 0;

  if (rawGrossProfit <= 0) {
    console.log(`ℹ️ Trade #${tradeNumber}: grossProfit=${rawGrossProfit}, no settlement needed`);
    return null;
  }

  // ── Idempotency guard ──
  const existingEntry = await new Parse.Query('AccountStatement')
    .equalTo('tradeId', trade.id)
    .equalTo('entryType', 'commission_credit')
    .equalTo('source', 'backend')
    .first({ useMasterKey: true });

  if (existingEntry) {
    console.log(`ℹ️ Trade #${tradeNumber}: already settled, skipping`);
    return null;
  }

  // ── Step 1: Net trading profit (after order fees) ──
  const totalTradingFees = computeTradingFees(trade);
  const netTradingProfit = rawGrossProfit - totalTradingFees;

  if (netTradingProfit <= 0) {
    console.log(`ℹ️ Trade #${tradeNumber}: netTradingProfit=${round2(netTradingProfit)} after fees, no distribution`);
    return null;
  }

  const commissionRate = await getTraderCommissionRate();
  const config = await loadConfig();
  const feeConfig = config.financial;
  const taxConfig = config.tax || {};
  const traderProfile = await resolveUserTaxProfile(traderId);

  console.log(`💰 Settling trade #${tradeNumber}: gross=€${round2(rawGrossProfit)}, fees=€${round2(totalTradingFees)}, net=€${round2(netTradingProfit)}, commRate=${(commissionRate * 100).toFixed(1)}%`);

  // ── Load participations (unsettled only) ──
  const participations = await new Parse.Query('PoolTradeParticipation')
    .equalTo('tradeId', trade.id)
    .equalTo('isSettled', false)
    .find({ useMasterKey: true });

  if (participations.length === 0) {
    console.log(`ℹ️ Trade #${tradeNumber}: no unsettled participations`);
    return null;
  }

  const tradeBuyPrice = trade.get('entryPrice') || trade.get('buyPrice') || 0;
  const tradeSellPrice = trade.get('exitPrice') || trade.get('sellPrice') || 0;

  let totalCommission = 0;
  const investorBreakdown = [];

  // ── Step 2: Process each participation ──
  for (const participation of participations) {
    const result = await settleParticipation({
      participation,
      trade,
      traderId,
      tradeNumber,
      netTradingProfit,
      commissionRate,
      feeConfig,
      tradeBuyPrice,
      tradeSellPrice,
      taxConfig,
    });

    if (result) {
      totalCommission += result.commission;
      investorBreakdown.push(result);
    }
  }

  // ── Step 3: TRADER trade lifecycle — Beleg FIRST, then Buchung ──
  const buyOrder = trade.get('buyOrder');
  const sellOrders = trade.get('sellOrders') || [];
  const sellOrder = trade.get('sellOrder');
  const allSells = sellOrders.length > 0 ? sellOrders : (sellOrder ? [sellOrder] : []);

  if (buyOrder && buyOrder.totalAmount > 0) {
    const buyDoc = await createTradeExecutionDocument({
      traderId, trade, executionType: 'buy',
      amount: buyOrder.totalAmount, order: buyOrder,
    });
    await bookAccountStatementEntry({
      userId: traderId,
      entryType: 'trade_buy',
      amount: -Math.abs(round2(buyOrder.totalAmount)),
      tradeId: trade.id,
      tradeNumber,
      description: `Wertpapierkauf Trade #${tradeNumber} (${trade.get('symbol') || ''})`,
      referenceDocumentId: buyDoc.id,
    });
  }

  for (const so of allSells) {
    if (so && so.totalAmount > 0) {
      const sellDoc = await createTradeExecutionDocument({
        traderId, trade, executionType: 'sell',
        amount: so.totalAmount, order: so,
      });
      await bookAccountStatementEntry({
        userId: traderId,
        entryType: 'trade_sell',
        amount: round2(so.totalAmount),
        tradeId: trade.id,
        tradeNumber,
        description: `Wertpapierverkauf Trade #${tradeNumber} (${trade.get('symbol') || ''})`,
        referenceDocumentId: sellDoc.id,
      });
    }
  }

  if (totalTradingFees > 0) {
    const feeDoc = await createTradeExecutionDocument({
      traderId, trade, executionType: 'fees',
      amount: totalTradingFees, order: buyOrder,
    });
    await bookAccountStatementEntry({
      userId: traderId,
      entryType: 'trading_fees',
      amount: -round2(totalTradingFees),
      tradeId: trade.id,
      tradeNumber,
      description: `Handelsgebühren Trade #${tradeNumber}`,
      referenceDocumentId: feeDoc.id,
    });
  }

  // ── Step 4: Create Credit Note document FIRST (Beleg vor Buchung) ──
  if (totalCommission <= 0) {
    console.log(`ℹ️ Trade #${tradeNumber}: totalCommission=0, no trader credit`);
  } else {
    const traderTaxBreakdown = calculateWithholdingBundle({
      taxableAmount: totalCommission,
      taxConfig,
      userProfile: traderProfile,
    });
    const creditNote = await createCreditNoteDocument({
      traderId,
      trade,
      totalCommission: round2(totalCommission),
      commissionRate,
      grossProfit: round2(netTradingProfit),
      netProfit: round2(netTradingProfit - totalCommission),
      investorBreakdown,
      taxBreakdown: traderTaxBreakdown,
    });

    // ── Step 5: Book trader commission credit WITH Beleg-Referenz ──
    await bookAccountStatementEntry({
      userId: traderId,
      entryType: 'commission_credit',
      amount: round2(totalCommission),
      tradeId: trade.id,
      tradeNumber,
      description: `Provisionsgutschrift Trade #${tradeNumber}`,
      referenceDocumentId: creditNote.id,
    });

    if (traderTaxBreakdown.totalTax > 0) {
      await bookTraderTaxEntries({
        traderId,
        trade,
        tradeNumber,
        creditNoteId: creditNote.id,
        taxBreakdown: traderTaxBreakdown,
      });
    }
  }

  const summary = {
    tradeId: trade.id,
    tradeNumber,
    rawGrossProfit: round2(rawGrossProfit),
    tradingFees: round2(totalTradingFees),
    netTradingProfit: round2(netTradingProfit),
    totalCommission: round2(totalCommission),
    netProfit: round2(netTradingProfit - totalCommission),
    traderTaxWithheld: round2(
      calculateWithholdingBundle({
        taxableAmount: totalCommission,
        taxConfig,
        userProfile: traderProfile,
      }).totalTax
    ),
    commissionRate,
    investorCount: investorBreakdown.length,
  };

  console.log(`✅ Trade #${tradeNumber} settled: buy/sell/fees booked, commission=€${round2(totalCommission)}, investors=${investorBreakdown.length}`);
  return summary;
}

// ============================================================================
// Per-participation settlement
// ============================================================================

async function settleParticipation({
  participation,
  trade,
  traderId,
  tradeNumber,
  netTradingProfit,
  commissionRate,
  feeConfig,
  tradeBuyPrice,
  tradeSellPrice,
  taxConfig,
}) {
  // ── Normalize ownership: iOS stores as ratio (0-1), legacy as percent (0-100) ──
  const rawOwnership = participation.get('ownershipPercentage') || 0;
  const ownershipRatio = rawOwnership > 1 ? rawOwnership / 100 : rawOwnership;

  const profitShare = round2(netTradingProfit * ownershipRatio);
  const commission = round2(profitShare * commissionRate);
  const netProfit = round2(profitShare - commission);

  console.log(`  📊 Participation ${participation.id}: ownership=${rawOwnership} (ratio=${ownershipRatio.toFixed(4)}), profit=€${profitShare}, comm=€${commission}, net=€${netProfit}`);

  // ── 2a: Update PoolTradeParticipation ──
  participation.set('profitShare', profitShare);
  participation.set('commissionAmount', commission);
  participation.set('commissionRate', commissionRate);
  participation.set('grossReturn', netProfit);
  participation.set('isSettled', true);
  participation.set('settledAt', new Date());
  await participation.save(null, { useMasterKey: true });

  // ── 2b: Find investment ──
  const rawInvestmentId = participation.get('investmentId');
  const investment = await findInvestment(rawInvestmentId, participation, trade);

  if (!investment) {
    console.warn(`  ⚠️ Investment not found for participation ${participation.id}, investmentId=${rawInvestmentId}`);
    return { investorId: null, investmentId: rawInvestmentId, grossProfit: profitShare, commission };
  }

  const investorId = investment.get('investorId');
  const investmentCapital = investment.get('amount') || 0;
  const investmentNumber = investment.get('investmentNumber') || investment.id;
  console.log(`  📊 Found investment ${investment.id} for investor ${investorId}, capital=€${investmentCapital}`);
  const investorProfile = await resolveUserTaxProfile(investorId);
  const taxBreakdown = calculateWithholdingBundle({
    taxableAmount: netProfit,
    taxConfig,
    userProfile: investorProfile,
  });

  // ── 2c-pre: Book investment_activate if it was never booked (reserved → completed) ──
  // GoB: Beleg FIRST, then Buchung
  const existingActivation = await new Parse.Query('AccountStatement')
    .equalTo('investmentId', investment.id)
    .equalTo('entryType', 'investment_activate')
    .equalTo('source', 'backend')
    .first({ useMasterKey: true });

  if (!existingActivation && investmentCapital > 0) {
    const activateReceipt = await createWalletReceiptDocument({
      userId: investorId,
      receiptType: 'investment',
      amount: -investmentCapital,
      description: `Investment ${investmentNumber} aktiviert – Abbuchung vom Anlagekonto`,
      referenceType: 'Investment',
      referenceId: investment.id,
      metadata: { investmentNumber, traderId },
    });
    await bookAccountStatementEntry({
      userId: investorId,
      entryType: 'investment_activate',
      amount: -Math.abs(investmentCapital),
      investmentId: investment.id,
      description: `Investment ${investmentNumber} aktiviert`,
      referenceDocumentId: activateReceipt.id,
    });
    console.log(`  💸 Booked investment_activate: -€${investmentCapital} for ${investorId} (Beleg: ${activateReceipt.get('accountingDocumentNumber')})`);
  }

  // ── 2c: Compute buy/sell legs (for documents + residual) ──
  let buyLeg = null;
  let sellLeg = null;
  if (tradeBuyPrice > 0 && investmentCapital > 0) {
    buyLeg = computeInvestorBuyLeg(investmentCapital, tradeBuyPrice, feeConfig);
    if (buyLeg && tradeSellPrice > 0) {
      sellLeg = computeInvestorSellLeg(buyLeg.quantity, tradeSellPrice, 1.0, feeConfig);
    }
  }

  // ── 2d: Create Collection Bill document FIRST (Beleg vor Buchung) ──
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
  });

  // ── 2e: Book AccountStatement entries BEFORE saving investment ──
  // (afterSave trigger checks for existing investment_return to avoid duplicates)
  // Model: Invest (withdrawal) → Return (deposit of capital + gross profit) → Commission (debit)
  const grossReturn = investmentCapital + profitShare;
  await bookAccountStatementEntry({
    userId: investorId,
    entryType: 'investment_return',
    amount: Math.abs(grossReturn),
    tradeId: trade.id,
    tradeNumber,
    investmentId: investment.id,
    description: `Abrechnung Trade #${tradeNumber} – Rückzahlung ${investmentNumber}`,
    referenceDocumentId: collectionBill.id,
  });

  if (commission > 0) {
    await bookAccountStatementEntry({
      userId: investorId,
      entryType: 'commission_debit',
      amount: -Math.abs(commission),
      tradeId: trade.id,
      tradeNumber,
      investmentId: investment.id,
      description: `Provision Trade #${tradeNumber} (${(commissionRate * 100).toFixed(0)}%)`,
      referenceDocumentId: collectionBill.id,
    });
  }

  if (taxBreakdown.totalTax > 0) {
    await bookInvestorTaxEntries({
      investorId,
      investmentId: investment.id,
      trade,
      tradeNumber,
      collectionBillId: collectionBill.id,
      taxBreakdown,
    });
  }

  // ── 2f: Update Investment totals & mark completed ──
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

  // ── 2g: Book residual return if buy-leg has leftover capital ──
  if (buyLeg && buyLeg.residualAmount > 0) {
    await bookAccountStatementEntry({
      userId: investorId,
      entryType: 'residual_return',
      amount: round2(buyLeg.residualAmount),
      tradeId: trade.id,
      tradeNumber,
      investmentId: investment.id,
      description: `Restbetrag Trade #${tradeNumber} (Rundungsdifferenz Stückkauf)`,
      referenceDocumentId: collectionBill.id,
    });
    console.log(`  💰 Residual return: €${round2(buyLeg.residualAmount)} for investor ${investorId}`);
  }

  // ── 2h: Create Commission record ──
  await createCommissionRecord(traderId, investment, trade, participation, commission);

  // ── 2i: Notify investor ──
  await createNotification(investorId, 'investment_profit', 'investment',
    'Gewinn erzielt',
    `Ihr Investment hat einen Gewinn von ${formatCurrency(netProfit - taxBreakdown.totalTax)} nach Steuerabzug erzielt.`);

  return {
    investorId,
    investmentId: investment.id,
    grossProfit: profitShare,
    commission,
    taxWithheld: taxBreakdown.totalTax,
  };
}

async function bookInvestorTaxEntries({
  investorId,
  investmentId,
  trade,
  tradeNumber,
  collectionBillId,
  taxBreakdown,
}) {
  if (taxBreakdown.withholdingTax > 0) {
    await bookAccountStatementEntry({
      userId: investorId,
      entryType: 'withholding_tax_debit',
      amount: -Math.abs(taxBreakdown.withholdingTax),
      tradeId: trade.id,
      tradeNumber,
      investmentId,
      description: `Abgeltungsteuer Trade #${tradeNumber}`,
      referenceDocumentId: collectionBillId,
    });
  }
  if (taxBreakdown.solidaritySurcharge > 0) {
    await bookAccountStatementEntry({
      userId: investorId,
      entryType: 'solidarity_surcharge_debit',
      amount: -Math.abs(taxBreakdown.solidaritySurcharge),
      tradeId: trade.id,
      tradeNumber,
      investmentId,
      description: `Solidaritätszuschlag Trade #${tradeNumber}`,
      referenceDocumentId: collectionBillId,
    });
  }
  if (taxBreakdown.churchTax > 0) {
    await bookAccountStatementEntry({
      userId: investorId,
      entryType: 'church_tax_debit',
      amount: -Math.abs(taxBreakdown.churchTax),
      tradeId: trade.id,
      tradeNumber,
      investmentId,
      description: `Kirchensteuer Trade #${tradeNumber}`,
      referenceDocumentId: collectionBillId,
    });
  }
}

async function bookTraderTaxEntries({
  traderId,
  trade,
  tradeNumber,
  creditNoteId,
  taxBreakdown,
}) {
  if (taxBreakdown.withholdingTax > 0) {
    await bookAccountStatementEntry({
      userId: traderId,
      entryType: 'withholding_tax_debit',
      amount: -Math.abs(taxBreakdown.withholdingTax),
      tradeId: trade.id,
      tradeNumber,
      description: `Abgeltungsteuer Trader-Provision Trade #${tradeNumber}`,
      referenceDocumentId: creditNoteId,
    });
  }
  if (taxBreakdown.solidaritySurcharge > 0) {
    await bookAccountStatementEntry({
      userId: traderId,
      entryType: 'solidarity_surcharge_debit',
      amount: -Math.abs(taxBreakdown.solidaritySurcharge),
      tradeId: trade.id,
      tradeNumber,
      description: `Solidaritätszuschlag Trader-Provision Trade #${tradeNumber}`,
      referenceDocumentId: creditNoteId,
    });
  }
  if (taxBreakdown.churchTax > 0) {
    await bookAccountStatementEntry({
      userId: traderId,
      entryType: 'church_tax_debit',
      amount: -Math.abs(taxBreakdown.churchTax),
      tradeId: trade.id,
      tradeNumber,
      description: `Kirchensteuer Trader-Provision Trade #${tradeNumber}`,
      referenceDocumentId: creditNoteId,
    });
  }
}

// ============================================================================
// Helper: Compute total trading fees from buy + sell orders
// ============================================================================

function computeTradingFees(trade) {
  const buyOrder = trade.get('buyOrder');
  const sellOrders = trade.get('sellOrders') || [];
  const sellOrder = trade.get('sellOrder');
  let total = 0;

  if (buyOrder) {
    total += calculateOrderFees(buyOrder.totalAmount || 0, true).totalFees;
  }

  const allSells = sellOrders.length > 0 ? sellOrders : (sellOrder ? [sellOrder] : []);
  for (const so of allSells) {
    total += calculateOrderFees(so.totalAmount || 0, true).totalFees;
  }

  return total;
}

// ============================================================================
// Helper: Find investment (5 fallback strategies)
// ============================================================================

async function findInvestment(investmentId, participation, trade) {
  const Investment = Parse.Object.extend('Investment');

  try {
    return await new Parse.Query(Investment).get(investmentId, { useMasterKey: true });
  } catch (_) { /* not a Parse objectId */ }

  const byBatchId = await new Parse.Query(Investment)
    .equalTo('batchId', investmentId).first({ useMasterKey: true });
  if (byBatchId) {
    console.log(`  📊 Found investment via batchId: ${byBatchId.id}`);
    return byBatchId;
  }

  const investorId = participation.get('investorId');
  if (investorId) {
    const byInvestor = await new Parse.Query(Investment)
      .equalTo('investorId', investorId).descending('createdAt').first({ useMasterKey: true });
    if (byInvestor) {
      console.log(`  📊 Found investment via investorId: ${byInvestor.id}`);
      return byInvestor;
    }
  }

  const partCreated = participation.get('createdAt') || participation.createdAt;
  if (partCreated) {
    const windowStart = new Date(partCreated.getTime() - 60000);
    const windowEnd = new Date(partCreated.getTime() + 60000);
    const timeQuery = new Parse.Query(Investment);
    timeQuery.greaterThanOrEqualTo('createdAt', windowStart);
    timeQuery.lessThanOrEqualTo('createdAt', windowEnd);
    timeQuery.ascending('createdAt');
    const candidates = await timeQuery.find({ useMasterKey: true });
    if (candidates.length >= 1) {
      console.log(`  📊 Found investment via time-proximity: ${candidates[0].id}`);
      return candidates[0];
    }
  }

  if (trade) {
    const traderId = trade.get('traderId');
    let traderEmail = (traderId && traderId.startsWith('user:')) ? traderId.replace('user:', '') : null;
    if (traderEmail) {
      const traderUser = await new Parse.Query(Parse.User)
        .equalTo('email', traderEmail).first({ useMasterKey: true });
      if (traderUser) {
        const q1 = new Parse.Query(Investment).equalTo('traderId', traderUser.id);
        const q2 = new Parse.Query(Investment).equalTo('traderId', `user:${traderEmail}`);
        const inv = await Parse.Query.or(q1, q2).descending('createdAt').first({ useMasterKey: true });
        if (inv) {
          console.log(`  📊 Found investment via trader lookup: ${inv.id}`);
          return inv;
        }
      }
    }

    const tradeCreated = trade.get('createdAt') || trade.createdAt;
    if (tradeCreated) {
      const recent = await new Parse.Query(Investment)
        .greaterThanOrEqualTo('createdAt', new Date(tradeCreated.getTime() - 120000))
        .lessThanOrEqualTo('createdAt', new Date(tradeCreated.getTime() + 120000))
        .ascending('createdAt').first({ useMasterKey: true });
      if (recent) {
        console.log(`  📊 Found investment via trade-time proximity: ${recent.id}`);
        return recent;
      }
    }
  }

  return null;
}

// ============================================================================
// Helper: Create Commission record
// ============================================================================

async function createCommissionRecord(traderId, investment, trade, participation, amount) {
  const Commission = Parse.Object.extend('Commission');
  const commission = new Commission();

  const lastComm = await new Parse.Query('Commission')
    .startsWith('commissionNumber', `COM-${new Date().getFullYear()}-`)
    .descending('commissionNumber')
    .first({ useMasterKey: true });

  let seq = 1;
  if (lastComm) {
    const parts = lastComm.get('commissionNumber').split('-');
    seq = parseInt(parts[2], 10) + 1;
  }

  commission.set('commissionNumber', `COM-${new Date().getFullYear()}-${seq.toString().padStart(7, '0')}`);
  commission.set('traderId', traderId);
  commission.set('investorId', investment.get('investorId'));
  commission.set('investmentId', investment.id);
  commission.set('tradeId', trade.id);
  commission.set('participationId', participation.id);
  commission.set('investorGrossProfit', participation.get('profitShare'));
  commission.set('commissionRate', participation.get('commissionRate'));
  commission.set('commissionAmount', amount);
  commission.set('status', 'pending');

  await commission.save(null, { useMasterKey: true });
  console.log(`  📄 Commission ${commission.get('commissionNumber')}: €${round2(amount)} for trade #${trade.get('tradeNumber')}`);
}

// ============================================================================
// Shared helpers
// ============================================================================

async function createNotification(userId, type, category, title, message) {
  const Notification = Parse.Object.extend('Notification');
  const notif = new Notification();
  notif.set('userId', userId);
  notif.set('type', type);
  notif.set('category', category);
  notif.set('title', title);
  notif.set('message', message);
  notif.set('isRead', false);
  notif.set('channels', ['in_app', 'push']);
  await notif.save(null, { useMasterKey: true });
}

function formatCurrency(amount) {
  return new Intl.NumberFormat('de-DE', { style: 'currency', currency: 'EUR' }).format(amount);
}

module.exports = {
  settleAndDistribute,
  settleCompletedTrade: settleAndDistribute,
};
