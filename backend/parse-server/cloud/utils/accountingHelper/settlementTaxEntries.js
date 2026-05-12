'use strict';

async function bookInvestorTaxEntries({
  investorId,
  investmentId,
  investmentNumber,
  trade,
  tradeNumber,
  collectionBillId,
  collectionBillNumber,
  taxBreakdown,
  bookSettlementEntry,
  businessCaseId,
}) {
  if (taxBreakdown.withholdingTax > 0) {
    await bookSettlementEntry({
      userId: investorId,
      userRole: 'investor',
      entryType: 'withholding_tax_debit',
      amount: -Math.abs(taxBreakdown.withholdingTax),
      tradeId: trade.id,
      tradeNumber,
      investmentId,
      investmentNumber,
      description: `Abgeltungsteuer Trade #${tradeNumber}`,
      referenceDocumentId: collectionBillId,
      referenceDocumentNumber: collectionBillNumber,
      businessCaseId,
    });
  }
  if (taxBreakdown.solidaritySurcharge > 0) {
    await bookSettlementEntry({
      userId: investorId,
      userRole: 'investor',
      entryType: 'solidarity_surcharge_debit',
      amount: -Math.abs(taxBreakdown.solidaritySurcharge),
      tradeId: trade.id,
      tradeNumber,
      investmentId,
      investmentNumber,
      description: `Solidaritätszuschlag Trade #${tradeNumber}`,
      referenceDocumentId: collectionBillId,
      referenceDocumentNumber: collectionBillNumber,
      businessCaseId,
    });
  }
  if (taxBreakdown.churchTax > 0) {
    await bookSettlementEntry({
      userId: investorId,
      userRole: 'investor',
      entryType: 'church_tax_debit',
      amount: -Math.abs(taxBreakdown.churchTax),
      tradeId: trade.id,
      tradeNumber,
      investmentId,
      investmentNumber,
      description: `Kirchensteuer Trade #${tradeNumber}`,
      referenceDocumentId: collectionBillId,
      referenceDocumentNumber: collectionBillNumber,
      businessCaseId,
    });
  }
}

async function bookTraderTaxEntries({
  traderId,
  trade,
  tradeNumber,
  creditNoteId,
  creditNoteNumber,
  taxBreakdown,
  bookSettlementEntry,
  businessCaseId,
}) {
  if (taxBreakdown.withholdingTax > 0) {
    await bookSettlementEntry({
      userId: traderId,
      userRole: 'trader',
      entryType: 'withholding_tax_debit',
      amount: -Math.abs(taxBreakdown.withholdingTax),
      tradeId: trade.id,
      tradeNumber,
      description: `Abgeltungsteuer Trader-Provision Trade #${tradeNumber}`,
      referenceDocumentId: creditNoteId,
      referenceDocumentNumber: creditNoteNumber,
      businessCaseId,
    });
  }
  if (taxBreakdown.solidaritySurcharge > 0) {
    await bookSettlementEntry({
      userId: traderId,
      userRole: 'trader',
      entryType: 'solidarity_surcharge_debit',
      amount: -Math.abs(taxBreakdown.solidaritySurcharge),
      tradeId: trade.id,
      tradeNumber,
      description: `Solidaritätszuschlag Trader-Provision Trade #${tradeNumber}`,
      referenceDocumentId: creditNoteId,
      referenceDocumentNumber: creditNoteNumber,
      businessCaseId,
    });
  }
  if (taxBreakdown.churchTax > 0) {
    await bookSettlementEntry({
      userId: traderId,
      userRole: 'trader',
      entryType: 'church_tax_debit',
      amount: -Math.abs(taxBreakdown.churchTax),
      tradeId: trade.id,
      tradeNumber,
      description: `Kirchensteuer Trader-Provision Trade #${tradeNumber}`,
      referenceDocumentId: creditNoteId,
      referenceDocumentNumber: creditNoteNumber,
      businessCaseId,
    });
  }
}

module.exports = {
  bookInvestorTaxEntries,
  bookTraderTaxEntries,
};
