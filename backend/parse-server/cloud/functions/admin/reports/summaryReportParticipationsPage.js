'use strict';

const {
  loadParticipationsPageForPoolTrade,
  loadParticipationAggregatesByPoolTradeIds,
  enrichParticipationDisplayFields,
} = require('./summaryReportParticipationLoader');

async function handleGetSummaryReportTradeParticipationsPage(request) {
  const {
    poolTradeId,
    tradeId,
    page: pageRaw,
    pageSize: pageSizeRaw,
    costBasisPerShare,
  } = request.params || {};

  const resolvedPoolTradeId = String(poolTradeId || tradeId || '').trim();
  if (!resolvedPoolTradeId) {
    throw new Error('poolTradeId is required');
  }

  const pageResult = await loadParticipationsPageForPoolTrade(resolvedPoolTradeId, {
    page: pageRaw,
    pageSize: pageSizeRaw,
  });

  const aggregatesMap = await loadParticipationAggregatesByPoolTradeIds([resolvedPoolTradeId]);
  const aggregates = aggregatesMap.get(resolvedPoolTradeId) || {
    count: pageResult.total,
    totalCommission: 0,
    totalProfitShare: 0,
  };

  const items = enrichParticipationDisplayFields(
    pageResult.items,
    Number(costBasisPerShare || 0),
  );

  return {
    poolTradeId: resolvedPoolTradeId,
    items,
    total: pageResult.total,
    page: pageResult.page,
    pageSize: pageResult.pageSize,
    aggregates: {
      totalCommission: aggregates.totalCommission,
      totalProfitShare: aggregates.totalProfitShare,
    },
  };
}

module.exports = {
  handleGetSummaryReportTradeParticipationsPage,
};
