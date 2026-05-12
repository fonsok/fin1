'use strict';

const { requirePermission } = require('../../../utils/permissions');
const { getMappedAccounts, BANK_CONTRA_ACCOUNTS } = require('./shared');

function registerBankContraReportFunctions() {
  Parse.Cloud.define('getBankContraLedger', async (request) => {
    requirePermission(request, 'getFinancialDashboard');

    const { account, investorId, dateFrom, dateTo, limit: maxResults = 500, skip = 0 } = request.params || {};

    let directPostings = [];
    try {
      const postingQuery = new Parse.Query('BankContraPosting');
      if (account) postingQuery.equalTo('account', account);
      if (investorId) postingQuery.equalTo('investorId', investorId);
      if (dateFrom) postingQuery.greaterThanOrEqualTo('createdAt', new Date(dateFrom));
      if (dateTo) postingQuery.lessThanOrEqualTo('createdAt', new Date(dateTo));
      postingQuery.descending('createdAt');
      postingQuery.limit(maxResults);
      postingQuery.skip(skip);
      directPostings = await postingQuery.find({ useMasterKey: true });
    } catch {
      // Class may not exist yet
    }

    const postings = directPostings.map((p) => ({
      id: p.id,
      account: p.get('account'),
      side: p.get('side'),
      amount: p.get('amount'),
      investorId: p.get('investorId'),
      investorName: p.get('investorName') || '',
      batchId: p.get('batchId'),
      investmentIds: p.get('investmentIds') || [],
      reference: p.get('reference'),
      createdAt: p.get('createdAt'),
      metadata: p.get('metadata') || {},
    }));

    if (postings.length === 0) {
      try {
        const invQuery = new Parse.Query('Invoice');
        invQuery.equalTo('invoiceType', 'service_charge');
        if (investorId) invQuery.equalTo('userId', investorId);
        if (dateFrom) invQuery.greaterThanOrEqualTo('createdAt', new Date(dateFrom));
        if (dateTo) invQuery.lessThanOrEqualTo('createdAt', new Date(dateTo));
        invQuery.descending('createdAt');
        invQuery.limit(maxResults);
        invQuery.skip(skip);

        const invoices = await invQuery.find({ useMasterKey: true });

        for (const invoice of invoices) {
          const grossAmount = invoice.get('totalAmount') || invoice.get('subtotal') || 0;
          if (grossAmount <= 0) continue;

          const vatRate = 0.19;
          const netAmount = grossAmount / (1 + vatRate);
          const vatAmount = grossAmount - netAmount;

          const invId = invoice.id;
          const investId = invoice.get('userId') || '';
          const investName = invoice.get('customerName') || '';
          const batchId = invoice.get('tradeId') || invoice.get('orderId') || invId;
          const createdAt = invoice.get('createdAt');

          postings.push({
            id: `${invId}-net`,
            account: 'BANK-PS-NET',
            side: 'credit',
            amount: Math.round(netAmount * 100) / 100,
            investorId: investId,
            investorName: investName,
            batchId,
            investmentIds: [],
            reference: `PSC-${batchId}`,
            createdAt,
            metadata: { component: 'net', grossAmount: grossAmount.toString() },
          });

          postings.push({
            id: `${invId}-vat`,
            account: 'BANK-PS-VAT',
            side: 'credit',
            amount: Math.round(vatAmount * 100) / 100,
            investorId: investId,
            investorName: investName,
            batchId,
            investmentIds: [],
            reference: `PSC-${batchId}`,
            createdAt,
            metadata: { component: 'vat', grossAmount: grossAmount.toString() },
          });
        }
      } catch {
        // Invoice class may not exist or invoiceType may differ; ignore
      }
    }

    const filtered = account ? postings.filter((p) => p.account === account) : postings;

    const totals = {};
    for (const p of filtered) {
      const key = p.account;
      if (!totals[key]) totals[key] = { credit: 0, debit: 0, net: 0 };
      if (p.side === 'credit') {
        totals[key].credit += p.amount;
        totals[key].net += p.amount;
      } else {
        totals[key].debit += p.amount;
        totals[key].net -= p.amount;
      }
    }

    for (const key of Object.keys(totals)) {
      totals[key].credit = Math.round(totals[key].credit * 100) / 100;
      totals[key].debit = Math.round(totals[key].debit * 100) / 100;
      totals[key].net = Math.round(totals[key].net * 100) / 100;
    }

    const bankCodes = new Set(BANK_CONTRA_ACCOUNTS.map((a) => a.code));
    const accounts = getMappedAccounts().filter((a) => bankCodes.has(a.code));

    return {
      postings: filtered,
      totals,
      totalCount: filtered.length,
      accounts,
    };
  });
}

module.exports = { registerBankContraReportFunctions };
