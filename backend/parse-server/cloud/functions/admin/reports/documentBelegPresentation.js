'use strict';

const { round2 } = require('../../../utils/accountingHelper/shared');
const {
  formatTradeNumberForDisplay,
  getTradeNumberCalendarYear,
} = require('../../../utils/tradeNumberAllocation');
const {
  traderCollectionBillDisplaySections,
  formatTraderCollectionBillSummaryText,
} = require('../../../utils/accountingHelper/traderCollectionBillBelegSnapshot');
const {
  poolMirrorExecutionDisplaySections,
} = require('../../../utils/accountingHelper/poolMirrorExecutionEigenbelegSnapshot');

function formatEuroDe(amount) {
  const n = round2(Math.abs(Number(amount) || 0));
  return new Intl.NumberFormat('de-DE', { style: 'currency', currency: 'EUR' }).format(n);
}

function formatEuroDeSigned(amount) {
  const n = round2(Number(amount) || 0);
  const abs = formatEuroDe(Math.abs(n));
  return n < 0 ? `-${abs}` : abs;
}

function pushSection(sections, title, rows) {
  const filtered = rows.filter((r) => r.value != null && String(r.value).trim() !== '');
  if (filtered.length) sections.push({ title, rows: filtered });
}

function formatFeesBlock(fees) {
  if (!fees || typeof fees !== 'object') return '—';
  const parts = [];
  for (const [k, label] of [
    ['orderFee', 'Ordergebühr'],
    ['exchangeFee', 'Handelsplatzgebühr'],
    ['foreignCosts', 'Fremdkostenpauschale'],
    ['totalFees', 'Gebühren gesamt'],
  ]) {
    const v = round2(Number(fees[k]) || 0);
    if (v > 0) parts.push(`${label}: ${formatEuroDe(v)}`);
  }
  return parts.length ? parts.join('\n') : '—';
}

function formatLegBlock(leg, side) {
  if (!leg || typeof leg !== 'object') return [];
  const rows = [];
  const qty = Number(leg.quantity || 0);
  const price = Number(leg.price || 0);
  const amount = round2(Number(leg.amount) || 0);
  if (qty > 0) rows.push({ label: 'Stück', value: String(qty) });
  if (price > 0) rows.push({ label: 'Kurs (nominell)', value: formatEuroDe(price) });
  if (amount > 0) rows.push({ label: 'Volumen (netto Brutto)', value: formatEuroDe(amount) });
  if (leg.costBasisPerShare > 0) {
    rows.push({ label: 'Einstand / Stück', value: formatEuroDe(leg.costBasisPerShare) });
  }
  if (leg.netSellPricePerShare > 0) {
    rows.push({ label: 'Verkauf netto / Stück', value: formatEuroDe(leg.netSellPricePerShare) });
  }
  const fees = formatFeesBlock(leg.fees);
  if (fees !== '—') rows.push({ label: 'Gebühren', value: fees });
  if (leg.residualAmount > 0) {
    rows.push({ label: 'Residual', value: formatEuroDe(leg.residualAmount) });
  }
  return rows;
}

function formatPartyRow(label, userId, partyDisplayName) {
  const uid = String(userId || '').trim();
  if (!uid) return { label, value: '—' };
  const name = String(partyDisplayName || '').trim();
  return { label, value: name ? `${name} · ${uid}` : uid };
}

function parseTradeNumberYearFromDocumentName(name) {
  const match = String(name || '').match(/Trade(\d{4})-(\d{3})/);
  return match ? Number(match[1]) : null;
}

function adminTradeRefLabel(doc, tradeNumberYear = null) {
  const num = doc.get('tradeNumber');
  if (num == null || num === '') {
    return doc.get('tradeId') ? String(doc.get('tradeId')) : '—';
  }
  const year = tradeNumberYear
    ?? parseTradeNumberYearFromDocumentName(doc.get('name'))
    ?? getTradeNumberCalendarYear(doc.get('createdAt') || new Date());
  const formatted = formatTradeNumberForDisplay(num, year);
  return formatted ? `#${formatted}` : `#${num}`;
}

function buildInvestorCollectionBillSections(meta, doc, enrichment = {}) {
  const sections = [];
  pushSection(sections, 'Beleg', [
    { label: 'Belegnummer', value: doc.get('accountingDocumentNumber') || '—' },
    { label: 'Trade', value: adminTradeRefLabel(doc) },
    { label: 'Investment', value: String(doc.get('investmentId') || '—') },
    formatPartyRow('Investor (User-ID)', doc.get('userId'), enrichment.partyDisplayName),
  ]);
  pushSection(sections, 'Summen (GoB)', [
    { label: 'Investment-Nominal', value: formatEuroDe(meta.investmentNominal) },
    { label: 'Gesamtkaufkosten', value: formatEuroDe(meta.totalBuyCost) },
    { label: 'Residual', value: formatEuroDe(meta.residualAmount) },
    { label: 'Netto-Verkauf', value: formatEuroDe(meta.netSellAmount) },
    { label: 'Bruttogewinn', value: formatEuroDe(meta.grossProfit) },
    { label: 'Provision', value: formatEuroDe(meta.commission) },
    { label: 'Nettogewinn', value: formatEuroDe(meta.netProfit) },
    { label: 'Überweisungsbetrag', value: formatEuroDe(meta.transferAmount) },
    {
      label: 'Rendite',
      value: typeof meta.returnPercentage === 'number'
        ? `${meta.returnPercentage.toFixed(2)} %`
        : '—',
    },
  ]);
  pushSection(sections, 'Kauf (buyLeg)', formatLegBlock(meta.buyLeg, 'buy'));
  pushSection(sections, 'Verkauf (sellLeg)', formatLegBlock(meta.sellLeg, 'sell'));
  if (meta.taxBreakdown && Number(meta.taxBreakdown.totalTax) > 0) {
    pushSection(sections, 'Steuer', [
      { label: 'Quellensteuer gesamt', value: formatEuroDe(meta.taxBreakdown.totalTax) },
    ]);
  }
  return sections;
}

function buildTraderExecutionSections(meta, doc, enrichment = {}) {
  return traderCollectionBillDisplaySections(meta, doc, enrichment);
}

function traderSummaryFromMetadata(meta, doc) {
  if (!meta || !Number(meta.amount)) return null;
  return formatTraderCollectionBillSummaryText({
    label: meta.belegLabel || 'Trade-Abrechnung',
    docNumber: doc.get('accountingDocumentNumber') || '',
    tradeNumber: doc.get('tradeNumber') || meta.tradeNumber || '',
    metadata: meta,
  });
}

function buildAppCommissionEigenbelegSections(meta, doc) {
  const sections = [];
  const konten = meta.buchungskonten || {};
  pushSection(sections, 'Eigenbeleg — Erfolgsprovision Plattform', [
    { label: 'Belegnummer', value: doc.get('accountingDocumentNumber') || '—' },
    { label: 'Trade', value: adminTradeRefLabel(doc) },
    { label: 'Erfolgsprovision', value: formatEuroDe(meta.appCommissionAmount ?? meta.betrag) },
    {
      label: 'Provisionssatz (Plattform)',
      value: typeof meta.appCommissionRateSnapshot === 'number'
        ? `${(meta.appCommissionRateSnapshot * 100).toFixed(2)} %`
        : '—',
    },
    {
      label: 'Bruttogewinn-Basis',
      value: typeof meta.grossProfitBasis === 'number'
        ? formatEuroDe(meta.grossProfitBasis)
        : '—',
    },
  ]);
  if (konten.soll && konten.haben) {
    pushSection(sections, 'Buchungskonten (SKR03)', [
      {
        label: 'Soll',
        value: `${konten.soll.skr03} ${konten.soll.ledgerId} — ${konten.soll.bezeichnung}`,
      },
      {
        label: 'Haben',
        value: `${konten.haben.skr03} ${konten.haben.ledgerId} — ${konten.haben.bezeichnung}`,
      },
      { label: 'Buchungssatz', value: konten.buchungssatzBeschreibung || '—' },
    ]);
  }
  return sections;
}

function buildTraderCreditNoteSections(meta, doc, enrichment = {}) {
  const sections = [];
  const traderName = enrichment.partyDisplayName || meta.traderDisplayName;
  pushSection(sections, 'Gutschrift (Provision)', [
    { label: 'Belegnummer', value: doc.get('accountingDocumentNumber') || '—' },
    formatPartyRow('Trader (User-ID)', doc.get('userId') || meta.traderId, traderName),
    { label: 'Trade', value: adminTradeRefLabel(doc) },
    { label: 'Bruttogewinn (Basis)', value: formatEuroDe(meta.grossProfit) },
    { label: 'Provision gesamt', value: formatEuroDe(meta.commissionAmount) },
    { label: 'Netto', value: formatEuroDe(meta.netProfit) },
    {
      label: 'Provisionssatz',
      value: typeof meta.commissionRate === 'number'
        ? `${(meta.commissionRate * 100).toFixed(0)} %`
        : '—',
    },
  ]);
  const breakdown = Array.isArray(meta.investorBreakdown) ? meta.investorBreakdown : [];
  if (meta.investorBreakdownTruncated) {
    pushSection(sections, 'Investor-Aufschlüsselung', [
      {
        label: 'Investoren gesamt',
        value: String(meta.investorCount || breakdown.length || '—'),
      },
      {
        label: 'Hinweis',
        value: 'Detail-Aufschlüsselung paginiert im Admin Summary Report (Pool-Mirror-Trade Investoren).',
      },
    ]);
  } else if (breakdown.length) {
    pushSection(
      sections,
      'Investor-Aufschlüsselung',
      breakdown.map((b, i) => ({
        label: `Investor ${i + 1}`,
        value: [
          b.investorId && `ID: ${b.investorId}`,
          `Gewinn ${formatEuroDe(b.grossProfit)}`,
          `Prov. ${formatEuroDe(b.commission)}`,
        ].filter(Boolean).join(' · '),
      })),
    );
  }
  return sections;
}

function buildInvoiceSections(meta, doc) {
  const sections = [];
  pushSection(sections, 'Rechnung', [
    { label: 'Belegnummer', value: doc.get('accountingDocumentNumber') || doc.get('documentNumber') || '—' },
    { label: 'Rechnungsart', value: meta.invoiceType || '—' },
    { label: 'Netto', value: formatEuroDe(meta.netAmount ?? meta.subtotal) },
    { label: 'MwSt.', value: formatEuroDe(meta.vatAmount ?? meta.taxAmount) },
    { label: 'Gesamt', value: formatEuroDe(meta.totalAmount) },
    { label: 'Investment', value: meta.investmentId || '—' },
    { label: 'Batch', value: meta.batchId || '—' },
  ]);
  return sections;
}

function buildBelegDisplaySections(doc, metadataOverride, enrichment = {}) {
  const type = String(doc.get('type') || '');
  const meta = metadataOverride ?? doc.get('metadata') ?? {};
  if (type === 'investorCollectionBill' || type === 'investor_collection_bill') {
    return buildInvestorCollectionBillSections(meta, doc, enrichment);
  }
  if (type === 'traderCollectionBill' || type === 'trade_execution_document') {
    return buildTraderExecutionSections(meta, doc, enrichment);
  }
  if (type === 'traderCreditNote') return buildTraderCreditNoteSections(meta, doc, enrichment);
  if (type === 'appCommissionEigenbeleg' || type === 'appCommissionInternalEigenbeleg') {
    return buildAppCommissionEigenbelegSections(meta, doc);
  }
  if (type === 'invoice') return buildInvoiceSections(meta, doc);
  if (Object.keys(meta).length > 0) {
    return [{
      title: 'Metadaten',
      rows: Object.entries(meta).slice(0, 24).map(([k, v]) => ({
        label: k,
        value: typeof v === 'object' ? JSON.stringify(v) : String(v),
      })),
    }];
  }
  return [];
}

function sectionsToSummaryText(sections) {
  return sections
    .map((sec) => {
      const lines = sec.rows.map((r) => `${r.label}: ${r.value}`);
      return `${sec.title}\n${lines.join('\n')}`;
    })
    .join('\n\n');
}

function projectDocumentDetail(doc, metadataOverride, enrichment = {}) {
  const meta = metadataOverride ?? doc.get('metadata') ?? {};
  const stored = String(doc.get('accountingSummaryText') || '').trim();
  const displaySections = buildBelegDisplaySections(doc, meta, enrichment);
  const type = String(doc.get('type') || '');
  const isTraderBill = type === 'traderCollectionBill' || type === 'trade_execution_document';
  const isPoolMirrorEigen = type === 'poolMirrorExecutionEigenbeleg';
  const summaryFromSnapshot = isTraderBill ? traderSummaryFromMetadata(meta, doc) : null;
  const computedSections = sectionsToSummaryText(displaySections);
  const computed = summaryFromSnapshot || computedSections;
  const preferComputed = metadataOverride && !stored && computed && !isPoolMirrorEigen;
  const displaySummary = (isPoolMirrorEigen && stored) || (stored && !preferComputed)
    ? stored
    : (computed || null);
  return {
    metadata: meta,
    displaySections,
    accountingSummaryText: displaySummary,
    summarySource: stored && !preferComputed
      ? 'stored'
      : (summaryFromSnapshot ? 'snapshot' : (computedSections ? 'computed' : 'none')),
  };
}

module.exports = {
  projectDocumentDetail,
  buildBelegDisplaySections,
  buildTraderExecutionSections,
  formatEuroDe,
  formatEuroDeSigned,
};
