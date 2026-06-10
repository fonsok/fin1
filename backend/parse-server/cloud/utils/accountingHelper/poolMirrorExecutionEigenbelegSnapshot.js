'use strict';

/**
 * GoB: Interner Eigenbeleg für Pool-Mirror-Trade (MIRROR_POOL).
 * SSOT für Admin „Kaufabrechnung (Pool-Mirror)“ — nicht Trader-TBC umbenennen.
 */

const { round2 } = require('./shared');

const POOL_MIRROR_EIGENBELEG_SCHEMA_VERSION = 1;

function formatEuroDe(amount) {
  const n = round2(Math.abs(Number(amount) || 0));
  return new Intl.NumberFormat('de-DE', { style: 'currency', currency: 'EUR' }).format(n);
}

function formatPct(fraction) {
  const p = round2(Number(fraction || 0) * 100);
  return `${p.toFixed(1)} %`;
}

function executionLabel(executionType) {
  return String(executionType).toLowerCase() === 'sell'
    ? 'Verkaufsabrechnung (Pool-Mirror)'
    : 'Kaufabrechnung (Pool-Mirror)';
}

/**
 * @param {object} input
 * @param {'buy'|'sell'} input.executionType
 * @param {object} input.poolSnap — Pool-Mirror economics (summary-report shape)
 * @param {object} input.traderSnap — Trader-Leg reference (optional)
 * @param {string} input.docNumber
 * @param {string} [input.linkedTraderDocumentNumber]
 */
function buildPoolMirrorExecutionEigenbelegSnapshot(input) {
  const executionType = String(input.executionType || 'buy').toLowerCase();
  const pool = input.poolSnap || {};
  const trader = input.traderSnap || {};
  const docNumber = String(input.docNumber || '').trim();
  const label = executionLabel(executionType);

  const metadata = {
    belegSchemaVersion: POOL_MIRROR_EIGENBELEG_SCHEMA_VERSION,
    belegKind: 'pool_mirror_execution',
    executionType,
    label,
    tradeId: pool.tradeId,
    tradeNumber: pool.tradeNumber,
    symbol: pool.symbol,
    wknOrIsin: pool.wknOrIsin,
    underlyingAsset: pool.underlyingAsset,
    optionDirection: pool.optionDirection,
    poolReservedCapitalTotal: round2(pool.poolReservedCapitalTotal),
    poolCapitalAllocated: round2(pool.poolCapitalAllocated),
    poolResidualTotal: round2(pool.poolResidualTotal),
    poolInvestorCount: Number(pool.poolInvestorCount) || 0,
    impliedBuyQuantityFromPool: pool.impliedBuyQuantityFromPool,
    poolSoldQuantityDerived: round2(pool.poolSoldQuantityDerived),
    poolSellAmountDerived: round2(pool.poolSellAmountDerived),
    poolSellVolumeProgress: pool.poolSellVolumeProgress,
    costBasisPerShare: round2(pool.costBasisPerShare),
    bidPricePerShare: round2(pool.bidPricePerShare ?? pool.buyPrice),
    buyFeesTotal: round2(pool.buyFeesTotal),
    totalBuyCost: round2(pool.totalBuyCost ?? pool.buyAmount),
    linkedTraderTradeId: trader.tradeId || null,
    linkedTraderTradeNumber: trader.tradeNumber || null,
    linkedTraderDocumentNumber: input.linkedTraderDocumentNumber || null,
    sellOrderId: input.sellOrderId || null,
    traderBuyQuantity: round2(trader.buyQuantity),
    traderSoldQuantity: round2(trader.soldQuantity),
  };

  const accountingSummaryText = formatPoolMirrorExecutionSummaryText({
    label,
    docNumber,
    metadata,
    pool,
    trader,
  });

  return { metadata, accountingSummaryText };
}

function formatPoolMirrorExecutionSummaryText({
  label,
  docNumber,
  metadata,
  pool,
  trader,
}) {
  const lines = [
    label,
    `Belegnummer ${docNumber}`,
    `Pool-Mirror-Trade #${String(pool.tradeNumber || '').padStart(3, '0')} · Mirror-ID ${pool.tradeId || '—'}`,
    '',
    '1. Zweck (intern, GoB)',
    'Eigenbeleg für die gebündelte Pool-Abbildung (MIRROR_POOL) — nicht identisch mit der '
    + 'Trader-Kaufabrechnung (TBC/TSC). Sichtbar nur im Admin-Portal.',
    '',
    '2. Instrument',
    [
      pool.symbol && `Symbol: ${pool.symbol}`,
      pool.wknOrIsin && `WKN/ISIN: ${pool.wknOrIsin}`,
      pool.underlyingAsset && `Basiswert: ${pool.underlyingAsset}`,
      pool.optionDirection && `Richtung: ${pool.optionDirection}`,
    ].filter(Boolean).join('\n') || '—',
    '',
    '3. Pool-Kapital (∑ aktive Investments)',
    `Reserved (∑ Investments): ${formatEuroDe(metadata.poolReservedCapitalTotal)}`,
    `Pool-Einlage (Σ Stück × Einstand): ${formatEuroDe(metadata.poolCapitalAllocated)}`,
    `Residual (Reserved − aktiv @ Einstand): ${formatEuroDe(metadata.poolResidualTotal)}`,
    `Investoren (aktiv): ${metadata.poolInvestorCount}`,
    `Stück (Pool, abgerundet): ${metadata.impliedBuyQuantityFromPool ?? '—'}`,
    `Einstand / Bezug (pro Stück): ${formatEuroDe(metadata.costBasisPerShare)}`,
    `Bid (nominell / Stück): ${formatEuroDe(metadata.bidPricePerShare)}`,
    `Σ Gebühren (Kauf, Trader-Leg): ${formatEuroDe(metadata.buyFeesTotal)}`,
    '',
    '4. Verkaufs-Fortschritt (abgeleitet vom Trader-Leg)',
    `Verkauft (Stück, Pool): ${metadata.poolSoldQuantityDerived}`,
    `Verkaufsvolumen (netto, Pool): ${formatEuroDe(metadata.poolSellAmountDerived)}`,
    `Verkaufs-Fortschritt: ${formatPct(metadata.poolSellVolumeProgress)}`,
    '',
    '5. Referenz Trader-Leg (Ausführung beim Trader)',
    trader.tradeId
      ? `Trade #${String(trader.tradeNumber || '').padStart(3, '0')} · ${trader.tradeId}`
      : '—',
    metadata.linkedTraderDocumentNumber
      ? `Trader-Beleg: ${metadata.linkedTraderDocumentNumber}`
      : 'Trader-Beleg: (noch nicht verknüpft)',
    metadata.sellOrderId ? `Verkaufsorder: ${metadata.sellOrderId}` : '',
    trader.buyQuantity
      ? `Trader Kauf (Stück): ${trader.buyQuantity} · Trader Verkauft: ${trader.soldQuantity ?? 0}`
      : '',
    '',
    '6. Status',
    `Pool-Mirror-Status: ${pool.status || '—'}`,
  ].filter((line) => line !== '');

  if (String(metadata.executionType) === 'sell') {
    lines.push('', '7. Hinweis Verkauf', 'Teilverkäufe auf dem Pool werden über Investor-Collection-Bills abgebildet; '
      + 'dieser Eigenbeleg dokumentiert die Pool-Spiegelung der Trader-Verkaufsbewegung.');
  }

  return lines.join('\n');
}

function poolMirrorExecutionDisplaySections(meta, doc) {
  const rows = (pairs) => pairs
    .filter(([, v]) => v != null && String(v).trim() !== '')
    .map(([label, value]) => ({ label, value: String(value) }));

  return [
    {
      title: 'Pool-Mirror (intern)',
      rows: rows([
        ['Belegnummer', doc.get('accountingDocumentNumber')],
        ['Ausführung', meta.executionType === 'sell' ? 'Verkauf' : 'Kauf'],
        ['Trade', meta.tradeNumber ? `#${meta.tradeNumber}` : doc.get('tradeId')],
        ['Investoren (aktiv)', meta.poolInvestorCount],
        ['Reserved', formatEuroDe(meta.poolReservedCapitalTotal)],
        ['Pool-Einlage', formatEuroDe(meta.poolCapitalAllocated)],
        ['Residual', formatEuroDe(meta.poolResidualTotal)],
        ['Stück (Pool)', meta.impliedBuyQuantityFromPool],
        ['Einstand / Stück', formatEuroDe(meta.costBasisPerShare)],
      ]),
    },
    {
      title: 'Trader-Referenz',
      rows: rows([
        ['Trader-Beleg', meta.linkedTraderDocumentNumber],
        ['Trader-Trade', meta.linkedTraderTradeNumber ? `#${meta.linkedTraderTradeNumber}` : meta.linkedTraderTradeId],
      ]),
    },
  ].filter((s) => s.rows.length > 0);
}

function isUsablePoolMirrorEigenbelegSummary(text) {
  const t = String(text || '').trim();
  return t.includes('Pool-Mirror') && (t.includes('Reserved') || t.includes('Pool-Einlage'));
}

module.exports = {
  POOL_MIRROR_EIGENBELEG_SCHEMA_VERSION,
  buildPoolMirrorExecutionEigenbelegSnapshot,
  formatPoolMirrorExecutionSummaryText,
  poolMirrorExecutionDisplaySections,
  isUsablePoolMirrorEigenbelegSummary,
};
