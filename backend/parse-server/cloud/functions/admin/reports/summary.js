'use strict';

const { requirePermission } = require('../../../utils/permissions');
const { getTraderCommissionRate } = require('../../../utils/configHelper/index.js');
const { applyQuerySort } = require('../../../utils/applyQuerySort');

const MAX_PAGE_SIZE = 100;

function parseDateParam(v) {
  if (v == null || v === '') return null;
  const d = v instanceof Date ? v : new Date(v);
  return Number.isNaN(d.getTime()) ? null : d;
}

function buildInvestmentMatch({ dateFrom, dateTo, investorId, traderId }) {
  const match = {};
  if (dateFrom || dateTo) {
    match.createdAt = {};
    if (dateFrom) match.createdAt.$gte = parseDateParam(dateFrom);
    if (dateTo) match.createdAt.$lte = parseDateParam(dateTo);
  }
  if (investorId) match.investorId = investorId;
  if (traderId) match.traderId = traderId;
  return match;
}

function buildTradeMatch({ dateFrom, dateTo, traderId }) {
  const match = {};
  if (dateFrom || dateTo) {
    match.createdAt = {};
    if (dateFrom) match.createdAt.$gte = parseDateParam(dateFrom);
    if (dateTo) match.createdAt.$lte = parseDateParam(dateTo);
  }
  if (traderId) match.traderId = traderId;
  return match;
}

function applyInvestmentQueryFilters(query, filters) {
  const { dateFrom, dateTo, investorId, traderId } = filters;
  const from = parseDateParam(dateFrom);
  const to = parseDateParam(dateTo);
  if (from) query.greaterThanOrEqualTo('createdAt', from);
  if (to) query.lessThanOrEqualTo('createdAt', to);
  if (investorId) query.equalTo('investorId', investorId);
  if (traderId) query.equalTo('traderId', traderId);
}

function applyTradeQueryFilters(query, filters) {
  const { dateFrom, dateTo, traderId } = filters;
  const from = parseDateParam(dateFrom);
  const to = parseDateParam(dateTo);
  if (from) query.greaterThanOrEqualTo('createdAt', from);
  if (to) query.lessThanOrEqualTo('createdAt', to);
  if (traderId) query.equalTo('traderId', traderId);
}

function investmentAggPipeline(match) {
  const stages = [];
  if (match && Object.keys(match).length > 0) {
    stages.push({ $match: match });
  }
  stages.push({
    $addFields: {
      effCurrent: { $ifNull: ['$currentValue', '$amount'] },
      rowGross: {
        $subtract: [{ $ifNull: ['$currentValue', '$amount'] }, { $ifNull: ['$amount', 0] }],
      },
    },
  });
  stages.push({
    $group: {
      _id: null,
      totalInvestedAmount: { $sum: { $ifNull: ['$amount', 0] } },
      totalCurrentValue: { $sum: '$effCurrent' },
      totalGrossProfit: { $sum: '$rowGross' },
      positiveGrossSum: {
        $sum: { $cond: [{ $gt: ['$rowGross', 0] }, '$rowGross', 0] },
      },
    },
  });
  return stages;
}

function tradeAggPipeline(match) {
  const stages = [];
  if (match && Object.keys(match).length > 0) {
    stages.push({ $match: match });
  }
  stages.push({
    $addFields: {
      buyAmt: { $ifNull: ['$buyOrder.totalAmount', 0] },
      sellSingle: { $ifNull: ['$sellOrder.totalAmount', 0] },
      sellFromArray: {
        $reduce: {
          input: { $ifNull: ['$sellOrders', []] },
          initialValue: 0,
          in: { $add: ['$$value', { $ifNull: ['$$this.totalAmount', 0] }] },
        },
      },
    },
  });
  stages.push({
    $addFields: {
      sellAmt: {
        $cond: [
          { $gt: [{ $size: { $ifNull: ['$sellOrders', []] } }, 0] },
          '$sellFromArray',
          '$sellSingle',
        ],
      },
    },
  });
  stages.push({
    $addFields: {
      rowProfit: {
        $ifNull: [
          '$calculatedProfit',
          { $ifNull: ['$grossProfit', { $subtract: ['$sellAmt', '$buyAmt'] }] },
        ],
      },
      rowVolume: { $max: ['$buyAmt', '$sellAmt'] },
    },
  });
  stages.push({
    $group: {
      _id: null,
      totalTradeProfit: { $sum: '$rowProfit' },
      totalTradeVolume: { $sum: '$rowVolume' },
    },
  });
  return stages;
}

function mapInvestmentRow(inv, commissionRate) {
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
}

function mapTradeRow(trade) {
  const buyOrder = trade.get('buyOrder') || {};
  const sellOrder = trade.get('sellOrder') || {};
  const sellOrders = trade.get('sellOrders') || [];

  const buyAmount = buyOrder.totalAmount || 0;
  let sellAmount = sellOrder.totalAmount || 0;
  if (sellOrders.length > 0) {
    sellAmount = sellOrders.reduce((s, o) => s + (o.totalAmount || 0), 0);
  }
  const profit =
    trade.get('calculatedProfit') || trade.get('grossProfit') || sellAmount - buyAmount;

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
}

function firstAggRow(rows) {
  if (!Array.isArray(rows) || rows.length === 0) return {};
  return rows[0] || {};
}

function registerSummaryReportFunctions() {
  Parse.Cloud.define('getSummaryReport', async (request) => {
    requirePermission(request, 'getFinancialDashboard');

    const { dateFrom, dateTo, investorId, traderId } = request.params || {};
    const filters = { dateFrom, dateTo, investorId, traderId };
    const commissionRate = await getTraderCommissionRate();

    const invMatch = buildInvestmentMatch(filters);
    const tradeMatch = buildTradeMatch(filters);

    const invQuery = new Parse.Query('Investment');
    applyInvestmentQueryFilters(invQuery, filters);

    const tradeQuery = new Parse.Query('Trade');
    applyTradeQueryFilters(tradeQuery, filters);

    const invPipeline = investmentAggPipeline(invMatch);
    const tradePipeline = tradeAggPipeline(tradeMatch);

    const [totalInvestments, totalTrades, invAggRows, tradeAggRows] = await Promise.all([
      invQuery.count({ useMasterKey: true }),
      tradeQuery.count({ useMasterKey: true }),
      new Parse.Query('Investment').aggregate(invPipeline, { useMasterKey: true }),
      new Parse.Query('Trade').aggregate(tradePipeline, { useMasterKey: true }),
    ]);

    const invAgg = firstAggRow(invAggRows);
    const tradeAgg = firstAggRow(tradeAggRows);

    const totalInvestedAmount = Number(invAgg.totalInvestedAmount) || 0;
    const totalCurrentValue = Number(invAgg.totalCurrentValue) || 0;
    const totalGrossProfit = Number(invAgg.totalGrossProfit) || 0;
    const positiveGrossSum = Number(invAgg.positiveGrossSum) || 0;
    const totalCommission = positiveGrossSum * commissionRate;

    const totalTradeVolume = Number(tradeAgg.totalTradeVolume) || 0;
    const totalTradeProfit = Number(tradeAgg.totalTradeProfit) || 0;

    return {
      summary: {
        totalInvestments,
        totalTrades,
        totalInvestedAmount,
        totalCurrentValue,
        totalGrossProfit,
        totalCommission,
        totalTradeVolume,
        totalTradeProfit,
        netReturn:
          totalInvestedAmount > 0
            ? ((totalCurrentValue - totalInvestedAmount) / totalInvestedAmount) * 100
            : 0,
        commissionRate,
      },
      generatedAt: new Date().toISOString(),
    };
  });

  Parse.Cloud.define('getSummaryReportInvestmentsPage', async (request) => {
    requirePermission(request, 'getFinancialDashboard');

    const {
      dateFrom,
      dateTo,
      investorId,
      traderId,
      page: pageRaw,
      pageSize: pageSizeRaw,
    } = request.params || {};
    const page = Math.max(0, parseInt(pageRaw, 10) || 0);
    const pageSize = Math.min(MAX_PAGE_SIZE, Math.max(1, parseInt(pageSizeRaw, 10) || 25));
    const filters = { dateFrom, dateTo, investorId, traderId };

    const commissionRate = await getTraderCommissionRate();

    const base = new Parse.Query('Investment');
    applyInvestmentQueryFilters(base, filters);

    const total = await base.count({ useMasterKey: true });

    const pageQuery = new Parse.Query('Investment');
    applyInvestmentQueryFilters(pageQuery, filters);
    applyQuerySort(pageQuery, request.params || {}, {
      allowed: ['createdAt', 'amount'],
      defaultField: 'createdAt',
      defaultDesc: true,
    });
    pageQuery.skip(page * pageSize);
    pageQuery.limit(pageSize);

    const rows = await pageQuery.find({ useMasterKey: true });
    const items = rows.map((inv) => mapInvestmentRow(inv, commissionRate));

    return { items, total, page, pageSize };
  });

  Parse.Cloud.define('getSummaryReportTradesPage', async (request) => {
    requirePermission(request, 'getFinancialDashboard');

    const {
      dateFrom,
      dateTo,
      traderId,
      page: pageRaw,
      pageSize: pageSizeRaw,
    } = request.params || {};
    const page = Math.max(0, parseInt(pageRaw, 10) || 0);
    const pageSize = Math.min(MAX_PAGE_SIZE, Math.max(1, parseInt(pageSizeRaw, 10) || 25));
    const filters = { dateFrom, dateTo, traderId };

    const base = new Parse.Query('Trade');
    applyTradeQueryFilters(base, filters);

    const total = await base.count({ useMasterKey: true });

    const pageQuery = new Parse.Query('Trade');
    applyTradeQueryFilters(pageQuery, filters);
    applyQuerySort(pageQuery, request.params || {}, {
      allowed: ['createdAt', 'tradeNumber'],
      defaultField: 'createdAt',
      defaultDesc: true,
    });
    pageQuery.skip(page * pageSize);
    pageQuery.limit(pageSize);

    const rows = await pageQuery.find({ useMasterKey: true });
    const items = rows.map((t) => mapTradeRow(t));

    return { items, total, page, pageSize };
  });
}

module.exports = { registerSummaryReportFunctions };
