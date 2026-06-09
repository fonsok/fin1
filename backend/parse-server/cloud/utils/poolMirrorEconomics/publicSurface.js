'use strict';

const { aggregatePoolInvestmentEconomics } = require('./aggregatePool');
const {
  sumPoolPiecesFromParticipations,
  resolvePoolBuyQuantity,
  resolvePoolMirrorTradeCapitalAllocated,
  applyTradeLevelPoolCapitalTotals,
  derivePoolSellState,
  applyPoolMirrorEconomicsToSnapshot,
  reconcilePoolMirrorSnapshot,
} = require('./resolvePoolMirrorState');
const {
  floorPoolPiecesFromCapital,
  resolvePoolSoldQtyCumulative,
  poolSellQuantityForTraderSellFraction,
  poolSellDeltaForTraderSellRange,
} = require('./traderSellMath');
const {
  loadParticipationEconomicsRows,
  computePoolPiecesForMirrorTrade,
  resolvePoolContextForTraderSell,
} = require('../poolMirrorQueries');
const { computeInvestorPartialSellDelta } = require('../poolMirrorInvestorDelta');
const { costBasisPerShareFromBuyLeg } = require('../accountingHelper/legPriceMetrics');
const { tradeEconomicsSnapshot } = require('./tradeLegEconomics');

/** Tier 1 — pool aggregation + mirror trade orchestration. */
const tier1UseCases = {
  tradeEconomicsSnapshot,
  aggregatePoolInvestmentEconomics,
  sumPoolPiecesFromParticipations,
  resolvePoolBuyQuantity,
  resolvePoolMirrorTradeCapitalAllocated,
  applyTradeLevelPoolCapitalTotals,
  derivePoolSellState,
  applyPoolMirrorEconomicsToSnapshot,
  reconcilePoolMirrorSnapshot,
  loadParticipationEconomicsRows,
  computePoolPiecesForMirrorTrade,
  resolvePoolContextForTraderSell,
  computeInvestorPartialSellDelta,
  costBasisPerShareFromBuyLeg,
};

/** Tier 2 — trader↔pool sell math helpers. */
const tier2SellMath = {
  floorPoolPiecesFromCapital,
  resolvePoolSoldQtyCumulative,
  poolSellQuantityForTraderSellFraction,
  poolSellDeltaForTraderSellRange,
};

/**
 * Package-internal:
 *   constants.ACTIVE_INVESTMENT_STATUSES
 *   aggregatePool.aggregatePoolAtCostBasis
 *   traderSellMath.TRADER_FULL_SELL_EPSILON (pairedTradeMirrorSync/sellSync imports submodule)
 */

const publicSurface = {
  ...tier1UseCases,
  ...tier2SellMath,
};

const API_TIERS = {
  useCases: Object.keys(tier1UseCases),
  sellMath: Object.keys(tier2SellMath),
  packageInternal: ['ACTIVE_INVESTMENT_STATUSES', 'aggregatePoolAtCostBasis', 'TRADER_FULL_SELL_EPSILON'],
};

module.exports = { publicSurface, API_TIERS };
