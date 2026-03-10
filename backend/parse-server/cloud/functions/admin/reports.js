'use strict';

const { requirePermission } = require('../../utils/permissions');
const { getTraderCommissionRate } = require('../../utils/configHelper');

Parse.Cloud.define('getSummaryReport', async (request) => {
  requirePermission(request, 'getFinancialDashboard');

  const { dateFrom, dateTo, investorId, traderId, limit: maxResults = 200 } = request.params || {};

  const commissionRate = await getTraderCommissionRate();

  const invQuery = new Parse.Query('Investment');
  if (dateFrom) invQuery.greaterThanOrEqualTo('createdAt', new Date(dateFrom));
  if (dateTo) invQuery.lessThanOrEqualTo('createdAt', new Date(dateTo));
  if (investorId) invQuery.equalTo('investorId', investorId);
  if (traderId) invQuery.equalTo('traderId', traderId);
  invQuery.descending('createdAt');
  invQuery.limit(maxResults);
  const investments = await invQuery.find({ useMasterKey: true });

  const investmentSummaries = investments.map(inv => {
    const amount = inv.get('amount') || 0;
    const currentValue = inv.get('currentValue') || amount;
    const grossProfit = currentValue - amount;
    const commission = grossProfit > 0 ? grossProfit * commissionRate : 0;

    return {
      investmentId: inv.id,
      investmentNumber: inv.get('investmentNumber') || inv.id.substring(0, 8),
      investorId: inv.get('investorId') || '',
      investorName: inv.get('investorName') || 'N/A',
      traderId: inv.get('traderId') || '',
      traderName: inv.get('traderName') || 'N/A',
      amount,
      currentValue,
      grossProfit,
      returnPercentage: amount > 0 ? (grossProfit / amount) * 100 : 0,
      commission,
      status: inv.get('status') || 'unknown',
      createdAt: inv.get('createdAt'),
    };
  });

  const tradeQuery = new Parse.Query('Trade');
  if (dateFrom) tradeQuery.greaterThanOrEqualTo('createdAt', new Date(dateFrom));
  if (dateTo) tradeQuery.lessThanOrEqualTo('createdAt', new Date(dateTo));
  if (traderId) tradeQuery.equalTo('traderId', traderId);
  tradeQuery.descending('createdAt');
  tradeQuery.limit(maxResults);
  const trades = await tradeQuery.find({ useMasterKey: true });

  const tradeSummaries = trades.map(trade => {
    const buyOrder = trade.get('buyOrder') || {};
    const sellOrder = trade.get('sellOrder') || {};
    const sellOrders = trade.get('sellOrders') || [];

    const buyAmount = buyOrder.totalAmount || 0;
    let sellAmount = sellOrder.totalAmount || 0;
    if (sellOrders.length > 0) {
      sellAmount = sellOrders.reduce((s, o) => s + (o.totalAmount || 0), 0);
    }
    const profit = trade.get('calculatedProfit') || trade.get('grossProfit') || (sellAmount - buyAmount);

    return {
      tradeId: trade.id,
      tradeNumber: trade.get('tradeNumber') || 0,
      symbol: trade.get('symbol') || buyOrder.symbol || 'N/A',
      traderId: trade.get('traderId') || '',
      buyAmount,
      sellAmount,
      profit,
      status: trade.get('status') || 'unknown',
      investorIds: trade.get('investorIds') || [],
      createdAt: trade.get('createdAt'),
    };
  });

  const totalInvestedAmount = investmentSummaries.reduce((s, i) => s + i.amount, 0);
  const totalCurrentValue = investmentSummaries.reduce((s, i) => s + i.currentValue, 0);
  const totalGrossProfit = investmentSummaries.reduce((s, i) => s + i.grossProfit, 0);
  const totalCommission = investmentSummaries.reduce((s, i) => s + i.commission, 0);
  const totalTradeVolume = tradeSummaries.reduce((s, t) => s + Math.max(t.buyAmount, t.sellAmount), 0);
  const totalTradeProfit = tradeSummaries.reduce((s, t) => s + t.profit, 0);

  return {
    summary: {
      totalInvestments: investmentSummaries.length,
      totalTrades: tradeSummaries.length,
      totalInvestedAmount,
      totalCurrentValue,
      totalGrossProfit,
      totalCommission,
      totalTradeVolume,
      totalTradeProfit,
      netReturn: totalInvestedAmount > 0 ? ((totalCurrentValue - totalInvestedAmount) / totalInvestedAmount) * 100 : 0,
      commissionRate,
    },
    investments: investmentSummaries,
    trades: tradeSummaries,
    generatedAt: new Date().toISOString(),
  };
});

Parse.Cloud.define('getBankContraLedger', async (request) => {
  requirePermission(request, 'getFinancialDashboard');

  const { account, investorId, dateFrom, dateTo, limit: maxResults = 500, skip = 0 } = request.params || {};

  const query = new Parse.Query('Investment');
  query.exists('platformServiceCharge');
  if (investorId) query.equalTo('investorId', investorId);
  if (dateFrom) query.greaterThanOrEqualTo('createdAt', new Date(dateFrom));
  if (dateTo) query.lessThanOrEqualTo('createdAt', new Date(dateTo));
  query.descending('createdAt');
  query.limit(maxResults);
  query.skip(skip);

  const investments = await query.find({ useMasterKey: true });

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

  const postings = directPostings.map(p => ({
    id: p.id,
    account: p.get('account'),
    side: p.get('side'),
    amount: p.get('amount'),
    investorId: p.get('investorId'),
    batchId: p.get('batchId'),
    investmentIds: p.get('investmentIds') || [],
    reference: p.get('reference'),
    createdAt: p.get('createdAt'),
    metadata: p.get('metadata') || {},
  }));

  if (postings.length === 0 && investments.length > 0) {
    for (const inv of investments) {
      const psc = inv.get('platformServiceCharge') || {};
      const grossAmount = psc.gross || psc.amount || 0;
      const vatRate = 0.19;
      const netAmount = grossAmount / (1 + vatRate);
      const vatAmount = grossAmount - netAmount;
      const invId = inv.id;
      const investId = inv.get('investorId') || '';

      if (grossAmount > 0) {
        const batchId = inv.get('batchId') || invId;
        postings.push({
          id: `${invId}-net`,
          account: 'BANK-PS-NET',
          side: 'credit',
          amount: Math.round(netAmount * 100) / 100,
          investorId: investId,
          batchId,
          investmentIds: [invId],
          reference: `PSC-${batchId}`,
          createdAt: inv.get('createdAt'),
          metadata: { component: 'net', grossAmount: grossAmount.toString() },
        });
        postings.push({
          id: `${invId}-vat`,
          account: 'BANK-PS-VAT',
          side: 'credit',
          amount: Math.round(vatAmount * 100) / 100,
          investorId: investId,
          batchId,
          investmentIds: [invId],
          reference: `PSC-${batchId}`,
          createdAt: inv.get('createdAt'),
          metadata: { component: 'vat', grossAmount: grossAmount.toString() },
        });
      }
    }
  }

  const filtered = account
    ? postings.filter(p => p.account === account)
    : postings;

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

  return {
    postings: filtered,
    totals,
    totalCount: filtered.length,
    accounts: [
      { code: 'BANK-PS-NET', name: 'Bank Clearing – Service Charge NET' },
      { code: 'BANK-PS-VAT', name: 'Bank Clearing – Service Charge VAT' },
    ],
  };
});
