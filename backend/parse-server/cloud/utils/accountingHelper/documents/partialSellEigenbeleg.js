'use strict';

const { generateSequentialNumber } = require('../../helpers');
const { round2, formatDateCompact, generateShortHash } = require('../shared');
const { applyBusinessCaseIdToDocument, formatEuroDe, formatDateTimeDe } = require('./shared');
const { resolveTradeNumberPresentation } = require('../../tradeNumberAllocation');

const PARTIAL_SELL_KONTO_PTR = {
  skr03: '1592',
  ledgerId: 'CLT-LIAB-PTR',
  bezeichnung: 'Kundenguthaben – PoolTrade (Stückkauf)',
};
const PARTIAL_SELL_KONTO_PPS = {
  skr03: '1593',
  ledgerId: 'CLT-LIAB-PPS',
  bezeichnung: 'Kundenguthaben – Teilverkauf Pool-Trade (ausstehend)',
};
const PARTIAL_SELL_KONTO_PNL = {
  skr03: '8900',
  ledgerId: 'CLT-EQT-INV-PNL',
  bezeichnung: 'Investor-Erfolg (Teilverkauf, intern)',
};

/**
 * ADR-015: Interner Buchungsbeleg pro Investor-Partial-Sell (kein Kunden-Collection-Bill).
 * Idempotent pro investmentId + tradeId + sellOrderId.
 */
async function createPartialSellInternalBeleg({
  investorId,
  investmentId,
  investmentNumber,
  trade,
  sellOrderId,
  poolCapitalReleased,
  sellLeg,
  grossProfit,
  netProfit,
  commission,
  businessCaseId,
}) {
  const tradeId = trade?.id;
  const sellKey = String(sellOrderId || '').trim();
  if (!investorId || !investmentId || !tradeId || !sellKey) return null;

  const amount = round2(Math.abs(Number(poolCapitalReleased) || 0));
  const grossProfitAmt = round2(Math.max(0, Number(grossProfit) || 0));
  const netProfitAmt = round2(Number(netProfit) || 0);
  const commissionAmt = round2(Math.max(0, Number(commission) || 0));
  if (amount <= 0) return null;

  const dup = new Parse.Query('Document');
  dup.equalTo('investmentId', investmentId);
  dup.equalTo('tradeId', tradeId);
  dup.equalTo('type', 'investorPartialSellInternal');
  dup.equalTo('source', 'backend');
  dup.equalTo('metadata.sellOrderId', sellKey);
  const existing = await dup.first({ useMasterKey: true });
  if (existing) return existing;

  const tradePresentation = resolveTradeNumberPresentation(trade);
  const tradeNumber = tradePresentation.tradeNumber;
  const symbol = trade.get('symbol') || '';
  const docNumber = await generateSequentialNumber('EBP', 'Document', 'accountingDocumentNumber');
  const dateStr = formatDateCompact(new Date());
  const hash = generateShortHash();
  const belegDatum = new Date();
  const sellQty = sellLeg?.quantity ?? null;
  const sellPrice = sellLeg?.price ?? null;
  const ppsPendingTotal = round2(amount + grossProfitAmt);

  const accountingSummaryText = [
    `Eigenbeleg ${docNumber} — Teilverkauf Pool-Trade (intern)`,
    '',
    `Trade ${tradePresentation.label || `#${tradeNumber}`} (${symbol}), Investment ${investmentNumber || investmentId}`,
    `Verkaufte Pool-Stück (Investor-Anteil): ${sellQty != null ? sellQty : '—'}`,
    sellPrice != null ? `Verkaufspreis: ${formatEuroDe(sellPrice)}` : '',
    `Freigegebenes Pool-Kapital (Einstand): ${formatEuroDe(amount)}`,
    grossProfitAmt > 0 ? `Brutto-Gewinn (Partial-Sell-Scheibe): ${formatEuroDe(grossProfitAmt)}` : '',
    grossProfitAmt > 0 && commissionAmt > 0
      ? `Provision (erst bei Trade-Ende): ${formatEuroDe(commissionAmt)}`
      : '',
    grossProfitAmt > 0 ? `Netto-Gewinn (nach Provision, bei Trade-Ende): ${formatEuroDe(netProfitAmt)}` : '',
    ppsPendingTotal > amount ? `Σ 1593 ausstehend (Einstand + Brutto-Gewinn): ${formatEuroDe(ppsPendingTotal)}` : '',
    '',
    'Buchungssatz 1 (Einstand):',
    `${PARTIAL_SELL_KONTO_PTR.skr03} ${PARTIAL_SELL_KONTO_PTR.ledgerId} (Soll) ${formatEuroDe(amount)}`,
    `→ ${PARTIAL_SELL_KONTO_PPS.skr03} ${PARTIAL_SELL_KONTO_PPS.ledgerId} (Haben) ${formatEuroDe(amount)}`,
    'Leg: partialSellRelease (investmentEscrow).',
    ...(grossProfitAmt > 0
      ? [
        '',
        'Buchungssatz 2 (Gewinnrealisierung, intern):',
        `${PARTIAL_SELL_KONTO_PNL.skr03} ${PARTIAL_SELL_KONTO_PNL.ledgerId} (Soll) ${formatEuroDe(grossProfitAmt)}`,
        `→ ${PARTIAL_SELL_KONTO_PPS.skr03} ${PARTIAL_SELL_KONTO_PPS.ledgerId} (Haben) ${formatEuroDe(grossProfitAmt)}`,
        'Leg: partialSellProfitRecognition (investmentEscrow).',
      ]
      : []),
    'Keine Kundenauszahlung / keine Provision vor Trade-Ende (Collection Bill).',
    '',
    `Belegdatum: ${formatDateTimeDe(belegDatum)}`,
  ].filter(Boolean).join('\n');

  const Document = Parse.Object.extend('Document');
  const doc = new Document();
  doc.set('userId', investorId);
  doc.set('type', 'investorPartialSellInternal');
  doc.set('name', `Eigenbeleg_PartialSell_${investmentNumber || investmentId}_Trade${tradePresentation.filenameToken}_${dateStr}_${hash}.pdf`);
  doc.set('investmentId', investmentId);
  doc.set('tradeId', tradeId);
  doc.set('tradeNumber', tradeNumber);
  doc.set('accountingDocumentNumber', docNumber);
  doc.set('documentNumber', docNumber);
  doc.set('source', 'backend');
  doc.set('status', 'verified');
  doc.set('fileURL', `eigenbeleg-partial-sell://${docNumber}.pdf`);
  doc.set('accountingSummaryText', accountingSummaryText);
  doc.set('size', Buffer.byteLength(accountingSummaryText, 'utf8'));
  doc.set('metadata', {
    eigenbelegArt: 'interner_buchungsbeleg',
    belegTitel: 'Eigenbeleg — Teilverkauf Pool-Trade (Investor, intern)',
    executionType: 'investor_partial_sell',
    sellOrderId: sellKey,
    datumIso: belegDatum.toISOString(),
    betrag: amount,
    betragTextDe: formatEuroDe(amount),
    poolCapitalReleased: amount,
    ppsPendingTotal: ppsPendingTotal > 0 ? ppsPendingTotal : null,
    grossProfit: grossProfitAmt > 0 ? grossProfitAmt : null,
    netProfit: grossProfitAmt > 0 ? netProfitAmt : null,
    commissionDeferred: commissionAmt > 0 ? commissionAmt : null,
    buchungskonten: {
      einstand: {
        soll: PARTIAL_SELL_KONTO_PTR,
        haben: PARTIAL_SELL_KONTO_PPS,
        leg: 'partialSellRelease',
        betrag: amount,
      },
      ...(grossProfitAmt > 0
        ? {
          gewinn: {
            soll: PARTIAL_SELL_KONTO_PNL,
            haben: PARTIAL_SELL_KONTO_PPS,
            leg: 'partialSellProfitRecognition',
            betrag: grossProfitAmt,
          },
        }
        : {}),
    },
    investment: {
      objectId: investmentId,
      investmentNumber: investmentNumber || null,
    },
    sellLeg: sellLeg || null,
    generatedAt: belegDatum.toISOString(),
  });

  applyBusinessCaseIdToDocument(doc, businessCaseId || trade.get('businessCaseId'));
  await doc.save(null, { useMasterKey: true });
  console.log(
    `📄 Eigenbeleg Partial-Sell: ${docNumber} Investment ${investmentId}, Trade #${tradeNumber}, €${amount}`,
  );
  return doc;
}

module.exports = {
  createPartialSellInternalBeleg,
};
