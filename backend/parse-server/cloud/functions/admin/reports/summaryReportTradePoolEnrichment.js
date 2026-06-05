'use strict';

const { loadConfig } = require('../../../utils/configHelper/index.js');
const {
  getMirrorTradeForPairedTraderLeg,
  getTraderTradeForPairedMirrorLeg,
} = require('../../../utils/pairedTradeMirrorSync');
const { totalSellQuantity } = require('../../../triggers/tradeSellQuantityHelpers');
const {
  aggregatePoolInvestmentEconomics,
} = require('../../../utils/poolMirrorEconomics');
const { attachLegPriceMetricsToSnapshot } = require('../../../utils/accountingHelper/legPriceMetrics');
const {
  collectTradeIdsFromDraftRows,
  loadDocumentsByTradeIds,
  attachBelegeToSummaryRows,
} = require('./summaryReportTradeBelege');

function normalizeLegType(legType) {
  return String(legType || '').trim().toUpperCase();
}

function round2(n) {
  return Math.round(Number(n) * 100) / 100;
}

function round4(n) {
  return Math.round(Number(n) * 10000) / 10000;
}

function weightedAvgSellPrice(sellOrders) {
  let qtySum = 0;
  let amtSum = 0;
  for (const o of sellOrders) {
    const q = Number(o?.quantity || 0);
    const px = Number(o?.price || 0);
    if (q > 0 && px > 0) {
      qtySum += q;
      amtSum += q * px;
    }
  }
  if (qtySum > 0) return round4(amtSum / qtySum);
  return 0;
}

function extractInstrumentFields(trade) {
  const buyOrder = trade.get('buyOrder') || {};
  const wkn = String(trade.get('wkn') || buyOrder.wkn || '').trim();
  const isin = String(trade.get('isin') || buyOrder.isin || '').trim();
  const symbol = String(trade.get('symbol') || buyOrder.symbol || '').trim();
  const wknOrIsin = wkn || isin || symbol || null;
  const strike = Number(trade.get('strikePrice') || buyOrder.strikePrice || 0);
  return {
    wkn: wkn || null,
    isin: isin || null,
    wknOrIsin,
    symbol,
    underlyingAsset: trade.get('underlyingAsset') || buyOrder.underlyingAsset || null,
    issuer: trade.get('issuer') || buyOrder.issuer || null,
    optionDirection: trade.get('optionDirection') || buyOrder.optionDirection || null,
    strikePrice: strike > 0 ? round4(strike) : null,
  };
}

function applyPoolMirrorEconomicsOverrides(snap, poolEconomics) {
  if (!snap || !poolEconomics?.impliedBuyQuantityFromPool) return snap;
  const pieces = poolEconomics.impliedBuyQuantityFromPool;
  const sold = Number(poolEconomics.poolSoldQuantityDerived || 0);
  const buyAmt = poolEconomics.poolCapitalAllocated;
  const buyPx = snap.buyPrice;
  const sellPx = snap.sellPrice;
  const costBasis = Number(poolEconomics.costBasisPerShare || snap.costBasisPerShare || 0);
  const netSellPx = Number(snap.netSellPricePerShare || sellPx);
  const sellAmt = poolEconomics.poolSellAmountDerived > 0
    ? poolEconomics.poolSellAmountDerived
    : round2(sold * netSellPx);
  const profit =
    sold > 0 && costBasis > 0
      ? round2(sellAmt - sold * costBasis)
      : snap.profit;

  return {
    ...snap,
    buyQuantity: pieces,
    soldQuantity: sold,
    sellVolumeProgress: poolEconomics.poolSellVolumeProgress,
    buyAmount: buyAmt,
    sellAmount: sellAmt,
    profit,
    costBasisPerShare: costBasis > 0 ? costBasis : snap.costBasisPerShare,
    poolCapitalAllocated: poolEconomics.poolCapitalAllocated,
    poolReservedCapitalTotal: poolEconomics.poolReservedCapitalTotal,
    poolResidualTotal: poolEconomics.poolResidualTotal,
    poolInvestorCount: poolEconomics.poolInvestorCount,
    impliedBuyQuantityFromPool: pieces,
  };
}

function tradeEconomicsSnapshot(trade, participations = null, options = {}) {
  if (!trade) return null;
  const buyOrder = trade.get('buyOrder') || {};
  const instrument = extractInstrumentFields(trade);
  const sellOrders = trade.get('sellOrders') || [];
  const sellOrder = trade.get('sellOrder') || {};
  const resolvedSells = sellOrders.length > 0 ? sellOrders : (sellOrder ? [sellOrder] : []);
  const buyAmount = Number(buyOrder.totalAmount || trade.get('buyAmount') || 0);
  let sellAmount = Number(sellOrder.totalAmount || trade.get('sellAmount') || 0);
  if (sellOrders.length > 0) {
    sellAmount = sellOrders.reduce((s, o) => s + Number(o?.totalAmount || 0), 0);
  }
  const buyQuantity = Number(trade.get('quantity') || buyOrder.quantity || 0);
  const soldQuantity = Number(trade.get('soldQuantity') || 0) || totalSellQuantity(trade);
  const buyPrice = Number(
    buyOrder.price || trade.get('buyPrice') || trade.get('entryPrice') || 0,
  );
  let sellPrice = Number(
    sellOrder.price || trade.get('exitPrice') || trade.get('sellPrice') || 0,
  );
  if (resolvedSells.length > 0) {
    const avg = weightedAvgSellPrice(resolvedSells);
    if (avg > 0) sellPrice = avg;
  }
  const profit =
    Number(trade.get('calculatedProfit') || trade.get('grossProfit') || 0)
    || round2(sellAmount - buyAmount);

  const traderReference = options.traderReference || null;
  const applyPoolMirror = Boolean(options.applyPoolMirror && participations?.length);
  const feeConfig = options.feeConfig || {};

  let poolEconomics = null;
  const snapWithLegMetrics = attachLegPriceMetricsToSnapshot(
    {
      tradeId: trade.id,
      buyQuantity: round4(buyQuantity),
      soldQuantity: round4(soldQuantity),
      buyAmount: round2(buyAmount),
      sellAmount: round2(sellAmount),
      buyPrice: round4(buyPrice),
      sellPrice: round4(sellPrice),
    },
    feeConfig,
  );

  if (participations?.length) {
    const costBasisPerShare = Number(snapWithLegMetrics.costBasisPerShare || 0);
    poolEconomics = aggregatePoolInvestmentEconomics(
      participations,
      buyPrice,
      traderReference,
      { feeConfig, sellPrice, costBasisPerShare },
    );
  }

  const base = {
    tradeId: trade.id,
    tradeNumber: trade.get('tradeNumber') || 0,
    symbol: instrument.symbol || 'N/A',
    description: trade.get('description') || '',
    status: trade.get('status') || 'unknown',
    traderId: trade.get('traderId') || '',
    wkn: instrument.wkn,
    isin: instrument.isin,
    wknOrIsin: instrument.wknOrIsin,
    underlyingAsset: instrument.underlyingAsset,
    issuer: instrument.issuer,
    optionDirection: instrument.optionDirection,
    strikePrice: instrument.strikePrice,
    buyQuantity: snapWithLegMetrics.buyQuantity,
    soldQuantity: snapWithLegMetrics.soldQuantity,
    sellVolumeProgress: buyQuantity > 0 ? round4(Math.min(1, soldQuantity / buyQuantity)) : 0,
    buyPrice: snapWithLegMetrics.bidPricePerShare ?? round4(buyPrice),
    sellPrice: snapWithLegMetrics.askPricePerShare ?? round4(sellPrice),
    buyAmount: snapWithLegMetrics.totalBuyCost ?? round2(buyAmount),
    sellAmount: snapWithLegMetrics.netSellAmount ?? round2(sellAmount),
    profit: round2(profit),
    bidPricePerShare: snapWithLegMetrics.bidPricePerShare,
    buyFeesTotal: snapWithLegMetrics.buyFeesTotal,
    totalBuyCost: snapWithLegMetrics.totalBuyCost,
    costBasisPerShare: snapWithLegMetrics.costBasisPerShare,
    askPricePerShare: snapWithLegMetrics.askPricePerShare,
    sellFeesTotal: snapWithLegMetrics.sellFeesTotal,
    netSellAmount: snapWithLegMetrics.netSellAmount,
    netSellPricePerShare: snapWithLegMetrics.netSellPricePerShare,
    poolCapitalAllocated: poolEconomics?.poolCapitalAllocated ?? 0,
    poolReservedCapitalTotal: poolEconomics?.poolReservedCapitalTotal ?? 0,
    poolResidualTotal: poolEconomics?.poolResidualTotal ?? 0,
    poolInvestorCount: poolEconomics?.poolInvestorCount ?? 0,
    impliedBuyQuantityFromPool: poolEconomics?.impliedBuyQuantityFromPool ?? null,
    createdAt: trade.get('createdAt'),
    completedAt: trade.get('completedAt') || null,
  };

  if (applyPoolMirror && poolEconomics?.impliedBuyQuantityFromPool) {
    return applyPoolMirrorEconomicsOverrides(base, poolEconomics);
  }
  return base;
}

function resolveTraderAndPoolObjects(tradeRow, ctx, tradeById) {
  let legKind = ctx.legKind;
  const mirrorId = ctx.mirrorTradeId;
  const rowId = tradeRow.id;

  if (legKind === 'standalone' && mirrorId && mirrorId !== rowId) {
    legKind = 'trader';
  }

  let traderObj = null;
  let poolObj = null;

  if (legKind === 'mirror_pool') {
    traderObj = ctx.traderTradeId ? tradeById.get(ctx.traderTradeId) : null;
    poolObj = tradeRow;
  } else if (legKind === 'trader') {
    traderObj = tradeRow;
    poolObj = mirrorId ? tradeById.get(mirrorId) : null;
  } else if (mirrorId && mirrorId !== rowId) {
    traderObj = tradeRow;
    poolObj = tradeById.get(mirrorId);
    legKind = 'trader';
  } else {
    traderObj = tradeRow;
    poolObj = null;
  }

  const traderTrade = traderObj ? tradeEconomicsSnapshot(traderObj) : null;
  const poolMirrorTrade =
    poolObj && traderObj && poolObj.id !== traderObj.id
      ? tradeEconomicsSnapshot(poolObj)
      : poolObj && !traderObj
        ? tradeEconomicsSnapshot(poolObj)
        : null;

  return { legKind, traderTrade, poolMirrorTrade, poolTradeId: poolObj?.id || ctx.poolTradeId };
}

function resolvePoolParticipationsForRow(tradeRow, ctx, participationsByPool) {
  const candidates = [
    ctx.poolTradeId,
    tradeRow.id,
    ctx.mirrorTradeId,
  ].filter(Boolean);
  for (const tid of candidates) {
    const parts = participationsByPool.get(tid);
    if (parts?.length) return { poolTradeId: tid, participations: parts };
  }
  return { poolTradeId: ctx.poolTradeId || tradeRow.id, participations: [] };
}

function applyPoolMirrorFromParticipations({
  tradeRow,
  legKind,
  traderTrade,
  poolMirrorTrade,
  poolTradeId,
  participations,
  tradeById,
  feeConfig = {},
}) {
  if (!participations.length) {
    return { legKind, traderTrade, poolMirrorTrade, poolTradeId };
  }

  const poolObj =
    tradeById.get(poolTradeId)
    || (poolTradeId === tradeRow.id ? tradeRow : null);
  if (!poolObj) {
    return { legKind, traderTrade, poolMirrorTrade, poolTradeId };
  }

  const poolSnap = tradeEconomicsSnapshot(poolObj, participations, {
    traderReference: traderTrade,
    applyPoolMirror: true,
    feeConfig,
  });
  let nextLeg = legKind;
  let nextTrader = traderTrade;

  if (poolTradeId === tradeRow.id) {
    nextLeg = 'mirror_pool';
    if (!nextTrader) nextTrader = null;
  } else if (!poolMirrorTrade) {
    nextLeg = legKind === 'standalone' ? 'trader' : legKind;
  }

  return {
    legKind: nextLeg,
    traderTrade: nextTrader,
    poolMirrorTrade: poolSnap,
    poolTradeId,
  };
}

/**
 * Batch-resolve paired TRADER / MIRROR_POOL legs for a summary page of trades.
 * @returns {Map<string, { legKind: string, pairExecutionId: string|null, traderTradeId: string|null, mirrorTradeId: string|null, poolTradeId: string|null }>}
 */
async function resolvePairedLegContextsByTradeId(tradeRows) {
  const out = new Map();
  const buyOrderIds = [...new Set(tradeRows.map((t) => t.get('buyOrderId')).filter(Boolean))];
  if (buyOrderIds.length === 0) {
    for (const t of tradeRows) {
      out.set(t.id, {
        legKind: 'standalone',
        pairExecutionId: null,
        traderTradeId: t.id,
        mirrorTradeId: null,
        poolTradeId: t.id,
      });
    }
    return out;
  }

  const buyOrders = await new Parse.Query('Order')
    .containedIn('objectId', buyOrderIds)
    .limit(buyOrderIds.length)
    .find({ useMasterKey: true });
  const orderById = new Map(buyOrders.map((o) => [o.id, o]));

  const pairIds = new Set();
  for (const o of buyOrders) {
    const pid = o.get('pairExecutionId');
    if (pid) pairIds.add(String(pid));
  }

  const pairLegsByPairId = new Map();
  if (pairIds.size > 0) {
    const pairOrders = await new Parse.Query('Order')
      .containedIn('pairExecutionId', Array.from(pairIds))
      .limit(Math.min(5000, pairIds.size * 4))
      .find({ useMasterKey: true });
    for (const o of pairOrders) {
      const pid = String(o.get('pairExecutionId') || '');
      if (!pid) continue;
      if (!pairLegsByPairId.has(pid)) {
        pairLegsByPairId.set(pid, { trader: null, mirror: null });
      }
      const bucket = pairLegsByPairId.get(pid);
      const leg = normalizeLegType(o.get('legType'));
      if (leg === 'TRADER') bucket.trader = o;
      if (leg === 'MIRROR_POOL') bucket.mirror = o;
    }
  }

  for (const trade of tradeRows) {
    const buyOrderId = trade.get('buyOrderId');
    const order = buyOrderId ? orderById.get(buyOrderId) : null;
    const pairId = order?.get('pairExecutionId') ? String(order.get('pairExecutionId')) : null;
    const leg = normalizeLegType(order?.get('legType'));

    if (pairId && pairLegsByPairId.has(pairId)) {
      const { trader, mirror } = pairLegsByPairId.get(pairId);
      const traderTradeId = trader?.get('tradeId') || null;
      const mirrorTradeId = mirror?.get('tradeId') || null;
      const poolTradeId = mirrorTradeId || trade.id;

      if (leg === 'TRADER') {
        out.set(trade.id, {
          legKind: 'trader',
          pairExecutionId: pairId,
          traderTradeId: trade.id,
          mirrorTradeId,
          poolTradeId,
        });
      } else if (leg === 'MIRROR_POOL') {
        out.set(trade.id, {
          legKind: 'mirror_pool',
          pairExecutionId: pairId,
          traderTradeId,
          mirrorTradeId: trade.id,
          poolTradeId: trade.id,
        });
      } else if (trade.id === traderTradeId) {
        out.set(trade.id, {
          legKind: 'trader',
          pairExecutionId: pairId,
          traderTradeId: trade.id,
          mirrorTradeId,
          poolTradeId: mirrorTradeId || trade.id,
        });
      } else if (trade.id === mirrorTradeId) {
        out.set(trade.id, {
          legKind: 'mirror_pool',
          pairExecutionId: pairId,
          traderTradeId,
          mirrorTradeId: trade.id,
          poolTradeId: trade.id,
        });
      } else {
        out.set(trade.id, {
          legKind: mirrorTradeId && mirrorTradeId !== trade.id ? 'trader' : 'standalone',
          pairExecutionId: pairId,
          traderTradeId: traderTradeId || trade.id,
          mirrorTradeId,
          poolTradeId: mirrorTradeId || trade.id,
        });
      }
    } else {
      out.set(trade.id, {
        legKind: 'standalone',
        pairExecutionId: null,
        traderTradeId: trade.id,
        mirrorTradeId: null,
        poolTradeId: trade.id,
      });
    }
  }

  return out;
}

async function loadTradesById(tradeIds) {
  const ids = [...new Set(tradeIds.filter(Boolean))];
  if (!ids.length) return new Map();
  const rows = await new Parse.Query('Trade')
    .containedIn('objectId', ids)
    .limit(ids.length)
    .find({ useMasterKey: true });
  return new Map(rows.map((t) => [t.id, t]));
}

async function loadParticipationsByPoolTradeIds(poolTradeIds) {
  const ids = [...new Set(poolTradeIds.filter(Boolean))];
  if (!ids.length) return new Map();

  const pq = new Parse.Query('PoolTradeParticipation');
  pq.containedIn('tradeId', ids);
  pq.limit(5000);
  const parts = await pq.find({ useMasterKey: true });

  const byTrade = new Map();
  const investmentIds = new Set();
  for (const p of parts) {
    const tid = p.get('tradeId');
    if (!tid) continue;
    if (!byTrade.has(tid)) byTrade.set(tid, []);
    byTrade.get(tid).push(p);
    const iid = p.get('investmentId');
    if (iid) investmentIds.add(iid);
  }

  const investmentById = new Map();
  if (investmentIds.size > 0) {
    const invRows = await new Parse.Query('Investment')
      .containedIn('objectId', Array.from(investmentIds))
      .limit(investmentIds.size)
      .find({ useMasterKey: true });
    for (const inv of invRows) investmentById.set(inv.id, inv);
  }

  const userIds = new Set();
  for (const inv of investmentById.values()) {
    const uid = inv.get('investorId');
    if (uid) userIds.add(uid);
  }
  const userById = new Map();
  if (userIds.size > 0) {
    const users = await new Parse.Query(Parse.User)
      .containedIn('objectId', Array.from(userIds))
      .limit(userIds.size)
      .find({ useMasterKey: true });
    for (const u of users) userById.set(u.id, u);
  }

  const enrichedByTrade = new Map();
  for (const [tid, partList] of byTrade) {
    enrichedByTrade.set(
      tid,
      partList.map((p) => mapParticipationRow(p, investmentById, userById)),
    );
  }
  return enrichedByTrade;
}

function mapParticipationRow(participation, investmentById, userById) {
  const investmentId = participation.get('investmentId') || '';
  const inv = investmentId ? investmentById.get(investmentId) : null;
  let investorId = participation.get('investorId') || inv?.get('investorId') || '';
  let investorEmail = '';
  let investorName = participation.get('investorName') || '';

  if (investorId && userById.has(investorId)) {
    const u = userById.get(investorId);
    investorEmail = u.get('email') || '';
    if (!investorName) {
      investorName = u.get('firstName')
        ? `${u.get('firstName')} ${u.get('lastName') || ''}`.trim()
        : investorEmail;
    }
  }
  if (investorEmail && investorEmail.startsWith('user:')) {
    investorEmail = investorEmail.replace('user:', '');
  }
  if (investorId && String(investorId).startsWith('user:')) {
    investorId = String(investorId).replace('user:', '');
  }

  const rawOwnership = Number(participation.get('ownershipPercentage') || 0);
  const ownershipPercentage = rawOwnership > 1 ? rawOwnership : rawOwnership * 100;
  const investmentStatus = String(inv?.get('status') || '').toLowerCase();
  const investmentCapital = round2(inv?.get('currentValue') || inv?.get('amount') || 0);

  return {
    investmentId,
    investmentNumber: inv?.get('investmentNumber') || '',
    investorId,
    investorName: investorName || investorEmail || '—',
    investorEmail,
    ownershipPercentage: round2(ownershipPercentage),
    investmentStatus,
    investmentCapital,
    allocatedAmount: round2(participation.get('allocatedAmount') || participation.get('investedAmount') || 0),
    profitShare: round2(participation.get('profitShare') || 0),
    commissionAmount: round2(participation.get('commissionAmount') || 0),
    isSettled: Boolean(participation.get('isSettled')),
  };
}

/**
 * Attach pool mirror trade + participations for Summary Report trades tab.
 */
async function enrichSummaryReportTrades(tradeRows, baseItems) {
  const config = await loadConfig();
  const feeConfig = config.financial || {};
  const snapshotOptions = { feeConfig };

  const contexts = await resolvePairedLegContextsByTradeId(tradeRows);

  const extraTradeIds = new Set();
  for (const ctx of contexts.values()) {
    if (ctx.mirrorTradeId && !tradeRows.some((t) => t.id === ctx.mirrorTradeId)) {
      extraTradeIds.add(ctx.mirrorTradeId);
    }
    if (ctx.traderTradeId && !tradeRows.some((t) => t.id === ctx.traderTradeId)) {
      extraTradeIds.add(ctx.traderTradeId);
    }
  }

  const linkedTrades = await loadTradesById(Array.from(extraTradeIds));
  const tradeById = new Map(tradeRows.map((t) => [t.id, t]));
  for (const [id, t] of linkedTrades) tradeById.set(id, t);

  const poolTradeIds = new Set();
  for (const ctx of contexts.values()) {
    if (ctx.poolTradeId) poolTradeIds.add(ctx.poolTradeId);
    if (ctx.mirrorTradeId) poolTradeIds.add(ctx.mirrorTradeId);
  }
  for (const t of tradeRows) poolTradeIds.add(t.id);
  const participationsByPool = await loadParticipationsByPoolTradeIds([...poolTradeIds]);

  const draftItems = baseItems.map((item, idx) => {
    const trade = tradeRows[idx];
    const ctx = contexts.get(trade.id) || {
      legKind: 'standalone',
      poolTradeId: trade.id,
      traderTradeId: trade.id,
      mirrorTradeId: null,
      pairExecutionId: null,
    };

    let resolved = resolveTraderAndPoolObjects(trade, ctx, tradeById);
    const { poolTradeId: effectivePoolId, participations } = resolvePoolParticipationsForRow(
      trade,
      ctx,
      participationsByPool,
    );
    resolved = applyPoolMirrorFromParticipations({
      tradeRow: trade,
      legKind: resolved.legKind,
      traderTrade: resolved.traderTrade,
      poolMirrorTrade: resolved.poolMirrorTrade,
      poolTradeId: effectivePoolId,
      participations,
      tradeById,
      feeConfig,
    });

    if (resolved.poolMirrorTrade?.tradeId === trade.id) {
      resolved.legKind = 'mirror_pool';
      if (!resolved.traderTrade) resolved.traderTrade = null;
    } else     if (!resolved.traderTrade) {
      resolved.traderTrade = tradeEconomicsSnapshot(trade, null, snapshotOptions);
    } else if (resolved.legKind === 'trader' && resolved.traderTrade.tradeId !== trade.id) {
      resolved.traderTrade = tradeEconomicsSnapshot(trade, null, snapshotOptions);
    }

    const investorIdsFromPool = [
      ...new Set(participations.map((p) => p.investorId).filter(Boolean)),
    ];

    return {
      ...item,
      investorIds: investorIdsFromPool.length > 0 ? investorIdsFromPool : item.investorIds,
      legKind: resolved.legKind,
      pairExecutionId: ctx.pairExecutionId,
      poolTradeId: resolved.poolTradeId,
      traderTrade: resolved.traderTrade,
      poolMirrorTrade: resolved.poolMirrorTrade,
      linkedTraderTrade: resolved.legKind === 'mirror_pool' ? resolved.traderTrade : null,
      poolParticipations: participations,
      poolExecutionBelege: null,
      hasPoolDetails: Boolean(resolved.poolMirrorTrade || participations.length > 0),
    };
  });

  const tradeIdsForBelege = collectTradeIdsFromDraftRows(draftItems);
  const docsByTradeId = await loadDocumentsByTradeIds(tradeIdsForBelege);

  const withBelege = attachBelegeToSummaryRows(draftItems, docsByTradeId);

  return withBelege.map((row) => {
    const costBasis =
      row.poolMirrorTrade?.costBasisPerShare
      || row.traderTrade?.costBasisPerShare
      || 0;
    const poolParticipations = enrichParticipationDisplayFields(
      row.poolParticipations || [],
      costBasis,
    );
    return { ...row, poolParticipations };
  });
}

function enrichParticipationDisplayFields(participations, costBasisPerShare) {
  if (!participations.length) return participations;
  const basis = Number(costBasisPerShare || 0);
  if (!(basis > 0)) return participations;
  return participations.map((p) => {
    const capital = Number(p.investmentCapital || 0);
    const pieces = capital > 0 ? Math.floor(capital / basis) : 0;
    const activeAtBasis = round2(pieces * basis);
    const residual = round2(Math.max(0, capital - activeAtBasis));
    return {
      ...p,
      poolPieces: pieces,
      activeInvestmentAtBid: activeAtBasis,
      investmentResidual: residual,
    };
  });
}

/**
 * Fallback when buyOrder batch misses mirror (legacy rows): per-trader-leg lookup.
 */
async function ensureMirrorLinkForTraderRows(enrichedItems, tradeRows) {
  const config = await loadConfig();
  const feeConfig = config.financial || {};
  const snapshotOptions = { feeConfig };

  const out = [...enrichedItems];
  for (let i = 0; i < tradeRows.length; i += 1) {
    if (out[i].poolMirrorTrade) continue;
    if (out[i].legKind !== 'trader' && out[i].legKind !== 'standalone') continue;
    const mirror = await getMirrorTradeForPairedTraderLeg(tradeRows[i]);
    if (!mirror || mirror.id === tradeRows[i].id) continue;
    const parts = await loadParticipationsByPoolTradeIds([mirror.id]);
    const traderSnap =
      out[i].traderTrade || tradeEconomicsSnapshot(tradeRows[i], null, snapshotOptions);
    const snap = tradeEconomicsSnapshot(mirror, parts.get(mirror.id) || [], {
      traderReference: traderSnap,
      applyPoolMirror: true,
      feeConfig,
    });
    const docsByTradeId = await loadDocumentsByTradeIds([mirror.id, tradeRows[i].id]);
    const [withBelege] = attachBelegeToSummaryRows(
      [{
        ...out[i],
        legKind: 'trader',
        poolTradeId: mirror.id,
        traderTrade: out[i].traderTrade || tradeEconomicsSnapshot(tradeRows[i]),
        poolMirrorTrade: snap,
        linkedTraderTrade: out[i].traderTrade || tradeEconomicsSnapshot(tradeRows[i]),
        poolParticipations: parts.get(mirror.id) || out[i].poolParticipations,
      }],
      docsByTradeId,
    );
    out[i] = { ...withBelege, hasPoolDetails: true };
  }
  return out;
}

async function ensureTraderLinkForPoolRows(enrichedItems, tradeRows) {
  const out = [...enrichedItems];
  for (let i = 0; i < tradeRows.length; i += 1) {
    if (out[i].traderTrade) continue;
    if (!out[i].poolMirrorTrade) continue;
    const trader = await getTraderTradeForPairedMirrorLeg(tradeRows[i]);
    if (!trader) continue;
    const traderSnap = tradeEconomicsSnapshot(trader);
    out[i] = {
      ...out[i],
      legKind: 'mirror_pool',
      traderTrade: traderSnap,
      linkedTraderTrade: traderSnap,
    };
  }
  return out;
}

module.exports = {
  enrichSummaryReportTrades,
  ensureMirrorLinkForTraderRows,
  ensureTraderLinkForPoolRows,
  tradeEconomicsSnapshot,
  resolvePairedLegContextsByTradeId,
};
