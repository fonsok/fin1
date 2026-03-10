// ============================================================================
// Parse Cloud Code
// utils/accountingHelper.js - Accounting & Document Helpers
// ============================================================================
//
// Centralised helpers for creating AccountStatement entries and
// accounting documents (Credit Notes, Collection Bills).
// Called from trade.js afterSave when a trade is completed.
//
// ============================================================================

'use strict';

const { generateSequentialNumber, formatCurrency, calculateOrderFees } = require('./helpers');
const { getTraderCommissionRate, getFinancialConfig } = require('./configHelper');

// ============================================================================
// ACCOUNT STATEMENT
// ============================================================================

/**
 * Book a single AccountStatement entry.
 *
 * @param {object} params
 * @param {string} params.userId        – User who owns this entry
 * @param {string} params.entryType     – e.g. 'commission_credit', 'commission_debit', 'investment_profit'
 * @param {number} params.amount        – Positive = credit, negative = debit
 * @param {string} params.tradeId
 * @param {number} params.tradeNumber
 * @param {string} [params.investmentId]
 * @param {string} params.description
 * @param {string} [params.referenceDocumentId] – Linked Document objectId
 * @returns {Promise<Parse.Object>} Saved AccountStatement
 */
async function bookAccountStatementEntry({
  userId, entryType, amount, tradeId, tradeNumber,
  investmentId, description, referenceDocumentId,
}) {
  const AccountStatement = Parse.Object.extend('AccountStatement');

  // Fetch current balance for this user (sequential consistency)
  const lastEntry = await new Parse.Query('AccountStatement')
    .equalTo('userId', userId)
    .descending('createdAt')
    .first({ useMasterKey: true });

  const balanceBefore = lastEntry ? (lastEntry.get('balanceAfter') || 0) : 0;
  const balanceAfter = balanceBefore + amount;

  const entry = new AccountStatement();
  entry.set('userId', userId);
  entry.set('entryType', entryType);
  entry.set('amount', amount);
  entry.set('balanceBefore', Math.round(balanceBefore * 100) / 100);
  entry.set('balanceAfter', Math.round(balanceAfter * 100) / 100);
  entry.set('tradeId', tradeId);
  entry.set('tradeNumber', tradeNumber);
  if (investmentId) entry.set('investmentId', investmentId);
  entry.set('description', description);
  if (referenceDocumentId) entry.set('referenceDocumentId', referenceDocumentId);
  entry.set('source', 'backend');

  await entry.save(null, { useMasterKey: true });
  return entry;
}

// ============================================================================
// CREDIT NOTE (Trader Commission Document)
// ============================================================================

/**
 * Create a Credit Note document for the trader's commission on a completed trade.
 *
 * @param {object} params
 * @param {string} params.traderId
 * @param {Parse.Object} params.trade
 * @param {number} params.totalCommission
 * @param {number} params.commissionRate
 * @param {number} params.grossProfit
 * @param {number} params.netProfit
 * @param {Array}  params.investorBreakdown – [{ investorId, investmentId, grossProfit, commission }]
 * @returns {Promise<Parse.Object>} Saved Document
 */
async function createCreditNoteDocument({
  traderId, trade, totalCommission, commissionRate,
  grossProfit, netProfit, investorBreakdown,
}) {
  const tradeNumber = trade.get('tradeNumber');
  const docNumber = await generateSequentialNumber('CN', 'Document', 'accountingDocumentNumber');
  const dateStr = formatDateCompact(new Date());
  const hash = generateShortHash();

  const Document = Parse.Object.extend('Document');
  const doc = new Document();
  doc.set('userId', traderId);
  doc.set('type', 'trader_credit_note');
  doc.set('name', `CreditNote_Trade${tradeNumber}_${dateStr}_${hash}.pdf`);
  doc.set('tradeId', trade.id);
  doc.set('tradeNumber', tradeNumber);
  doc.set('accountingDocumentNumber', docNumber);
  doc.set('source', 'backend');
  doc.set('metadata', {
    commissionAmount: round2(totalCommission),
    commissionRate,
    grossProfit: round2(grossProfit),
    netProfit: round2(netProfit),
    investorBreakdown: investorBreakdown.map(b => ({
      investorId: b.investorId,
      investmentId: b.investmentId,
      grossProfit: round2(b.grossProfit),
      commission: round2(b.commission),
    })),
    generatedAt: new Date().toISOString(),
  });

  await doc.save(null, { useMasterKey: true });
  console.log(`📄 CreditNote created: ${docNumber} for trade #${tradeNumber}, commission €${round2(totalCommission)}`);
  return doc;
}

// ============================================================================
// COLLECTION BILL (Investor Statement Document)
// ============================================================================

/**
 * Create an Investor Collection Bill document for a single investor's
 * participation in a completed trade.
 *
 * @param {object} params
 * @param {string} params.investorId
 * @param {string} params.investmentId
 * @param {Parse.Object} params.trade
 * @param {number} params.ownershipPercentage
 * @param {number} params.grossProfit    – Investor's share of gross profit
 * @param {number} params.commission     – Commission charged to this investor
 * @param {number} params.netProfit      – Investor's net profit after commission
 * @param {number} params.commissionRate
 * @returns {Promise<Parse.Object>} Saved Document
 */
async function createCollectionBillDocument({
  investorId, investmentId, trade,
  ownershipPercentage, grossProfit, commission, netProfit, commissionRate,
  buyLeg, sellLeg,
}) {
  const tradeNumber = trade.get('tradeNumber');
  const docNumber = await generateSequentialNumber('CB', 'Document', 'accountingDocumentNumber');
  const dateStr = formatDateCompact(new Date());
  const hash = generateShortHash();

  const Document = Parse.Object.extend('Document');
  const doc = new Document();
  doc.set('userId', investorId);
  doc.set('type', 'investor_collection_bill');
  doc.set('name', `CollectionBill_Investment${investmentId}_${dateStr}_${hash}.pdf`);
  doc.set('investmentId', investmentId);
  doc.set('tradeId', trade.id);
  doc.set('tradeNumber', tradeNumber);
  doc.set('accountingDocumentNumber', docNumber);
  doc.set('source', 'backend');
  doc.set('metadata', {
    ownershipPercentage: round2(ownershipPercentage),
    grossProfit: round2(grossProfit),
    commission: round2(commission),
    netProfit: round2(netProfit),
    commissionRate,
    buyLeg: buyLeg || null,
    sellLeg: sellLeg || null,
    generatedAt: new Date().toISOString(),
  });

  await doc.save(null, { useMasterKey: true });
  console.log(`📄 CollectionBill created: ${docNumber} for investor ${investorId}, investment ${investmentId}`);
  return doc;
}

// ============================================================================
// INVESTOR BUY/SELL LEG CALCULATION (aligned with frontend)
// ============================================================================
//
// Matches InvestorCollectionBillCalculationService logic:
// - solveForBuyAmount: buyAmount + fees(buyAmount) = investmentCapital
// - Maximization loop: buy as many whole units as capital allows
// - Residual = capital - (securities value + fees)
//

function computeTotalFees(orderAmount, feeConfig = {}) {
  const fees = calculateOrderFees(orderAmount, false, feeConfig);
  return fees.totalFees;
}

function solveForBuyAmount(investmentCapital, feeConfig, tolerance = 0.01) {
  let low = 0;
  let high = investmentCapital;
  let result = 0;

  for (let i = 0; i < 100; i++) {
    const mid = (low + high) / 2;
    const fees = computeTotalFees(mid, feeConfig);
    const totalCost = mid + fees;

    if (Math.abs(totalCost - investmentCapital) < tolerance) {
      result = mid;
      break;
    }
    if (totalCost < investmentCapital) {
      result = mid;
      low = mid;
    } else {
      high = mid;
    }
  }

  const finalFees = computeTotalFees(result, feeConfig);
  if (result + finalFees > investmentCapital) {
    result *= 0.99;
  }
  return result;
}

/**
 * Compute investor buy leg with fee-aware solve and residual maximization.
 * Aligned with frontend InvestorCollectionBillCalculationService.calculateBuyLeg.
 */
function computeInvestorBuyLeg(investmentCapital, buyPrice, feeConfig) {
  const solvedBuyAmount = solveForBuyAmount(investmentCapital, feeConfig);
  let buyQty = Math.floor(solvedBuyAmount / buyPrice);
  let buyAmt = round2(buyQty * buyPrice);
  let buyFees = buyAmt > 0 ? calculateOrderFees(buyAmt, false, feeConfig) : { orderFee: 0, exchangeFee: 0, foreignCosts: 0, totalFees: 0 };
  let totalBuyCost = buyAmt + buyFees.totalFees;
  let residual = round2(investmentCapital - totalBuyCost);

  // Maximization: add units while we can afford them
  for (let iter = 0; iter < 100; iter++) {
    const nextQty = buyQty + 1;
    const nextAmt = nextQty * buyPrice;
    const nextFees = calculateOrderFees(nextAmt, false, feeConfig);
    const nextTotalCost = nextAmt + nextFees.totalFees;

    if (nextTotalCost <= investmentCapital) {
      buyQty = nextQty;
      buyAmt = round2(nextAmt);
      buyFees = nextFees;
      totalBuyCost = nextTotalCost;
      residual = round2(investmentCapital - totalBuyCost);
    } else {
      break;
    }
  }

  return {
    quantity: buyQty,
    price: buyPrice,
    amount: buyAmt,
    fees: buyFees,
    residualAmount: Math.max(0, residual),
  };
}

/**
 * Compute investor sell leg.
 * @param {number} buyQuantity – Investor's buy quantity
 * @param {number} sellPrice – Average sell price
 * @param {number} sellPercentage – 0..1, proportion of position sold (1.0 for completed trade)
 */
function computeInvestorSellLeg(buyQuantity, sellPrice, sellPercentage, feeConfig) {
  const sellQty = Math.floor(buyQuantity * sellPercentage);
  const sellAmt = round2(sellQty * sellPrice);
  const sellFees = sellAmt > 0 ? calculateOrderFees(sellAmt, false, feeConfig) : { orderFee: 0, exchangeFee: 0, foreignCosts: 0, totalFees: 0 };
  return {
    quantity: sellQty,
    price: sellPrice,
    amount: sellAmt,
    fees: sellFees,
  };
}

// ============================================================================
// COMPOSITE: Full Trade Settlement
// ============================================================================

/**
 * Perform the complete financial settlement for a completed trade:
 *   1. Book trader commission to AccountStatement
 *   2. Create Credit Note document
 *   3. For each investor participation:
 *      a. Book commission debit to AccountStatement
 *      b. Book net profit credit to AccountStatement
 *      c. Create Collection Bill document
 *
 * Idempotent: checks for existing AccountStatement entries before booking.
 *
 * @param {Parse.Object} trade – The completed Trade object
 * @returns {Promise<object|null>} Settlement summary or null if nothing to settle
 */
async function settleCompletedTrade(trade) {
  const traderId = trade.get('traderId');
  const grossProfit = trade.get('grossProfit') || 0;
  const tradeNumber = trade.get('tradeNumber');

  if (grossProfit <= 0) {
    console.log(`ℹ️ Trade #${tradeNumber}: grossProfit=${grossProfit}, no settlement needed`);
    return null;
  }

  // Idempotency: skip if already settled by backend
  const existingEntry = await new Parse.Query('AccountStatement')
    .equalTo('tradeId', trade.id)
    .equalTo('entryType', 'commission_credit')
    .equalTo('source', 'backend')
    .first({ useMasterKey: true });

  if (existingEntry) {
    console.log(`ℹ️ Trade #${tradeNumber}: already settled by backend, skipping`);
    return null;
  }

  const commissionRate = await getTraderCommissionRate();

  // Find unsettled participations
  const participations = await new Parse.Query('PoolTradeParticipation')
    .equalTo('tradeId', trade.id)
    .find({ useMasterKey: true });

  if (participations.length === 0) {
    console.log(`ℹ️ Trade #${tradeNumber}: no investor participations, no commission`);
    return null;
  }

  console.log(`💰 Settling trade #${tradeNumber}: grossProfit=€${round2(grossProfit)}, rate=${(commissionRate * 100).toFixed(1)}%, ${participations.length} participations`);

  let totalCommission = 0;
  const investorBreakdown = [];

  // Pre-compute trade-level buy/sell data for per-investor leg breakdown
  const tradeBuyPrice = trade.get('entryPrice') || trade.get('buyPrice') || 0;
  const tradeSellPrice = trade.get('exitPrice') || trade.get('sellPrice') || 0;
  const tradeTotalQty = trade.get('totalQuantity') || trade.get('quantity') || 0;
  const feeConfig = await getFinancialConfig();

  // --- Per-investor settlement ---
  for (const participation of participations) {
    const ownershipPct = participation.get('ownershipPercentage') || 0;
    const investorGrossProfit = grossProfit * (ownershipPct / 100);
    const investorCommission = investorGrossProfit * commissionRate;
    const investorNetProfit = investorGrossProfit - investorCommission;
    const investmentId = participation.get('investmentId');

    totalCommission += investorCommission;

    // Load investment to find investorId and capital
    const investment = await new Parse.Query('Investment')
      .get(investmentId, { useMasterKey: true })
      .catch(() => null);

    const investorId = investment ? investment.get('investorId') : null;
    const investmentCapital = investment ? (investment.get('amount') || 0) : 0;

    // Compute investor buy/sell legs (aligned with frontend InvestorCollectionBillCalculationService)
    let buyLeg = null;
    let sellLeg = null;
    if (tradeBuyPrice > 0 && investmentCapital > 0) {
      buyLeg = computeInvestorBuyLeg(investmentCapital, tradeBuyPrice, feeConfig);
      if (buyLeg && tradeSellPrice > 0 && tradeTotalQty > 0) {
        // For completed trade: investor sells 100% of buy quantity
        sellLeg = computeInvestorSellLeg(buyLeg.quantity, tradeSellPrice, 1.0, feeConfig);
      }
    }

    if (investorId) {
      // 1) Book commission debit to investor account statement
      await bookAccountStatementEntry({
        userId: investorId,
        entryType: 'commission_debit',
        amount: -Math.abs(round2(investorCommission)),
        tradeId: trade.id,
        tradeNumber,
        investmentId,
        description: `Commission for Trade #${tradeNumber} (${(commissionRate * 100).toFixed(0)}%)`,
      });

      // 2) Book net profit credit to investor account statement
      if (investorNetProfit > 0) {
        await bookAccountStatementEntry({
          userId: investorId,
          entryType: 'investment_profit',
          amount: round2(investorNetProfit),
          tradeId: trade.id,
          tradeNumber,
          investmentId,
          description: `Net profit from Trade #${tradeNumber}`,
        });
      }

      // 3) Create Collection Bill document with buy/sell leg detail
      await createCollectionBillDocument({
        investorId,
        investmentId,
        trade,
        ownershipPercentage: ownershipPct,
        grossProfit: investorGrossProfit,
        commission: investorCommission,
        netProfit: investorNetProfit,
        commissionRate,
        buyLeg,
        sellLeg,
      });

      investorBreakdown.push({
        investorId,
        investmentId,
        grossProfit: investorGrossProfit,
        commission: investorCommission,
      });
    }
  }

  // --- Trader commission credit ---
  const totalNetProfit = grossProfit - totalCommission;

  await bookAccountStatementEntry({
    userId: traderId,
    entryType: 'commission_credit',
    amount: round2(totalCommission),
    tradeId: trade.id,
    tradeNumber,
    description: `Commission credit for Trade #${tradeNumber}`,
  });

  // --- Trader Credit Note ---
  const creditNote = await createCreditNoteDocument({
    traderId,
    trade,
    totalCommission,
    commissionRate,
    grossProfit,
    netProfit: totalNetProfit,
    investorBreakdown,
  });

  // Calculate order fees for the trade's buy/sell amounts
  const buyOrder = trade.get('buyOrder') || {};
  const sellOrder = trade.get('sellOrder') || {};
  const buyAmount = buyOrder.totalAmount || trade.get('buyAmount') || 0;
  const sellAmount = sellOrder.totalAmount || trade.get('sellAmount') || 0;
  const buyFees = buyAmount > 0 ? calculateOrderFees(buyAmount) : null;
  const sellFees = sellAmount > 0 ? calculateOrderFees(sellAmount) : null;

  const summary = {
    tradeId: trade.id,
    tradeNumber,
    grossProfit: round2(grossProfit),
    totalCommission: round2(totalCommission),
    netProfit: round2(totalNetProfit),
    commissionRate,
    creditNoteId: creditNote.id,
    investorCount: investorBreakdown.length,
    orderFees: { buy: buyFees, sell: sellFees },
  };

  console.log(`✅ Trade #${tradeNumber} settled: commission=€${round2(totalCommission)}, net=€${round2(totalNetProfit)}`);
  return summary;
}

// ============================================================================
// UTILITIES
// ============================================================================

function round2(n) {
  return Math.round(n * 100) / 100;
}

function formatDateCompact(date) {
  const y = date.getFullYear();
  const m = String(date.getMonth() + 1).padStart(2, '0');
  const d = String(date.getDate()).padStart(2, '0');
  return `${y}${m}${d}`;
}

function generateShortHash() {
  const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
  let hash = '';
  for (let i = 0; i < 8; i++) {
    hash += chars.charAt(Math.floor(Math.random() * chars.length));
  }
  return hash;
}

// ============================================================================
// EXPORTS
// ============================================================================

module.exports = {
  bookAccountStatementEntry,
  createCreditNoteDocument,
  createCollectionBillDocument,
  settleCompletedTrade,
};
