'use strict';

const { generateSequentialNumber } = require('../../helpers');
const { round2, formatDateCompact, generateShortHash } = require('../shared');
const { resolveTraderDisplayNameForBeleg } = require('../../traderDisplayNameForBeleg');
const { applyBusinessCaseIdToDocument } = require('./shared');

async function createCreditNoteDocument({
  traderId,
  trade,
  totalCommission,
  commissionRate,
  grossProfit,
  netProfit,
  investorBreakdown,
  taxBreakdown,
  businessCaseId,
}) {
  const tradeNumber = trade.get('tradeNumber');
  const docNumber = await generateSequentialNumber('CN', 'Document', 'accountingDocumentNumber');
  const dateStr = formatDateCompact(new Date());
  const hash = generateShortHash();
  const traderParty = await resolveTraderDisplayNameForBeleg(traderId);

  const Document = Parse.Object.extend('Document');
  const doc = new Document();
  doc.set('userId', traderParty.traderId || traderId);
  doc.set('type', 'traderCreditNote');
  doc.set('name', `CreditNote_Trade${tradeNumber}_${dateStr}_${hash}.pdf`);
  doc.set('tradeId', trade.id);
  doc.set('tradeNumber', tradeNumber);
  doc.set('accountingDocumentNumber', docNumber);
  doc.set('source', 'backend');
  doc.set('metadata', {
    traderId: traderParty.traderId || String(traderId || '').trim() || null,
    traderDisplayName: traderParty.traderDisplayName,
    traderUsername: traderParty.traderUsername,
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

  applyBusinessCaseIdToDocument(doc, businessCaseId || trade.get('businessCaseId'));

  await doc.save(null, { useMasterKey: true });
  console.log(`📄 CreditNote created: ${docNumber} for trade #${tradeNumber}, commission €${round2(totalCommission)}`);
  return doc;
}

module.exports = {
  createCreditNoteDocument,
};
