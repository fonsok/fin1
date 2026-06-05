'use strict';

const { loadConfig } = require('../configHelper/index.js');
const { round2, formatDateCompact, generateShortHash } = require('./shared');
const { generateSequentialNumber } = require('../helpers');
const { attachLegPriceMetricsToSnapshot } = require('./legPriceMetrics');
const {
  resolvePoolContextForTraderSell,
  loadParticipationEconomicsRows,
  aggregatePoolInvestmentEconomics,
} = require('../poolMirrorEconomics');
const {
  buildPoolMirrorExecutionEigenbelegSnapshot,
} = require('./poolMirrorExecutionEigenbelegSnapshot');
const { totalSellQuantity } = require('../../triggers/tradeSellQuantityHelpers');

const DOC_TYPE = 'poolMirrorExecutionEigenbeleg';
const PREFIX_BY_EXEC = { buy: 'PMBC', sell: 'PMSC' };

function traderReferenceSnap(traderTrade, feeConfig) {
  if (!traderTrade) return {};
  const buyOrder = traderTrade.get('buyOrder') || {};
  const buyQty = Number(traderTrade.get('quantity') || buyOrder.quantity || 0);
  const soldQty = Number(traderTrade.get('soldQuantity') || 0) || totalSellQuantity(traderTrade);
  const buyAmount = Number(buyOrder.totalAmount || traderTrade.get('buyAmount') || 0);
  const metrics = attachLegPriceMetricsToSnapshot(
    {
      buyQuantity: buyQty,
      soldQuantity: soldQty,
      buyAmount: round2(buyAmount),
      buyPrice: Number(buyOrder.price || traderTrade.get('buyPrice') || 0),
    },
    feeConfig,
  );
  return {
    tradeId: traderTrade.id,
    tradeNumber: traderTrade.get('tradeNumber'),
    buyQuantity: metrics.buyQuantity,
    soldQuantity: metrics.soldQuantity,
    buyFeesTotal: metrics.buyFeesTotal,
    totalBuyCost: metrics.totalBuyCost,
    costBasisPerShare: metrics.costBasisPerShare,
    bidPricePerShare: metrics.bidPricePerShare,
  };
}

function poolSnapFromTrade(poolTrade, participations, traderSnap, feeConfig) {
  const buyOrder = poolTrade.get('buyOrder') || {};
  const instrument = {
    symbol: poolTrade.get('symbol') || buyOrder.symbol || 'N/A',
    wknOrIsin: poolTrade.get('wkn') || buyOrder.wkn || poolTrade.get('symbol'),
    underlyingAsset: poolTrade.get('underlyingAsset') || buyOrder.underlyingAsset,
    optionDirection: poolTrade.get('optionDirection') || buyOrder.optionDirection,
  };
  const buyPrice = Number(buyOrder.price || poolTrade.get('buyPrice') || 0);
  const sellPrice = Number(poolTrade.get('exitPrice') || poolTrade.get('sellPrice') || 0);
  const traderRef = traderSnap.tradeId
    ? { buyQuantity: traderSnap.buyQuantity, soldQuantity: traderSnap.soldQuantity }
    : null;
  const poolEcon = aggregatePoolInvestmentEconomics(
    participations,
    buyPrice,
    traderRef,
    {
      feeConfig,
      sellPrice,
      costBasisPerShare: traderSnap.costBasisPerShare,
    },
  );
  return {
    tradeId: poolTrade.id,
    tradeNumber: poolTrade.get('tradeNumber'),
    status: poolTrade.get('status'),
    symbol: instrument.symbol,
    wknOrIsin: instrument.wknOrIsin,
    underlyingAsset: instrument.underlyingAsset,
    optionDirection: instrument.optionDirection,
    bidPricePerShare: traderSnap.bidPricePerShare,
    buyFeesTotal: traderSnap.buyFeesTotal,
    totalBuyCost: traderSnap.totalBuyCost,
    costBasisPerShare: poolEcon.costBasisPerShare || traderSnap.costBasisPerShare,
    ...poolEcon,
  };
}

/**
 * Idempotent Pool-Mirror Eigenbeleg after Trader TBC/TSC.
 * @returns {Promise<Parse.Object|null>}
 */
async function ensurePoolMirrorExecutionEigenbelegDocument({
  traderTrade,
  traderExecutionDoc,
  executionType,
  force = false,
}) {
  const poolCtx = await resolvePoolContextForTraderSell(traderTrade);
  if (!poolCtx) return null;

  const { poolTrade, traderTrade: traderLeg, participations } = poolCtx;
  if (!poolTrade?.id || poolTrade.id === traderLeg?.id && !participations.length) {
    return null;
  }

  const participationRows = await loadParticipationEconomicsRows(poolTrade.id);
  if (!participationRows.length) return null;

  const dup = new Parse.Query('Document');
  dup.equalTo('tradeId', poolTrade.id);
  dup.equalTo('type', DOC_TYPE);
  dup.equalTo('metadata.executionType', String(executionType).toLowerCase());
  const existing = await dup.first({ useMasterKey: true });
  if (existing && !force) return existing;

  const config = await loadConfig();
  const feeConfig = config.financial || {};
  const traderSnap = traderReferenceSnap(traderLeg, feeConfig);
  const poolSnap = poolSnapFromTrade(poolTrade, participationRows, traderSnap, feeConfig);

  const prefix = PREFIX_BY_EXEC[String(executionType).toLowerCase()] || 'PME';
  const docNumber = await generateSequentialNumber(prefix, 'Document', 'accountingDocumentNumber');
  const linkedTraderDocumentNumber = traderExecutionDoc?.get?.('accountingDocumentNumber') || null;

  const snapshot = buildPoolMirrorExecutionEigenbelegSnapshot({
    executionType,
    poolSnap,
    traderSnap,
    docNumber,
    linkedTraderDocumentNumber,
  });

  const label = snapshot.metadata.label || 'Pool-Mirror Eigenbeleg';
  const dateStr = formatDateCompact(new Date());
  const hash = generateShortHash();
  const traderId = poolTrade.get('traderId') || traderLeg.get('traderId');

  const Document = Parse.Object.extend('Document');
  const doc = existing || new Document();
  doc.set('userId', traderId);
  doc.set('type', DOC_TYPE);
  doc.set('name', `${label}_Pool${poolTrade.get('tradeNumber')}_${dateStr}_${hash}.pdf`);
  doc.set('tradeId', poolTrade.id);
  doc.set('tradeNumber', poolTrade.get('tradeNumber'));
  doc.set('accountingDocumentNumber', docNumber);
  doc.set('source', 'backend');
  doc.set('metadata', snapshot.metadata);
  doc.set('accountingSummaryText', snapshot.accountingSummaryText);
  doc.set('size', Buffer.byteLength(snapshot.accountingSummaryText, 'utf8'));

  const bc = traderExecutionDoc?.get?.('businessCaseId') || poolTrade.get('businessCaseId');
  if (bc) {
    const meta = doc.get('metadata') || {};
    doc.set('metadata', Object.assign({}, meta, { businessCaseId: bc }));
    doc.set('businessCaseId', bc);
  }

  await doc.save(null, { useMasterKey: true });
  return doc;
}

module.exports = {
  DOC_TYPE,
  ensurePoolMirrorExecutionEigenbelegDocument,
  poolSnapFromTrade,
  traderReferenceSnap,
};
