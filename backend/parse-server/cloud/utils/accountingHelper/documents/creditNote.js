'use strict';

const { generateSequentialNumber } = require('../../helpers');
const { round2, formatDateCompact, generateShortHash } = require('../shared');
const { resolveTraderDisplayNameForBeleg } = require('../../traderDisplayNameForBeleg');
const { applyBusinessCaseIdToDocument } = require('./shared');
const { buildCreditNoteInvestorBreakdownMetadata } = require('./creditNoteBreakdown');
const { resolveTradeNumberPresentation } = require('../../tradeNumberAllocation');

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
  const tradePresentation = resolveTradeNumberPresentation(trade);
  const tradeNumber = tradePresentation.tradeNumber;
  const docNumber = await generateSequentialNumber('CN', 'Document', 'accountingDocumentNumber');
  const dateStr = formatDateCompact(new Date());
  const hash = generateShortHash();
  const traderParty = await resolveTraderDisplayNameForBeleg(traderId);

  const breakdownMeta = buildCreditNoteInvestorBreakdownMetadata(investorBreakdown);

  const Document = Parse.Object.extend('Document');
  const doc = new Document();
  doc.set('userId', traderParty.traderId || traderId);
  doc.set('type', 'traderCreditNote');
  doc.set('name', `CreditNote_Trade${tradePresentation.filenameToken}_${dateStr}_${hash}.pdf`);
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
    ...breakdownMeta,
    taxBreakdown: taxBreakdown || null,
    generatedAt: new Date().toISOString(),
  });
  doc.set('traderCommissionRateSnapshot', commissionRate);

  applyBusinessCaseIdToDocument(doc, businessCaseId || trade.get('businessCaseId'));

  await doc.save(null, { useMasterKey: true });
  console.log(`📄 CreditNote created: ${docNumber} for ${tradePresentation.label || `trade #${tradeNumber}`}, commission €${round2(totalCommission)}`);
  return doc;
}

module.exports = {
  createCreditNoteDocument,
};
