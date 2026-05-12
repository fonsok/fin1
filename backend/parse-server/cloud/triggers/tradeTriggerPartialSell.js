'use strict';

const { totalSellQuantity, totalSellAmount } = require('./tradeSellQuantityHelpers');

function normalizeOwnershipRatio(rawOwnership) {
  const ownership = Number(rawOwnership || 0);
  if (!Number.isFinite(ownership) || ownership <= 0) return 0;
  return ownership > 1 ? ownership / 100 : ownership;
}

async function applyPartialSellRealizationToInvestments({ trade, previousTrade }) {
  if (!trade || !previousTrade) return;
  const tradeId = trade.id;
  if (!tradeId) return;

  const currentQty = totalSellQuantity(trade);
  const prevQty = totalSellQuantity(previousTrade);
  const deltaQty = currentQty - prevQty;
  if (!Number.isFinite(deltaQty) || deltaQty <= 0) return;

  const currentAmount = totalSellAmount(trade);
  const prevAmount = totalSellAmount(previousTrade);
  const deltaAmount = currentAmount - prevAmount;
  if (!Number.isFinite(deltaAmount) || deltaAmount <= 0) return;

  const participations = await new Parse.Query('PoolTradeParticipation')
    .equalTo('tradeId', tradeId)
    .find({ useMasterKey: true });
  if (!participations.length) return;

  const buyOrder = trade.get('buyOrder') || {};
  const buyQuantity = Number(trade.get('quantity') || buyOrder.quantity || 0);
  const tradeSellVolumeProgress = buyQuantity > 0
    ? Math.min(1, Math.round((currentQty / buyQuantity) * 10000) / 10000)
    : 0;

  for (const participation of participations) {
    const investmentId = String(participation.get('investmentId') || '').trim();
    if (!investmentId) continue;
    const ownershipRatio = normalizeOwnershipRatio(participation.get('ownershipPercentage'));
    if (ownershipRatio <= 0) continue;

    // eslint-disable-next-line no-await-in-loop
    const investment = await new Parse.Query('Investment').get(investmentId, { useMasterKey: true }).catch(() => null);
    if (!investment) continue;
    const status = String(investment.get('status') || '');
    if (status === 'completed' || status === 'cancelled') continue;

    const qtyDeltaForInvestment = Math.round((deltaQty * ownershipRatio) * 10000) / 10000;
    const amountDeltaForInvestment = Math.round((deltaAmount * ownershipRatio) * 100) / 100;
    const prevCount = Number(investment.get('partialSellCount') || 0);
    const prevQtyValue = Number(investment.get('realizedSellQuantity') || 0);
    const prevAmountValue = Number(investment.get('realizedSellAmount') || 0);

    investment.set('partialSellCount', prevCount + 1);
    investment.set('realizedSellQuantity', Math.round((prevQtyValue + qtyDeltaForInvestment) * 10000) / 10000);
    investment.set('realizedSellAmount', Math.round((prevAmountValue + amountDeltaForInvestment) * 100) / 100);
    investment.set('lastPartialSellAt', new Date().toISOString());
    investment.set('tradeSellVolumeProgress', tradeSellVolumeProgress);

    // eslint-disable-next-line no-await-in-loop
    await investment.save(null, { useMasterKey: true });
  }
}

module.exports = {
  applyPartialSellRealizationToInvestments,
};
