'use strict';

const { generateSequentialNumber } = require('../../helpers');
const { round2, formatDateCompact, generateShortHash } = require('../shared');
const { buildCollectionBillBelegSnapshot } = require('../collectionBillBelegSnapshot');
const { applyBusinessCaseIdToDocument } = require('./shared');

function collectionBillFileURL(docNumber) {
  const no = String(docNumber || '').trim();
  return no ? `collectionbill://${no}.pdf` : 'collectionbill://investor.pdf';
}

function applyCollectionBillPresentationFields(doc, docNumber) {
  doc.set('status', 'verified');
  if (!String(doc.get('fileURL') || '').trim()) {
    doc.set('fileURL', collectionBillFileURL(docNumber));
  }
}

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

async function createCollectionBillDocument({
  investorId,
  investmentId,
  trade,
  ownershipPercentage,
  grossProfit,
  commission,
  traderCommission,
  appCommission,
  netProfit,
  commissionRate,
  traderCommissionRate,
  appCommissionRate,
  investmentCapital,
  buyLeg,
  sellLeg,
  taxBreakdown,
  businessCaseId,
  /** Wenn true: vorhandenes backend-`investorCollectionBill` zu (investmentId, tradeId) aktualisieren statt neuer CB-Nummer. Nicht für Teil-Sell-Deltas. */
  allowIdempotentUpsert = false,
}) {
  const tradeNumber = trade.get('tradeNumber');

  if (allowIdempotentUpsert) {
    const existing = await new Parse.Query('Document')
      .equalTo('type', 'investorCollectionBill')
      .equalTo('source', 'backend')
      .equalTo('investmentId', investmentId)
      .equalTo('tradeId', trade.id)
      .first({ useMasterKey: true });

    if (existing) {
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
      const { metadata } = buildCollectionBillBelegSnapshot({
        investmentCapital,
        ownershipPercentage,
        commissionRate,
        traderCommissionRate,
        appCommissionRate,
        buyLeg,
        sellLeg,
        taxBreakdown,
        grossProfit,
        commission,
        traderCommission,
        appCommission,
        netProfit,
        returnPercentage,
      });
      existing.set('userId', investorId);
      existing.set('tradeNumber', tradeNumber);
      existing.set('metadata', metadata);
      applyCollectionBillPresentationFields(
        existing,
        existing.get('accountingDocumentNumber'),
      );
      applyBusinessCaseIdToDocument(
        existing,
        businessCaseId || trade.get('businessCaseId'),
      );
      await existing.save(null, { useMasterKey: true });
      console.log(
        `📄 CollectionBill idempotent update: ${existing.get('accountingDocumentNumber') || existing.id} `
        + `investor ${investorId}, investment ${investmentId}, trade ${trade.id}`,
      );
      return existing;
    }
  }

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
  applyCollectionBillPresentationFields(doc, docNumber);
  const { metadata } = buildCollectionBillBelegSnapshot({
    investmentCapital,
    ownershipPercentage,
    commissionRate,
    traderCommissionRate,
    appCommissionRate,
    buyLeg,
    sellLeg,
    taxBreakdown,
    grossProfit,
    commission,
    traderCommission,
    appCommission,
    netProfit,
    returnPercentage,
  });
  doc.set('metadata', metadata);

  applyBusinessCaseIdToDocument(
    doc,
    businessCaseId || trade.get('businessCaseId'),
  );

  await doc.save(null, { useMasterKey: true });
  console.log(`📄 CollectionBill created: ${docNumber} for investor ${investorId}, investment ${investmentId}`);
  return doc;
}

module.exports = {
  computeCollectionBillReturnPercentage,
  assertCollectionBillReturnPercentageInvariant,
  createCollectionBillDocument,
};
