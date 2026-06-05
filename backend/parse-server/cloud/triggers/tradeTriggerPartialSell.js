'use strict';

const { totalSellQuantity, totalSellAmount } = require('./tradeSellQuantityHelpers');
const {
  resolvePoolContextForTraderSell,
  computePoolPiecesForMirrorTrade,
  poolSellQuantityForTraderSellFraction,
} = require('../utils/poolMirrorEconomics');
const { resolveTradeBuyPrice } = require('../utils/accountingHelper/shared');
const { getMaxTraderPartialSells } = require('../utils/configHelper/traderPartialSellLimits');

function normalizeOwnershipRatio(rawOwnership) {
  const ownership = Number(rawOwnership || 0);
  if (!Number.isFinite(ownership) || ownership <= 0) return 0;
  return ownership > 1 ? ownership / 100 : ownership;
}

async function applyPartialSellRealizationToInvestments({ trade, previousTrade }) {
  if (!trade || !previousTrade) return;

  const maxPartial = await getMaxTraderPartialSells();
  if (maxPartial === 0) return;

  const currentQty = totalSellQuantity(trade);
  const prevQty = totalSellQuantity(previousTrade);
  const deltaQty = currentQty - prevQty;
  if (!Number.isFinite(deltaQty) || deltaQty <= 0) return;

  const currentAmount = totalSellAmount(trade);
  const prevAmount = totalSellAmount(previousTrade);
  const deltaAmount = currentAmount - prevAmount;
  if (!Number.isFinite(deltaAmount) || deltaAmount <= 0) return;

  const poolCtx = await resolvePoolContextForTraderSell(trade);
  if (!poolCtx) return;

  const { traderTrade, poolTrade, participations } = poolCtx;
  const buyOrder = traderTrade.get('buyOrder') || {};
  const traderBuyQuantity = Number(traderTrade.get('quantity') || buyOrder.quantity || 0);
  const traderSellVolumeProgress = traderBuyQuantity > 0
    ? Math.min(1, Math.round((currentQty / traderBuyQuantity) * 10000) / 10000)
    : 0;

  const buyPrice = resolveTradeBuyPrice(poolTrade);
  const poolPieces = await computePoolPiecesForMirrorTrade(poolTrade, buyPrice);
  const poolSoldTarget = poolSellQuantityForTraderSellFraction(poolPieces, traderSellVolumeProgress);

  const investmentIds = [
    ...new Set(
      participations
        .map((p) => String(p.get('investmentId') || '').trim())
        .filter(Boolean),
    ),
  ];
  if (investmentIds.length === 0) return;

  const iq = new Parse.Query('Investment');
  iq.containedIn('objectId', investmentIds);
  iq.notContainedIn('status', ['completed', 'cancelled']);
  iq.limit(Math.min(investmentIds.length, 500));
  const investments = await iq.find({ useMasterKey: true });
  const investmentById = new Map(investments.map((inv) => [inv.id, inv]));

  const toSave = [];
  const nowIso = new Date().toISOString();

  for (const participation of participations) {
    const investmentId = String(participation.get('investmentId') || '').trim();
    const investment = investmentById.get(investmentId);
    if (!investment) continue;

    const ownershipRatio = normalizeOwnershipRatio(participation.get('ownershipPercentage'));
    if (ownershipRatio <= 0) continue;

    const investmentCapital = Number(investment.get('amount') || investment.get('currentValue') || 0);
    const investorPoolPieces = buyPrice > 0 ? Math.floor(investmentCapital / buyPrice) : 0;
    const sellFraction = traderBuyQuantity > 0 ? deltaQty / traderBuyQuantity : 0;
    const qtyDeltaForInvestment = Math.floor(investorPoolPieces * sellFraction);
    const amountDeltaForInvestment = Math.round((deltaAmount * ownershipRatio) * 100) / 100;
    const prevCount = Number(investment.get('partialSellCount') || 0);
    const prevQtyValue = Number(investment.get('realizedSellQuantity') || 0);
    const prevAmountValue = Number(investment.get('realizedSellAmount') || 0);

    investment.set('partialSellCount', prevCount + 1);
    investment.set('realizedSellQuantity', Math.round((prevQtyValue + qtyDeltaForInvestment) * 10000) / 10000);
    investment.set('realizedSellAmount', Math.round((prevAmountValue + amountDeltaForInvestment) * 100) / 100);
    investment.set('lastPartialSellAt', nowIso);
    investment.set('tradeSellVolumeProgress', traderSellVolumeProgress);
    if (poolPieces > 0) {
      investment.set('poolSellVolumeProgress', poolSoldTarget / poolPieces);
    }
    toSave.push(investment);
  }

  const BATCH = 40;
  for (let i = 0; i < toSave.length; i += BATCH) {
    const chunk = toSave.slice(i, i + BATCH);
    // eslint-disable-next-line no-await-in-loop
    await Parse.Object.saveAll(chunk, { useMasterKey: true });
  }
}

module.exports = {
  applyPartialSellRealizationToInvestments,
};
