'use strict';

const { generateSequentialNumber } = require('../../helpers');
const { round2, formatDateCompact, generateShortHash } = require('../shared');
const { applyBusinessCaseIdToDocument, formatEuroDe, formatDateTimeDe } = require('./shared');

const RESERVATION_EIGENBELEG_VERMERK =
  'Reservierung für ggf. auszuführenden Wertpapierkauf (interne Veranlassung; '
  + 'kein externer Lieferanten- oder Bankbeleg).';
const RESERVATION_EIGENBELEG_ZWECK =
  'Sicherstellung des Investitionsbetrags bis zur Bestätigung bzw. Ausführung; '
  + 'Buchung: Kundenguthaben verfügbar → reserviert.';
const RESERVATION_EIGENBELEG_FOLGEHINWEIS =
  'Bei Ausführung des Wertpapierkaufs ist der Kauf- bzw. Abrechnungsbeleg der Bank '
  + 'oder des Brokers dem Vorgang nachzureichen (Anschaffungs-/Veräußerungsnachweis).';

/** SKR03 / interne Kontokennungen — konsistent mit App-Ledger (siehe Admin-Ansicht). */
const RESERVATION_KONTO_AVA = {
  skr03: '1590',
  ledgerId: 'CLT-LIAB-AVA',
  bezeichnung: 'Kundenguthaben – verfügbar (Teilverbindlichkeit)',
};
const RESERVATION_KONTO_RSV = {
  skr03: '1591',
  ledgerId: 'CLT-LIAB-RSV',
  bezeichnung: 'Kundenguthaben – für Investments reserviert (Teilverbindlichkeit)',
};

const GRUND_KEIN_ORIGINALBELEG =
  'Es liegt kein externes Originalbeleg (z. B. Bank- oder Brokerbeleg) vor, weil es sich um eine '
  + 'interne Verbuchung der Plattform handelt: Sicherstellung des vom Investor gewählten Betrags '
  + 'auf den internen Konten „verfügbar“ und „reserviert“ bis zur weiteren Verarbeitung '
  + '(Bestätigung / Zuordnung zum Handel). Dieser Eigenbeleg dient als plausibler und '
  + 'vollständiger Buchungsnachweis gemäß den Grundsätzen ordnungsgemäßer Buchführung (GoB).';

/**
 * Mehrzeiliger Klartext für App/Export (Feld `accountingSummaryText` am Document).
 */
function buildInvestmentReservationEigenbelegAccountingSummary({
  docNumber,
  amount,
  belegDatum,
  investorName,
  investorId,
  investmentNumber,
  investmentObjectId,
  traderName,
  traderId,
}) {
  const betrag = formatEuroDe(amount);
  const anlass = investmentNumber
    ? `Reservierung des Kundenguthabens für die Investition ${investmentNumber} (Parse-Investment ${investmentObjectId}).`
    : `Reservierung des Kundenguthabens für Investment ${investmentObjectId}.`;
  const traderZeile = traderName || traderId
    ? `Zugeordneter Trader-Pool: ${[traderName, traderId].filter(Boolean).join(' · ')}.`
    : '';

  const lines = [
    `Eigenbeleg ${docNumber}`,
    '',
    '1. Anlass / Geschäftsvorfall',
    anlass,
    traderZeile,
    '',
    '2. Betrag und Währung',
    `${betrag} (EUR)`,
    '',
    '3. Belegdatum / Buchungszeitpunkt (System)',
    formatDateTimeDe(belegDatum),
    '',
    '4. Ausführende / betroffene Partei (Investor)',
    [investorName && `Name: ${investorName}`, investorId && `Kunden-/User-ID: ${investorId}`]
      .filter(Boolean)
      .join('\n') || '(keine Namensangabe)',
    '',
    '5. Buchungsstellen (intern, SKR03) — „Empfänger“ der internen Umbuchung',
    `Soll (Belastung): ${RESERVATION_KONTO_AVA.skr03} ${RESERVATION_KONTO_AVA.ledgerId} — ${RESERVATION_KONTO_AVA.bezeichnung}`,
    `Haben (Gutschrift): ${RESERVATION_KONTO_RSV.skr03} ${RESERVATION_KONTO_RSV.ledgerId} — ${RESERVATION_KONTO_RSV.bezeichnung}`,
    'Buchungssatz: Kundenguthaben verfügbar → reserviert (App-Ledger, transactionType investmentEscrow, leg=reserve).',
    '',
    '6. Grund, warum kein Originalbeleg vorliegt',
    GRUND_KEIN_ORIGINALBELEG,
    '',
    '7. Hinweis zur Nachreichung',
    RESERVATION_EIGENBELEG_FOLGEHINWEIS,
  ];
  return lines.join('\n');
}

/**
 * GoB: vor Aufruf von `investmentEscrow.bookReserve` / `savePair` ausführen
 * (persistierter Beleg vor App-Ledger-Buchung).
 */
async function createInvestmentReservationEigenbelegDocument(investment) {
  if (!investment || typeof investment.get !== 'function' || !investment.id) {
    return null;
  }
  const investmentId = investment.id;
  const dup = new Parse.Query('Document');
  dup.equalTo('investmentId', investmentId);
  dup.equalTo('type', 'investmentReservationEigenbeleg');
  dup.equalTo('source', 'backend');
  const existing = await dup.first({ useMasterKey: true });
  if (existing) {
    return existing;
  }

  const investorId = String(investment.get('investorId') || '').trim();
  const amount = round2(Math.abs(Number(investment.get('amount')) || 0));
  if (!investorId || amount <= 0) {
    return null;
  }

  const docNumber = await generateSequentialNumber('EBR', 'Document', 'accountingDocumentNumber');
  const dateStr = formatDateCompact(new Date());
  const hash = generateShortHash();

  const investorName = String(investment.get('investorName') || '').trim();
  const investorEmail = String(investment.get('investorEmail') || '').trim();
  const investmentNumber = String(investment.get('investmentNumber') || '').trim();
  const batchId = String(investment.get('batchId') || '').trim();
  const traderId = String(investment.get('traderId') || '').trim();
  const traderName = String(investment.get('traderName') || '').trim();
  const belegDatum = new Date();

  const accountingSummaryText = buildInvestmentReservationEigenbelegAccountingSummary({
    docNumber,
    amount,
    belegDatum,
    investorName,
    investorId,
    investmentNumber,
    investmentObjectId: investmentId,
    traderName,
    traderId,
  });

  const Document = Parse.Object.extend('Document');
  const doc = new Document();
  doc.set('userId', investorId);
  doc.set('type', 'investmentReservationEigenbeleg');
  doc.set('name', `Eigenbeleg_Reservierung_${investmentNumber || investmentId}_${dateStr}_${hash}.pdf`);
  doc.set('investmentId', investmentId);
  doc.set('accountingDocumentNumber', docNumber);
  doc.set('documentNumber', docNumber);
  doc.set('source', 'backend');
  doc.set('status', 'verified');
  doc.set('fileURL', `eigenbeleg-reservierung://${docNumber}.pdf`);
  doc.set('accountingSummaryText', accountingSummaryText);
  doc.set('size', Buffer.byteLength(accountingSummaryText, 'utf8'));
  doc.set('metadata', {
    eigenbelegArt: 'interner_buchungsbeleg',
    belegTitel: 'Eigenbeleg — Reservierung Kundenguthaben (Investment-Split)',
    datumIso: belegDatum.toISOString(),
    belegdatumTextDe: formatDateTimeDe(belegDatum),
    betrag: amount,
    betragTextDe: formatEuroDe(amount),
    waehrung: 'EUR',
    anlassKurz: investmentNumber
      ? `Reservierung für Investition ${investmentNumber} beim Trader ${traderName || traderId || '—'}`
      : `Reservierung Kundenguthaben (Investment ${investmentId})`,
    anlassAusfuehrlich: accountingSummaryText,
    kunde: {
      userId: investorId,
      name: investorName,
      email: investorEmail,
    },
    vermerk: RESERVATION_EIGENBELEG_VERMERK,
    zweck: RESERVATION_EIGENBELEG_ZWECK,
    grundOhneOriginalbeleg: GRUND_KEIN_ORIGINALBELEG,
    buchungskonten: {
      soll: RESERVATION_KONTO_AVA,
      haben: RESERVATION_KONTO_RSV,
      buchungssatzBeschreibung:
        'Kundenguthaben verfügbar → reserviert (App-Ledger / investmentEscrow, leg=reserve)',
    },
    investment: {
      objectId: investmentId,
      investmentNumber: investmentNumber || null,
      batchId: batchId || null,
      traderId: traderId || null,
      traderName: traderName || null,
    },
    folgehinweisNachreichung: RESERVATION_EIGENBELEG_FOLGEHINWEIS,
    generatedAt: new Date().toISOString(),
  });

  applyBusinessCaseIdToDocument(doc, investment.get('businessCaseId'));

  await doc.save(null, { useMasterKey: true });
  console.log(`📄 Eigenbeleg Reservierung: ${docNumber} Investment ${investmentId}, €${amount}`);
  return doc;
}

module.exports = {
  createInvestmentReservationEigenbelegDocument,
};
