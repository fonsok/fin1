'use strict';

const { generateSequentialNumber } = require('../../helpers');
const { round2, formatDateCompact, generateShortHash } = require('../shared');
const { applyBusinessCaseIdToDocument, formatEuroDe, formatDateTimeDe } = require('./shared');

const DOC_TYPE = 'appCommissionEigenbeleg';
/** @deprecated Renamed from appCommissionInternalEigenbeleg; kept for idempotency lookup only. */
const LEGACY_DOC_TYPE = 'appCommissionInternalEigenbeleg';

const KONTO_LIAB_COM = {
  skr03: '1700',
  ledgerId: 'PLT-LIAB-COM',
  bezeichnung: 'Trader-Verbindlichkeit aus Provision (Clearing)',
};
const KONTO_REV_COM = {
  skr03: '8400',
  ledgerId: 'PLT-REV-COM',
  bezeichnung: 'Provisionserlös (Erfolgsprovision Plattform)',
};

const GRUND_KEIN_ORIGINALBELEG =
  'Es liegt kein externes Originalbeleg vor, weil die Erfolgsprovision der Plattform intern '
  + 'aus dem abgeschlossenen Trade-Settlement abgeleitet wird (Anteil am Investoren-Gewinn). '
  + 'Dieser Eigenbeleg dokumentiert die Umbuchung vom Provisions-Clearing auf den '
  + 'Provisionserlös gemäß den Grundsätzen ordnungsgemäßer Buchführung (GoB).';

function buildAppCommissionEigenbelegAccountingSummary({
  docNumber,
  amount,
  belegDatum,
  tradeNumber,
  tradeId,
  traderId,
  appCommissionRate,
  grossProfitBasis,
}) {
  const ratePct = Number.isFinite(appCommissionRate)
    ? `${(appCommissionRate * 100).toFixed(2).replace(/\.?0+$/, '')} %`
    : '—';
  const lines = [
    `Eigenbeleg ${docNumber}`,
    '',
    '1. Anlass / Geschäftsvorfall',
    `Erfolgsprovision der Plattform aus Trade #${tradeNumber || tradeId || '—'} (interne Ertragsrealisierung).`,
    '',
    '2. Betrag und Währung',
    `${formatEuroDe(amount)} (EUR)`,
    '',
    '3. Belegdatum / Buchungszeitpunkt (System)',
    formatDateTimeDe(belegDatum),
    '',
    '4. Bezug',
    `Trade-ID: ${tradeId || '—'}`,
    traderId ? `Trader-ID: ${traderId}` : '',
    typeof grossProfitBasis === 'number' && grossProfitBasis > 0
      ? `Bruttogewinn-Basis (Investoren-Spiegel): ${formatEuroDe(grossProfitBasis)}`
      : '',
    `Erfolgsprovisionssatz (Plattform): ${ratePct}`,
    '',
    '5. Buchungsstellen (intern, SKR03)',
    `Soll: ${KONTO_LIAB_COM.skr03} ${KONTO_LIAB_COM.ledgerId} — ${KONTO_LIAB_COM.bezeichnung}`,
    `Haben: ${KONTO_REV_COM.skr03} ${KONTO_REV_COM.ledgerId} — ${KONTO_REV_COM.bezeichnung}`,
    'Buchungssatz: Provisions-Clearing → Provisionserlös (App-Ledger, transactionType appCommission, leg=app_commission).',
    '',
    '6. Grund, warum kein Originalbeleg vorliegt',
    GRUND_KEIN_ORIGINALBELEG,
  ];
  return lines.filter((line) => line !== '').join('\n');
}

/**
 * GoB: Eigenbeleg vor App-Ledger-Buchung der Plattform-Erfolgsprovision.
 * Idempotent pro tradeId.
 */
async function createAppCommissionEigenbeleg({
  trade,
  traderId,
  totalAppCommission,
  appCommissionRate,
  grossProfitBasis,
  businessCaseId,
}) {
  const tradeId = trade?.id;
  const amount = round2(Math.abs(Number(totalAppCommission) || 0));
  if (!tradeId || amount <= 0) return null;

  const dup = new Parse.Query('Document');
  dup.equalTo('tradeId', tradeId);
  dup.containedIn('type', [DOC_TYPE, LEGACY_DOC_TYPE]);
  dup.equalTo('source', 'backend');
  const existing = await dup.first({ useMasterKey: true });
  if (existing) return existing;

  const tradeNumber = trade.get?.('tradeNumber') ?? trade.tradeNumber ?? '';
  const symbol = trade.get?.('symbol') ?? trade.symbol ?? '';
  const ownerId = String(traderId || trade.get?.('traderId') || '').trim();
  const docNumber = await generateSequentialNumber('EAP', 'Document', 'accountingDocumentNumber');
  const dateStr = formatDateCompact(new Date());
  const hash = generateShortHash();
  const belegDatum = new Date();
  const rate = Number.isFinite(appCommissionRate) ? appCommissionRate : null;
  const grossBasis = Number.isFinite(grossProfitBasis) ? round2(grossProfitBasis) : null;

  const accountingSummaryText = buildAppCommissionEigenbelegAccountingSummary({
    docNumber,
    amount,
    belegDatum,
    tradeNumber,
    tradeId,
    traderId: ownerId,
    appCommissionRate: rate,
    grossProfitBasis: grossBasis,
  });

  const Document = Parse.Object.extend('Document');
  const doc = new Document();
  doc.set('userId', ownerId || 'platform');
  doc.set('type', DOC_TYPE);
  doc.set('name', `Eigenbeleg_AppProvision_Trade${tradeNumber || tradeId}_${dateStr}_${hash}.pdf`);
  doc.set('tradeId', tradeId);
  doc.set('tradeNumber', tradeNumber);
  doc.set('accountingDocumentNumber', docNumber);
  doc.set('documentNumber', docNumber);
  doc.set('source', 'backend');
  doc.set('status', 'verified');
  doc.set('fileURL', `eigenbeleg-app-provision://${docNumber}.pdf`);
  doc.set('accountingSummaryText', accountingSummaryText);
  doc.set('size', Buffer.byteLength(accountingSummaryText, 'utf8'));
  doc.set('metadata', {
    eigenbelegArt: 'interner_buchungsbeleg',
    belegTitel: 'Eigenbeleg — Erfolgsprovision Plattform',
    executionType: 'app_commission_revenue',
    datumIso: belegDatum.toISOString(),
    belegdatumTextDe: formatDateTimeDe(belegDatum),
    betrag: amount,
    betragTextDe: formatEuroDe(amount),
    waehrung: 'EUR',
    appCommissionAmount: amount,
    appCommissionRateSnapshot: rate,
    grossProfitBasis: grossBasis,
    symbol: symbol || null,
    traderId: ownerId || null,
    buchungskonten: {
      soll: KONTO_LIAB_COM,
      haben: KONTO_REV_COM,
      buchungssatzBeschreibung:
        'Provisions-Clearing → Provisionserlös (leg=app_commission, transactionType=appCommission)',
    },
    grundOhneOriginalbeleg: GRUND_KEIN_ORIGINALBELEG,
    generatedAt: belegDatum.toISOString(),
  });

  applyBusinessCaseIdToDocument(doc, businessCaseId || trade.get?.('businessCaseId'));
  await doc.save(null, { useMasterKey: true });
  console.log(
    `📄 Eigenbeleg App-Provision: ${docNumber} Trade #${tradeNumber || tradeId}, €${amount}`,
  );
  return doc;
}

module.exports = {
  DOC_TYPE,
  LEGACY_DOC_TYPE,
  createAppCommissionEigenbeleg,
  buildAppCommissionEigenbelegAccountingSummary,
};
