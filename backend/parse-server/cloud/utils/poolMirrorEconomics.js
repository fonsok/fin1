'use strict';

const { round2 } = require('./accountingHelper/shared');
const {
  computeInvestorBuyLeg,
  computeInvestorSellLeg,
  deriveMirrorTradeBasis,
} = require('./accountingHelper/legs');
const { costBasisPerShareFromBuyLeg } = require('./accountingHelper/legPriceMetrics');
const ACTIVE_INVESTMENT_STATUSES = new Set(['active', 'executing']);

function floorPoolPiecesFromCapital(investmentCapital, buyPrice) {
  const capital = Number(investmentCapital || 0);
  const price = Number(buyPrice || 0);
  if (!(price > 0) || !(capital > 0)) return 0;
  return Math.floor(capital / price);
}

/**
 * Pool-Summary / Investor-Zeilen am Einstand des ausgeführten Legs (totalBuyCost / Stück).
 */
function aggregatePoolAtCostBasis(
  participations,
  costBasisPerShare,
  traderReference,
  options = {},
) {
  const feeConfig = options.feeConfig || {};
  const sellPrice = Number(options.sellPrice || 0);
  const basis = Number(costBasisPerShare || 0);

  if (!Array.isArray(participations) || participations.length === 0 || !(basis > 0)) {
    return {
      poolCapitalAllocated: 0,
      poolReservedCapitalTotal: 0,
      poolResidualTotal: 0,
      poolInvestorCount: 0,
      impliedBuyQuantityFromPool: null,
      poolSoldQuantityDerived: 0,
      poolSellAmountDerived: 0,
      poolSellVolumeProgress: 0,
    };
  }

  let poolReservedCapital = 0;
  let poolPieces = 0;
  const activeInvestorIds = new Set();
  const investorPieceRows = [];

  for (const p of participations) {
    const status = String(p.investmentStatus || '').toLowerCase();
    if (!ACTIVE_INVESTMENT_STATUSES.has(status)) continue;
    const capital = Number(p.investmentCapital || 0);
    if (!(capital > 0)) continue;
    poolReservedCapital += capital;
    const pieces = Math.floor(capital / basis);
    poolPieces += pieces;
    investorPieceRows.push({ pieces, capital });
    if (p.investorId) activeInvestorIds.add(p.investorId);
  }

  poolReservedCapital = round2(poolReservedCapital);
  const poolActiveAmount = round2(poolPieces * basis);
  const poolResidual = round2(Math.max(0, poolReservedCapital - poolActiveAmount));

  let poolSoldQuantityDerived = 0;
  let poolSellAmountDerived = 0;
  let poolSellVolumeProgress = 0;
  if (traderReference && poolPieces > 0) {
    const traderBuy = Number(traderReference.buyQuantity || 0);
    const traderSold = Number(traderReference.soldQuantity || 0);
    const traderSellPct = traderBuy > 0 ? Math.min(1, traderSold / traderBuy) : 0;

    if (sellPrice > 0) {
      for (const row of investorPieceRows) {
        const sellLeg = computeInvestorSellLeg(row.pieces, sellPrice, traderSellPct, feeConfig);
        poolSoldQuantityDerived += Number(sellLeg?.quantity || 0);
        poolSellAmountDerived += Number(sellLeg?.amount || 0);
      }
    } else {
      poolSoldQuantityDerived = poolSellQuantityForTraderSellFraction(poolPieces, traderSellPct);
    }
    poolSellVolumeProgress = poolPieces > 0
      ? Math.round((poolSoldQuantityDerived / poolPieces) * 10000) / 10000
      : 0;
  }

  return {
    poolCapitalAllocated: poolActiveAmount,
    poolReservedCapitalTotal: poolReservedCapital,
    poolResidualTotal: poolResidual,
    poolInvestorCount: activeInvestorIds.size,
    impliedBuyQuantityFromPool: poolPieces > 0 ? poolPieces : null,
    poolSoldQuantityDerived,
    poolSellAmountDerived: round2(poolSellAmountDerived),
    poolSellVolumeProgress,
    costBasisPerShare: basis,
  };
}

/**
 * SSOT = legs.js (Collection Bill). Summary-Pool nutzt optional Einstand des Trade-Legs.
 * @param {object} [options] feeConfig, sellPrice, costBasisPerShare (Trade-Leg Einstand)
 */
function aggregatePoolInvestmentEconomics(
  participations,
  buyPrice,
  traderReference = null,
  options = {},
) {
  const feeConfig = options.feeConfig || {};
  const sellPrice = Number(options.sellPrice || 0);
  const costBasis = Number(options.costBasisPerShare || 0);

  if (costBasis > 0) {
    return aggregatePoolAtCostBasis(participations, costBasis, traderReference, {
      feeConfig,
      sellPrice,
    });
  }

  if (!Array.isArray(participations) || participations.length === 0 || !(buyPrice > 0)) {
    return {
      poolCapitalAllocated: 0,
      poolReservedCapitalTotal: 0,
      poolResidualTotal: 0,
      poolInvestorCount: 0,
      impliedBuyQuantityFromPool: null,
      poolSoldQuantityDerived: 0,
      poolSellAmountDerived: 0,
      poolSellVolumeProgress: 0,
    };
  }

  let poolReservedCapital = 0;
  let poolPieces = 0;
  let poolActiveAmount = 0;
  let poolResidual = 0;
  const activeInvestorIds = new Set();
  const buyLegs = [];

  for (const p of participations) {
    const status = String(p.investmentStatus || '').toLowerCase();
    if (!ACTIVE_INVESTMENT_STATUSES.has(status)) continue;
    const capital = Number(p.investmentCapital || 0);
    if (!(capital > 0)) continue;
    poolReservedCapital += capital;
    const buyLeg = computeInvestorBuyLeg(capital, buyPrice, feeConfig);
    if (!buyLeg?.quantity) continue;
    buyLegs.push(buyLeg);
    poolPieces += buyLeg.quantity;
    poolActiveAmount += Number(buyLeg.amount || 0);
    poolResidual += Number(buyLeg.residualAmount || 0);
    if (p.investorId) activeInvestorIds.add(p.investorId);
  }

  poolReservedCapital = round2(poolReservedCapital);
  poolActiveAmount = round2(poolActiveAmount);
  poolResidual = round2(poolResidual);

  let poolSoldQuantityDerived = 0;
  let poolSellAmountDerived = 0;
  let poolSellVolumeProgress = 0;
  if (traderReference && poolPieces > 0) {
    const traderBuy = Number(traderReference.buyQuantity || 0);
    const traderSold = Number(traderReference.soldQuantity || 0);
    const traderSellPct = traderBuy > 0 ? Math.min(1, traderSold / traderBuy) : 0;

    if (sellPrice > 0 && buyLegs.length) {
      for (const buyLeg of buyLegs) {
        const sellLeg = computeInvestorSellLeg(buyLeg.quantity, sellPrice, traderSellPct, feeConfig);
        poolSoldQuantityDerived += Number(sellLeg?.quantity || 0);
        poolSellAmountDerived += Number(sellLeg?.amount || 0);
      }
    } else {
      poolSoldQuantityDerived = poolSellQuantityForTraderSellFraction(poolPieces, traderSellPct);
      poolSellAmountDerived = round2(poolSoldQuantityDerived * sellPrice);
    }
    poolSellVolumeProgress = poolPieces > 0
      ? Math.round((poolSoldQuantityDerived / poolPieces) * 10000) / 10000
      : 0;
  }

  return {
    poolCapitalAllocated: poolActiveAmount,
    poolReservedCapitalTotal: poolReservedCapital,
    poolResidualTotal: poolResidual,
    poolInvestorCount: activeInvestorIds.size
      || participations.filter((p) => ACTIVE_INVESTMENT_STATUSES.has(String(p.investmentStatus || '').toLowerCase())).length,
    impliedBuyQuantityFromPool: poolPieces > 0 ? poolPieces : null,
    poolSoldQuantityDerived,
    poolSellAmountDerived: round2(poolSellAmountDerived),
    poolSellVolumeProgress,
  };
}

/**
 * Trader-Leg-Teilverkauf → Pool-Stück (abrunden). sellFraction = Anteil dieser Verkaufsbewegung am Trader-Leg.
 */
function poolSellQuantityForTraderSellFraction(poolPieces, sellFraction) {
  const pieces = Number(poolPieces || 0);
  const frac = Number(sellFraction || 0);
  if (!(pieces > 0) || !(frac > 0)) return 0;
  return Math.floor(pieces * Math.min(1, frac));
}

async function loadParticipationEconomicsRows(poolTradeId) {
  const parts = await new Parse.Query('PoolTradeParticipation')
    .equalTo('tradeId', poolTradeId)
    .limit(500)
    .find({ useMasterKey: true });
  if (!parts.length) return [];

  const investmentIds = [...new Set(parts.map((p) => p.get('investmentId')).filter(Boolean))];
  const invById = new Map();
  if (investmentIds.length) {
    const invRows = await new Parse.Query('Investment')
      .containedIn('objectId', investmentIds)
      .limit(investmentIds.length)
      .find({ useMasterKey: true });
    for (const inv of invRows) invById.set(inv.id, inv);
  }

  return parts.map((p) => {
    const inv = invById.get(p.get('investmentId') || '') || null;
    return {
      investorId: inv?.get('investorId') || p.get('investorId') || '',
      investmentStatus: String(inv?.get('status') || '').toLowerCase(),
      investmentCapital: round2(inv?.get('currentValue') || inv?.get('amount') || 0),
    };
  });
}

async function computePoolPiecesForMirrorTrade(mirrorTrade, buyPrice, feeConfig = {}) {
  if (!mirrorTrade?.id || !(buyPrice > 0)) return 0;
  const rows = await loadParticipationEconomicsRows(mirrorTrade.id);
  const econ = aggregatePoolInvestmentEconomics(rows, buyPrice, null, { feeConfig });
  return Number(econ.impliedBuyQuantityFromPool || 0);
}

/**
 * Paired buy: participations on mirror; sells often on trader leg.
 * @returns {Promise<{ poolTrade: Parse.Object, traderTrade: Parse.Object, participations: Parse.Object[] }|null>}
 */
async function resolvePoolContextForTraderSell(traderTrade) {
  if (!traderTrade?.id) return null;

  let participations = await new Parse.Query('PoolTradeParticipation')
    .equalTo('tradeId', traderTrade.id)
    .find({ useMasterKey: true });
  if (participations.length) {
    return { poolTrade: traderTrade, traderTrade, participations };
  }

  const { getMirrorTradeForPairedTraderLeg } = require('./pairedTradeMirrorSync');
  const mirror = await getMirrorTradeForPairedTraderLeg(traderTrade);
  if (!mirror) return null;

  participations = await new Parse.Query('PoolTradeParticipation')
    .equalTo('tradeId', mirror.id)
    .find({ useMasterKey: true });
  if (!participations.length) return null;

  return { poolTrade: mirror, traderTrade, participations };
}

/**
 * Investor Teil-Sell-Delta über legs.js (floor Stück), nicht allocatedAmount × Trader-%.
 */
function computeInvestorPartialSellDelta({
  investmentCapital,
  tradeBuyPrice,
  tradeSellPrice,
  sellFraction,
  commissionRate,
  feeConfig,
}) {
  if (!(investmentCapital > 0) || !(tradeBuyPrice > 0) || !(sellFraction > 0)) {
    return null;
  }
  const buyLeg = computeInvestorBuyLeg(investmentCapital, tradeBuyPrice, feeConfig || {});
  if (!buyLeg?.quantity) return null;
  const sellLeg = tradeSellPrice > 0
    ? computeInvestorSellLeg(buyLeg.quantity, tradeSellPrice, sellFraction, feeConfig || {})
    : null;
  if (!sellLeg?.quantity) return null;

  const sliceRatio = buyLeg.quantity > 0 ? sellLeg.quantity / buyLeg.quantity : sellFraction;
  const buyFees = buyLeg.fees?.totalFees || 0;
  const buySlice = {
    amount: round2(buyLeg.amount * sliceRatio),
    fees: { totalFees: round2(buyFees * sliceRatio) },
    residualAmount: 0,
  };
  const basis = deriveMirrorTradeBasis(buySlice, sellLeg, commissionRate);
  if (!basis) return null;

  return {
    buyLeg: buySlice,
    sellLeg,
    grossProfit: basis.grossProfit,
    commission: basis.commission,
    netProfit: basis.netProfit,
    investorSellCashDelta: round2(sellLeg.amount),
    investorCostDelta: buySlice.amount,
  };
}

module.exports = {
  ACTIVE_INVESTMENT_STATUSES,
  floorPoolPiecesFromCapital,
  aggregatePoolInvestmentEconomics,
  aggregatePoolAtCostBasis,
  poolSellQuantityForTraderSellFraction,
  loadParticipationEconomicsRows,
  computePoolPiecesForMirrorTrade,
  resolvePoolContextForTraderSell,
  computeInvestorPartialSellDelta,
  costBasisPerShareFromBuyLeg,
};
