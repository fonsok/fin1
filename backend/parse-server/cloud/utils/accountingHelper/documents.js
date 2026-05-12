'use strict';

const { isServiceChargeInvoiceType } = require('../serviceChargeInvoiceTypes');
const { generateSequentialNumber } = require('../helpers');
const { round2, formatDateCompact, generateShortHash } = require('./shared');

function applyBusinessCaseIdToDocument(doc, businessCaseId) {
  const bc = String(businessCaseId || '').trim();
  if (!bc) return;
  doc.set('businessCaseId', bc);
  const meta = doc.get('metadata') || {};
  doc.set('metadata', Object.assign({}, meta, { businessCaseId: bc }));
}

function computeCollectionBillReturnPercentage({ netProfit, buyLeg, investmentCapital }) {
  const buyLegAmount = buyLeg?.amount || 0;
  const buyLegFees = buyLeg?.fees?.totalFees || 0;
  const investedAmountFromLeg = buyLegAmount + buyLegFees;
  const investedAmount = investedAmountFromLeg > 0
    ? investedAmountFromLeg
    : (typeof investmentCapital === 'number' && investmentCapital > 0 ? investmentCapital : 0);

  if (investedAmount <= 0) {
    return null;
  }
  return round2((netProfit / investedAmount) * 100);
}

function assertCollectionBillReturnPercentageInvariant(returnPercentage, context = {}) {
  if (typeof returnPercentage === 'number' && Number.isFinite(returnPercentage)) {
    return;
  }

  const details = {
    tradeId: context.tradeId || null,
    investmentId: context.investmentId || null,
    netProfit: context.netProfit ?? null,
    investmentCapital: context.investmentCapital ?? null,
  };
  throw new Error(
    `Invariant violation: investor collection bill missing canonical returnPercentage (${JSON.stringify(details)})`,
  );
}

async function createCreditNoteDocument({
  traderId,
  trade,
  totalCommission,
  commissionRate,
  grossProfit,
  netProfit,
  investorBreakdown,
  taxBreakdown,
  businessCaseId,
}) {
  const tradeNumber = trade.get('tradeNumber');
  const docNumber = await generateSequentialNumber('CN', 'Document', 'accountingDocumentNumber');
  const dateStr = formatDateCompact(new Date());
  const hash = generateShortHash();

  const Document = Parse.Object.extend('Document');
  const doc = new Document();
  doc.set('userId', traderId);
  doc.set('type', 'traderCreditNote');
  doc.set('name', `CreditNote_Trade${tradeNumber}_${dateStr}_${hash}.pdf`);
  doc.set('tradeId', trade.id);
  doc.set('tradeNumber', tradeNumber);
  doc.set('accountingDocumentNumber', docNumber);
  doc.set('source', 'backend');
  doc.set('metadata', {
    commissionAmount: round2(totalCommission),
    commissionRate,
    grossProfit: round2(grossProfit),
    netProfit: round2(netProfit),
    investorBreakdown: investorBreakdown.map((b) => ({
      investorId: b.investorId,
      investmentId: b.investmentId,
      grossProfit: round2(b.grossProfit),
      commission: round2(b.commission),
      taxWithheld: round2(b.taxWithheld || 0),
    })),
    taxBreakdown: taxBreakdown || null,
    generatedAt: new Date().toISOString(),
  });
  doc.set('traderCommissionRateSnapshot', commissionRate);

  applyBusinessCaseIdToDocument(doc, businessCaseId || trade.get('businessCaseId'));

  await doc.save(null, { useMasterKey: true });
  console.log(`📄 CreditNote created: ${docNumber} for trade #${tradeNumber}, commission €${round2(totalCommission)}`);
  return doc;
}

async function createCollectionBillDocument({
  investorId,
  investmentId,
  trade,
  ownershipPercentage,
  grossProfit,
  commission,
  netProfit,
  commissionRate,
  investmentCapital,
  buyLeg,
  sellLeg,
  taxBreakdown,
  businessCaseId,
}) {
  const tradeNumber = trade.get('tradeNumber');
  const docNumber = await generateSequentialNumber('CB', 'Document', 'accountingDocumentNumber');
  const dateStr = formatDateCompact(new Date());
  const hash = generateShortHash();

  const returnPercentage = computeCollectionBillReturnPercentage({
    netProfit,
    buyLeg,
    investmentCapital,
  });
  assertCollectionBillReturnPercentageInvariant(returnPercentage, {
    tradeId: trade?.id,
    investmentId,
    netProfit,
    investmentCapital,
  });

  const Document = Parse.Object.extend('Document');
  const doc = new Document();
  doc.set('userId', investorId);
  doc.set('type', 'investorCollectionBill');
  doc.set('name', `CollectionBill_Investment${investmentId}_${dateStr}_${hash}.pdf`);
  doc.set('investmentId', investmentId);
  doc.set('tradeId', trade.id);
  doc.set('tradeNumber', tradeNumber);
  doc.set('accountingDocumentNumber', docNumber);
  doc.set('source', 'backend');
  doc.set('metadata', {
    ownershipPercentage: round2(ownershipPercentage),
    grossProfit: round2(grossProfit),
    commission: round2(commission),
    netProfit: round2(netProfit),
    returnPercentage,
    commissionRate,
    buyLeg: buyLeg || null,
    sellLeg: sellLeg || null,
    taxBreakdown: taxBreakdown || null,
    generatedAt: new Date().toISOString(),
  });

  applyBusinessCaseIdToDocument(
    doc,
    businessCaseId || trade.get('businessCaseId'),
  );

  await doc.save(null, { useMasterKey: true });
  console.log(`📄 CollectionBill created: ${docNumber} for investor ${investorId}, investment ${investmentId}`);
  return doc;
}

// ============================================================================
// GoB Eigenbeleg — Reservierung Split-Investment (Kundenguthaben AVA → RSV)
// Kein externer Bank-/Broker-Beleg; interner Buchungsbeleg als Nachweis bis
// zur Ausführung (dann Bank-/Broker-Abrechnung nachreichen).
// ============================================================================

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

function formatEuroDe(amount) {
  const n = round2(Math.abs(Number(amount) || 0));
  return new Intl.NumberFormat('de-DE', { style: 'currency', currency: 'EUR' }).format(n);
}

function formatDateTimeDe(d) {
  try {
    return new Intl.DateTimeFormat('de-DE', {
      dateStyle: 'long',
      timeStyle: 'short',
    }).format(d instanceof Date ? d : new Date(d));
  } catch {
    return String(d);
  }
}

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

// ============================================================================
// GoB-compliant receipt for wallet transactions (Keine Buchung ohne Beleg)
// Covers: deposit, withdrawal, investment_activate, investment_return, refund
// ============================================================================

async function createWalletReceiptDocument({
  userId,
  receiptType,
  amount,
  description,
  referenceType,
  referenceId,
  metadata: extraMeta,
  businessCaseId,
}) {
  const typeToDocType = {
    deposit: 'financial',
    withdrawal: 'financial',
    investment: 'financial',
    investment_return: 'financial',
    refund: 'financial',
  };

  const typeToPrefix = {
    deposit: 'WDR',
    withdrawal: 'WWR',
    investment: 'IAR',
    investment_return: 'IRR',
    refund: 'IFR',
  };

  const docType = typeToDocType[receiptType] || `wallet_${receiptType}_receipt`;
  const prefix = typeToPrefix[receiptType] || 'WRC';

  const docNumber = await generateSequentialNumber(prefix, 'Document', 'accountingDocumentNumber');
  const dateStr = formatDateCompact(new Date());
  const hash = generateShortHash();

  const Document = Parse.Object.extend('Document');
  const doc = new Document();
  doc.set('userId', userId);
  doc.set('type', docType);
  doc.set('name', `${docType}_${dateStr}_${hash}.pdf`);
  doc.set('accountingDocumentNumber', docNumber);
  doc.set('source', 'backend');
  if (referenceType) doc.set('referenceType', referenceType);
  if (referenceId) doc.set('referenceId', referenceId);
  if (referenceType === 'Investment' && referenceId) {
    doc.set('investmentId', referenceId);
  }
  doc.set('metadata', {
    amount: round2(Math.abs(amount)),
    description,
    receiptType,
    ...extraMeta,
    generatedAt: new Date().toISOString(),
  });

  applyBusinessCaseIdToDocument(doc, businessCaseId);

  await doc.save(null, { useMasterKey: true });
  console.log(`📄 WalletReceipt created: ${docNumber} (${docType}) for user ${userId}, €${round2(Math.abs(amount))}`);
  return doc;
}

// ============================================================================
// GoB-compliant trade execution documents (Kaufabrechnung / Verkaufsabrechnung)
// Every trade_buy, trade_sell, and trading_fees booking needs its own Beleg.
// ============================================================================

async function createTradeExecutionDocument({
  traderId,
  trade,
  executionType,
  amount,
  order,
  businessCaseId,
}) {
  const tradeNumber = trade.get('tradeNumber');
  const symbol = trade.get('symbol') || '';

  const typeToDocType = {
    buy: 'traderCollectionBill',
    sell: 'traderCollectionBill',
    fees: 'invoice',
  };

  const typeToPrefix = {
    buy: 'TBC',
    sell: 'TSC',
    fees: 'TFS',
  };

  const typeToLabel = {
    buy: 'Kaufabrechnung',
    sell: 'Verkaufsabrechnung',
    fees: 'Gebührenabrechnung',
  };

  const docType = typeToDocType[executionType] || 'trade_execution_document';
  const prefix = typeToPrefix[executionType] || 'TED';
  const label = typeToLabel[executionType] || 'Trade Execution';

  const docNumber = await generateSequentialNumber(prefix, 'Document', 'accountingDocumentNumber');
  const dateStr = formatDateCompact(new Date());
  const hash = generateShortHash();

  const Document = Parse.Object.extend('Document');
  const doc = new Document();
  doc.set('userId', traderId);
  doc.set('type', docType);
  doc.set('name', `${label}_Trade${tradeNumber}_${symbol}_${dateStr}_${hash}.pdf`);
  doc.set('tradeId', trade.id);
  doc.set('tradeNumber', tradeNumber);
  doc.set('accountingDocumentNumber', docNumber);
  doc.set('source', 'backend');
  doc.set('metadata', {
    executionType,
    symbol,
    amount: round2(Math.abs(amount)),
    quantity: order?.quantity || null,
    price: order?.price || null,
    orderId: order?.id || null,
    wkn: order?.wkn || symbol,
    generatedAt: new Date().toISOString(),
  });

  applyBusinessCaseIdToDocument(doc, businessCaseId || trade.get('businessCaseId'));

  await doc.save(null, { useMasterKey: true });
  console.log(`📄 ${label} created: ${docNumber} for trade #${tradeNumber} (${symbol}), €${round2(Math.abs(amount))}`);
  return doc;
}

/**
 * GoB / Admin: one Parse `Document` per service-/app-service-charge invoice,
 * using the same `accountingDocumentNumber` as `Invoice.invoiceNumber`
 * so AppLedger `referenceDocumentId` resolves without number-only heuristics.
 *
 * Runs after the `Invoice` row exists (afterSave path); companion `Document` is
 * not in the same DB transaction as the invoice — idempotent create + stable
 * keys avoid duplicate Belege if the trigger retries.
 */
async function ensureServiceChargeInvoiceDocument(invoice) {
  const invoiceType = String(invoice.get('invoiceType') || '');
  if (!isServiceChargeInvoiceType(invoiceType)) {
    return null;
  }
  const invoiceNumber = String(invoice.get('invoiceNumber') || '').trim();
  if (!invoiceNumber || !invoice.id) {
    return null;
  }
  const userId = String(invoice.get('userId') || invoice.get('customerId') || '').trim();
  if (!userId) {
    return null;
  }

  const Document = Parse.Object.extend('Document');
  const bySource = new Parse.Query(Document);
  bySource.equalTo('metadata.sourceInvoiceId', invoice.id);
  const byNumber = new Parse.Query(Document);
  byNumber.equalTo('accountingDocumentNumber', invoiceNumber);
  byNumber.equalTo('userId', userId);
  const combined = Parse.Query.or(bySource, byNumber);
  combined.limit(5);
  const candidates = await combined.find({ useMasterKey: true });

  let doc = null;
  if (candidates.length > 0) {
    doc = candidates.find((d) => String((d.get('metadata') || {}).sourceInvoiceId || '') === invoice.id)
      || candidates.find((d) => String(d.get('accountingDocumentNumber') || '').trim() === invoiceNumber)
      || candidates[0];
  }
  if (doc) {
    const m = doc.get('metadata') || {};
    if (!m.sourceInvoiceId) {
      doc.set('metadata', Object.assign({}, m, { sourceInvoiceId: invoice.id }));
      await doc.save(null, { useMasterKey: true });
    }
    return doc;
  }

  const batchId = String(invoice.get('batchId') || '').trim();
  const investmentId = String(invoice.get('investmentId') || '').trim();
  const netAmount = round2(Number(invoice.get('subtotal')) || 0);
  const vatAmount = round2(Number(invoice.get('taxAmount')) || 0);
  const totalRaw = Number(invoice.get('totalAmount'));
  const totalAmount = Number.isFinite(totalRaw) && totalRaw > 0
    ? round2(totalRaw)
    : round2(netAmount + vatAmount);
  const belegDatum = invoice.get('createdAt') || new Date();
  const dateStr = formatDateCompact(belegDatum);
  const hash = generateShortHash();

  const accountingSummaryText = [
    `App-Service-Rechnung ${invoiceNumber}`,
    `Kunde: ${userId}`,
    batchId ? `Batch: ${batchId}` : null,
    `Rechnungsart: ${invoiceType}`,
    `Netto: ${formatEuroDe(netAmount)}`,
    `USt: ${formatEuroDe(vatAmount)}`,
    `Brutto: ${formatEuroDe(totalAmount)}`,
    `Belegdatum: ${formatDateTimeDe(belegDatum)}`,
    `Parse Invoice objectId: ${invoice.id}`,
  ].filter(Boolean).join('\n');

  const newDoc = new Document();
  newDoc.set('userId', userId);
  newDoc.set('type', 'invoice');
  newDoc.set('name', `Invoice_${invoiceNumber}_${dateStr}_${hash}.pdf`);
  newDoc.set('accountingDocumentNumber', invoiceNumber);
  newDoc.set('documentNumber', invoiceNumber);
  newDoc.set('source', 'backend');
  newDoc.set('status', 'verified');
  newDoc.set('fileURL', `invoice-beleg://${invoiceNumber}.pdf`);
  newDoc.set('accountingSummaryText', accountingSummaryText);
  newDoc.set('size', Buffer.byteLength(accountingSummaryText, 'utf8'));
  newDoc.set('metadata', {
    sourceInvoiceId: invoice.id,
    invoiceType,
    batchId: batchId || null,
    invoiceNumber,
    netAmount,
    vatAmount,
    totalAmount,
    generatedAt: new Date().toISOString(),
    adrRef: 'ADR-007',
  });
  if (investmentId) {
    newDoc.set('investmentId', investmentId);
  }

  applyBusinessCaseIdToDocument(newDoc, invoice.get('businessCaseId'));

  await newDoc.save(null, { useMasterKey: true });
  console.log(`📄 Service-charge invoice document: ${invoiceNumber} (invoice ${invoice.id})`);
  return newDoc;
}

async function resolveDocumentRefsFromInvoiceIfOwned(invoice, expectedUserId, expectedGross) {
  const uid = String(expectedUserId || '').trim();
  const invUser = String(invoice.get('userId') || invoice.get('customerId') || '').trim();
  if (!uid || invUser !== uid) {
    return {};
  }
  const invType = String(invoice.get('invoiceType') || '');
  if (!isServiceChargeInvoiceType(invType)) {
    return {};
  }
  const totalRaw = Number(invoice.get('totalAmount'));
  const sub = round2(Number(invoice.get('subtotal')) || 0);
  const tax = round2(Number(invoice.get('taxAmount')) || 0);
  const total = Number.isFinite(totalRaw) && totalRaw > 0
    ? round2(totalRaw)
    : round2(sub + tax);
  const expected = round2(Number(expectedGross));
  if (!Number.isFinite(expected) || expected <= 0 || total !== expected) {
    return {};
  }
  const doc = await ensureServiceChargeInvoiceDocument(invoice);
  const refId = doc && doc.id ? String(doc.id).trim() : '';
  const refNo = String(invoice.get('invoiceNumber') || '').trim();
  return {
    ...(refId ? { referenceDocumentId: refId } : {}),
    ...(refNo ? { referenceDocumentNumber: refNo } : {}),
  };
}

function buildDocRefsFromLedgerRow(row) {
  const meta = row.get('metadata') || {};
  let refId = String(meta.referenceDocumentId || '').trim();
  let refNo = String(meta.referenceDocumentNumber || meta.invoiceNumber || '').trim();
  const invId = String(meta.invoiceId || '').trim();
  return { refId, refNo, invId, meta };
}

async function finalizeLedgerDocRefs(refId, refNo, invId) {
  const rid = String(refId || '').trim();
  const rno = String(refNo || '').trim();
  if (rid && rno) {
    return { referenceDocumentId: rid, referenceDocumentNumber: rno };
  }
  let outId = rid;
  let outNo = rno;
  if (!outId && invId) {
    try {
      const Invoice = Parse.Object.extend('Invoice');
      const inv = await new Parse.Query(Invoice).get(invId, { useMasterKey: true });
      const ensured = await ensureServiceChargeInvoiceDocument(inv);
      if (ensured && ensured.id) {
        outId = String(ensured.id).trim();
      }
      if (!outNo) {
        outNo = String(inv.get('invoiceNumber') || '').trim();
      }
    } catch (_) {
      // leave refs empty
    }
  }
  if (outId || outNo) {
    return {
      ...(outId ? { referenceDocumentId: outId } : {}),
      ...(outNo ? { referenceDocumentNumber: outNo } : {}),
    };
  }
  return {};
}

async function findDocRefsFromLiabilityRows(rows, gross) {
  for (const row of rows) {
    const { refId, refNo, invId, meta } = buildDocRefsFromLedgerRow(row);
    const rowAmount = round2(Number(row.get('amount')) || 0);
    const metaGross = round2(parseFloat(String(meta.grossAmount ?? '')));
    const grossOk = (Number.isFinite(metaGross) && metaGross === gross)
      || (rowAmount === gross);
    if (!grossOk) {
      continue;
    }
    const finalized = await finalizeLedgerDocRefs(refId, refNo, invId);
    if (Object.keys(finalized).length > 0) {
      return finalized;
    }
  }
  return {};
}

async function fetchChargeLiabilityRows(userId, {
  referenceId,
  amount,
  limit,
} = {}) {
  const hasAmount = Number.isFinite(amount) && amount > 0;
  const defaultLimit = referenceId && hasAmount ? 5 : (hasAmount ? 12 : 20);
  const lim = Math.min(Math.max(Number(limit) || defaultLimit, 1), 30);

  const AppLedgerEntry = Parse.Object.extend('AppLedgerEntry');
  const q = new Parse.Query(AppLedgerEntry);
  q.equalTo('userId', userId);
  q.equalTo('transactionType', 'appServiceCharge');
  q.equalTo('account', 'CLT-LIAB-AVA');
  q.equalTo('side', 'debit');
  if (referenceId) {
    q.equalTo('referenceId', referenceId);
  }
  if (hasAmount) {
    q.equalTo('amount', round2(amount));
  }
  q.descending('createdAt');
  q.limit(lim);
  return q.find({ useMasterKey: true });
}

/**
 * For 4-eyes fee_refund: resolve Beleg refs. Priority:
 * 1) explicit `invoiceId` (must belong to userId and match gross),
 * 2) `batchId` + same gross on CLT-LIAB-AVA (`amount` + `referenceId`),
 * 3) gross-only on recent CLT-LIAB-AVA rows — only when no `batchId` was given
 *    (avoids matching another batch with the same gross). New requests should
 *    include `invoiceId` or `batchId` (enforced in createCorrectionRequest).
 *
 * @param {string} userId
 * @param {number} grossRefundAmount
 * @param {{ invoiceId?: string, batchId?: string }} [options]
 */
async function resolveDocumentRefForFeeRefund(userId, grossRefundAmount, options = {}) {
  const uid = String(userId || '').trim();
  const gross = round2(Number(grossRefundAmount));
  if (!uid || !Number.isFinite(gross) || gross <= 0) {
    return {};
  }

  const invoiceIdOpt = String(options.invoiceId || '').trim();
  const batchIdOpt = String(options.batchId || '').trim();

  if (invoiceIdOpt) {
    try {
      const Invoice = Parse.Object.extend('Invoice');
      const inv = await new Parse.Query(Invoice).get(invoiceIdOpt, { useMasterKey: true });
      const fromInv = await resolveDocumentRefsFromInvoiceIfOwned(inv, uid, gross);
      if (Object.keys(fromInv).length > 0) {
        return fromInv;
      }
    } catch (_) {
      // fall through to ledger paths
    }
  }

  if (batchIdOpt) {
    const batchRows = await fetchChargeLiabilityRows(uid, {
      referenceId: batchIdOpt,
      amount: gross,
      limit: 5,
    });
    const fromBatch = await findDocRefsFromLiabilityRows(batchRows, gross);
    if (Object.keys(fromBatch).length > 0) {
      return fromBatch;
    }
    return {};
  }

  const allRows = await fetchChargeLiabilityRows(uid, { amount: gross, limit: 12 });
  return findDocRefsFromLiabilityRows(allRows, gross);
}

module.exports = {
  createCreditNoteDocument,
  createCollectionBillDocument,
  createInvestmentReservationEigenbelegDocument,
  createWalletReceiptDocument,
  createTradeExecutionDocument,
  computeCollectionBillReturnPercentage,
  assertCollectionBillReturnPercentageInvariant,
  ensureServiceChargeInvoiceDocument,
  resolveDocumentRefForFeeRefund,
};
