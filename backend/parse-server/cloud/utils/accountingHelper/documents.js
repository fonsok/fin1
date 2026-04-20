'use strict';

const { generateSequentialNumber } = require('../helpers');
const { round2, formatDateCompact, generateShortHash } = require('./shared');

function computeCollectionBillReturnPercentage({ netProfit, buyLeg, investmentCapital }) {
  const buyLegAmount = buyLeg?.amount || 0;
  const buyLegFees = buyLeg?.fees?.totalFees || 0;
  const investedAmountFromLeg = buyLegAmount + buyLegFees;
  const investedAmount = investedAmountFromLeg > 0
    ? investedAmountFromLeg
    : (typeof investmentCapital === 'number' && investmentCapital > 0 ? investmentCapital : 0);

  if (investedAmount <= 0) {
    return null;
  }
  return round2((netProfit / investedAmount) * 100);
}

function assertCollectionBillReturnPercentageInvariant(returnPercentage, context = {}) {
  if (typeof returnPercentage === 'number' && Number.isFinite(returnPercentage)) {
    return;
  }

  const details = {
    tradeId: context.tradeId || null,
    investmentId: context.investmentId || null,
    netProfit: context.netProfit ?? null,
    investmentCapital: context.investmentCapital ?? null,
  };
  throw new Error(
    `Invariant violation: investor collection bill missing canonical returnPercentage (${JSON.stringify(details)})`,
  );
}

async function createCreditNoteDocument({
  traderId,
  trade,
  totalCommission,
  commissionRate,
  grossProfit,
  netProfit,
  investorBreakdown,
  taxBreakdown,
}) {
  const tradeNumber = trade.get('tradeNumber');
  const docNumber = await generateSequentialNumber('CN', 'Document', 'accountingDocumentNumber');
  const dateStr = formatDateCompact(new Date());
  const hash = generateShortHash();

  const Document = Parse.Object.extend('Document');
  const doc = new Document();
  doc.set('userId', traderId);
  doc.set('type', 'traderCreditNote');
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
    investorBreakdown: investorBreakdown.map((b) => ({
      investorId: b.investorId,
      investmentId: b.investmentId,
      grossProfit: round2(b.grossProfit),
      commission: round2(b.commission),
      taxWithheld: round2(b.taxWithheld || 0),
    })),
    taxBreakdown: taxBreakdown || null,
    generatedAt: new Date().toISOString(),
  });
  doc.set('traderCommissionRateSnapshot', commissionRate);

  await doc.save(null, { useMasterKey: true });
  console.log(`📄 CreditNote created: ${docNumber} for trade #${tradeNumber}, commission €${round2(totalCommission)}`);
  return doc;
}

async function createCollectionBillDocument({
  investorId,
  investmentId,
  trade,
  ownershipPercentage,
  grossProfit,
  commission,
  netProfit,
  commissionRate,
  investmentCapital,
  buyLeg,
  sellLeg,
  taxBreakdown,
}) {
  const tradeNumber = trade.get('tradeNumber');
  const docNumber = await generateSequentialNumber('CB', 'Document', 'accountingDocumentNumber');
  const dateStr = formatDateCompact(new Date());
  const hash = generateShortHash();

  const returnPercentage = computeCollectionBillReturnPercentage({
    netProfit,
    buyLeg,
    investmentCapital,
  });
  assertCollectionBillReturnPercentageInvariant(returnPercentage, {
    tradeId: trade?.id,
    investmentId,
    netProfit,
    investmentCapital,
  });

  const Document = Parse.Object.extend('Document');
  const doc = new Document();
  doc.set('userId', investorId);
  doc.set('type', 'investorCollectionBill');
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
    returnPercentage,
    commissionRate,
    buyLeg: buyLeg || null,
    sellLeg: sellLeg || null,
    taxBreakdown: taxBreakdown || null,
    generatedAt: new Date().toISOString(),
  });

  await doc.save(null, { useMasterKey: true });
  console.log(`📄 CollectionBill created: ${docNumber} for investor ${investorId}, investment ${investmentId}`);
  return doc;
}

// ============================================================================
// GoB-compliant receipt for wallet transactions (Keine Buchung ohne Beleg)
// Covers: deposit, withdrawal, investment_activate, investment_return, refund
// ============================================================================

async function createWalletReceiptDocument({
  userId,
  receiptType,
  amount,
  description,
  referenceType,
  referenceId,
  metadata: extraMeta,
}) {
  const typeToDocType = {
    deposit: 'financial',
    withdrawal: 'financial',
    investment: 'investorCollectionBill',
    investment_return: 'investorCollectionBill',
    refund: 'investorCollectionBill',
  };

  const typeToPrefix = {
    deposit: 'WDR',
    withdrawal: 'WWR',
    investment: 'IAR',
    investment_return: 'IRR',
    refund: 'IFR',
  };

  const docType = typeToDocType[receiptType] || `wallet_${receiptType}_receipt`;
  const prefix = typeToPrefix[receiptType] || 'WRC';

  const docNumber = await generateSequentialNumber(prefix, 'Document', 'accountingDocumentNumber');
  const dateStr = formatDateCompact(new Date());
  const hash = generateShortHash();

  const Document = Parse.Object.extend('Document');
  const doc = new Document();
  doc.set('userId', userId);
  doc.set('type', docType);
  doc.set('name', `${docType}_${dateStr}_${hash}.pdf`);
  doc.set('accountingDocumentNumber', docNumber);
  doc.set('source', 'backend');
  if (referenceType) doc.set('referenceType', referenceType);
  if (referenceId) doc.set('referenceId', referenceId);
  if (referenceType === 'Investment' && referenceId) {
    doc.set('investmentId', referenceId);
  }
  doc.set('metadata', {
    amount: round2(Math.abs(amount)),
    description,
    receiptType,
    ...extraMeta,
    generatedAt: new Date().toISOString(),
  });

  await doc.save(null, { useMasterKey: true });
  console.log(`📄 WalletReceipt created: ${docNumber} (${docType}) for user ${userId}, €${round2(Math.abs(amount))}`);
  return doc;
}

// ============================================================================
// GoB-compliant trade execution documents (Kaufabrechnung / Verkaufsabrechnung)
// Every trade_buy, trade_sell, and trading_fees booking needs its own Beleg.
// ============================================================================

async function createTradeExecutionDocument({
  traderId,
  trade,
  executionType,
  amount,
  order,
}) {
  const tradeNumber = trade.get('tradeNumber');
  const symbol = trade.get('symbol') || '';

  const typeToDocType = {
    buy: 'traderCollectionBill',
    sell: 'traderCollectionBill',
    fees: 'invoice',
  };

  const typeToPrefix = {
    buy: 'TBC',
    sell: 'TSC',
    fees: 'TFS',
  };

  const typeToLabel = {
    buy: 'Kaufabrechnung',
    sell: 'Verkaufsabrechnung',
    fees: 'Gebührenabrechnung',
  };

  const docType = typeToDocType[executionType] || 'trade_execution_document';
  const prefix = typeToPrefix[executionType] || 'TED';
  const label = typeToLabel[executionType] || 'Trade Execution';

  const docNumber = await generateSequentialNumber(prefix, 'Document', 'accountingDocumentNumber');
  const dateStr = formatDateCompact(new Date());
  const hash = generateShortHash();

  const Document = Parse.Object.extend('Document');
  const doc = new Document();
  doc.set('userId', traderId);
  doc.set('type', docType);
  doc.set('name', `${label}_Trade${tradeNumber}_${symbol}_${dateStr}_${hash}.pdf`);
  doc.set('tradeId', trade.id);
  doc.set('tradeNumber', tradeNumber);
  doc.set('accountingDocumentNumber', docNumber);
  doc.set('source', 'backend');
  doc.set('metadata', {
    executionType,
    symbol,
    amount: round2(Math.abs(amount)),
    quantity: order?.quantity || null,
    price: order?.price || null,
    orderId: order?.id || null,
    wkn: order?.wkn || symbol,
    generatedAt: new Date().toISOString(),
  });

  await doc.save(null, { useMasterKey: true });
  console.log(`📄 ${label} created: ${docNumber} for trade #${tradeNumber} (${symbol}), €${round2(Math.abs(amount))}`);
  return doc;
}

module.exports = {
  createCreditNoteDocument,
  createCollectionBillDocument,
  createWalletReceiptDocument,
  createTradeExecutionDocument,
  computeCollectionBillReturnPercentage,
  assertCollectionBillReturnPercentageInvariant,
};
