'use strict';

/**
 * Auditor-oriented CSV export: correlates Personenkonto, App-Hauptbuch, Belege,
 * Wallet und Rechnungen über `businessCaseId` (soweit vorhanden).
 *
 * Permission: same as financial dashboard (`getFinancialDashboard`).
 */

const { requirePermission } = require('../../../utils/permissions');

const DEFAULT_LIMIT = 8000;
const HARD_CAP = 25000;

function csvEscape(val) {
  if (val === null || val === undefined) return '';
  const s = String(val);
  if (/[",\n\r]/.test(s)) return `"${s.replace(/"/g, '""')}"`;
  return s;
}

function rowsToCsv(headers, rows) {
  const lines = [headers.map(csvEscape).join(',')];
  for (const row of rows) {
    lines.push(headers.map((h) => csvEscape(row[h])).join(','));
  }
  return lines.join('\n');
}

function iso(d) {
  if (!d) return '';
  try {
    return d instanceof Date ? d.toISOString() : new Date(d).toISOString();
  } catch {
    return '';
  }
}

function parseRange(params) {
  const dateFrom = params.dateFrom || params.from;
  const dateTo = params.dateTo || params.to;
  if (!dateFrom || !dateTo) {
    throw new Parse.Error(Parse.Error.INVALID_QUERY, 'Parameter „dateFrom“ und „dateTo“ (ISO-Datum) sind erforderlich.');
  }
  const from = new Date(dateFrom);
  const to = new Date(dateTo);
  if (Number.isNaN(from.getTime()) || Number.isNaN(to.getTime())) {
    throw new Parse.Error(Parse.Error.INVALID_QUERY, 'Ungültiges Datumsformat für dateFrom/dateTo.');
  }
  if (from > to) {
    throw new Parse.Error(Parse.Error.INVALID_QUERY, 'dateFrom darf nicht nach dateTo liegen.');
  }
  return { from, to };
}

function limitN(params) {
  const raw = Number(params.limitPerSection);
  if (!Number.isFinite(raw) || raw <= 0) return DEFAULT_LIMIT;
  return Math.min(Math.floor(raw), HARD_CAP);
}

async function fetchAccountStatements(from, to, businessCaseId, lim) {
  const q = new Parse.Query('AccountStatement');
  q.greaterThanOrEqualTo('createdAt', from);
  q.lessThanOrEqualTo('createdAt', to);
  if (businessCaseId) q.equalTo('businessCaseId', businessCaseId);
  q.ascending('createdAt');
  q.limit(lim);
  const rows = await q.find({ useMasterKey: true });
  return rows.map((e) => ({
    objectId: e.id,
    createdAt: iso(e.get('createdAt')),
    userId: e.get('userId') || '',
    entryType: e.get('entryType') || '',
    amount: e.get('amount'),
    balanceAfter: e.get('balanceAfter'),
    tradeId: e.get('tradeId') || '',
    tradeNumber: e.get('tradeNumber') ?? '',
    investmentId: e.get('investmentId') || '',
    investmentNumber: e.get('investmentNumber') || '',
    referenceDocumentId: e.get('referenceDocumentId') || '',
    referenceDocumentNumber: e.get('referenceDocumentNumber') || '',
    businessCaseId: e.get('businessCaseId') || '',
    businessReference: e.get('businessReference') || '',
    description: e.get('description') || '',
    source: e.get('source') || '',
  }));
}

async function fetchAppLedgerEntries(from, to, businessCaseId, lim) {
  const base = () => {
    const q = new Parse.Query('AppLedgerEntry');
    q.greaterThanOrEqualTo('createdAt', from);
    q.lessThanOrEqualTo('createdAt', to);
    q.ascending('createdAt');
    return q;
  };

  let rows = [];
  try {
    if (businessCaseId) {
      try {
        const q = base();
        q.equalTo('metadata.businessCaseId', businessCaseId);
        q.limit(lim);
        rows = await q.find({ useMasterKey: true });
      } catch (err) {
        console.warn(
          'exportAuditorFinancialCsv: AppLedger metadata.businessCaseId query failed, filtering in memory:',
          err && err.message ? err.message : err,
        );
        const q2 = base();
        q2.limit(Math.min(HARD_CAP, Math.max(lim * 10, lim)));
        const wide = await q2.find({ useMasterKey: true });
        rows = wide
          .filter((e) => String((e.get('metadata') || {}).businessCaseId || '') === businessCaseId)
          .slice(0, lim);
      }
    } else {
      const q = base();
      q.limit(lim);
      rows = await q.find({ useMasterKey: true });
    }
  } catch {
    return [];
  }

  return rows.map((e) => {
    const metadata = e.get('metadata') || {};
    const bc = metadata.businessCaseId || '';
    return {
      objectId: e.id,
      createdAt: iso(e.get('createdAt')),
      account: e.get('account') || '',
      side: e.get('side') || '',
      amount: e.get('amount'),
      userId: e.get('userId') || '',
      userRole: e.get('userRole') || '',
      transactionType: e.get('transactionType') || '',
      referenceId: e.get('referenceId') || '',
      referenceType: e.get('referenceType') || '',
      description: e.get('description') || '',
      metadataLeg: metadata.leg || '',
      businessCaseId: bc,
      referenceDocumentId: metadata.referenceDocumentId || '',
      referenceDocumentNumber: metadata.referenceDocumentNumber || '',
    };
  });
}

async function fetchDocuments(from, to, businessCaseId, lim) {
  const q = new Parse.Query('Document');
  q.greaterThanOrEqualTo('createdAt', from);
  q.lessThanOrEqualTo('createdAt', to);
  if (businessCaseId) q.equalTo('businessCaseId', businessCaseId);
  q.ascending('createdAt');
  q.limit(lim);
  let rows = [];
  try {
    rows = await q.find({ useMasterKey: true });
  } catch {
    return [];
  }
  return rows.map((e) => ({
    objectId: e.id,
    createdAt: iso(e.get('createdAt')),
    userId: e.get('userId') || '',
    type: e.get('type') || '',
    accountingDocumentNumber: e.get('accountingDocumentNumber') || '',
    documentNumber: e.get('documentNumber') || '',
    tradeId: e.get('tradeId') || '',
    investmentId: e.get('investmentId') || '',
    referenceId: e.get('referenceId') || '',
    referenceType: e.get('referenceType') || '',
    businessCaseId: e.get('businessCaseId') || '',
    source: e.get('source') || '',
  }));
}

async function fetchWalletTransactions(from, to, businessCaseId, lim) {
  const q = new Parse.Query('WalletTransaction');
  q.greaterThanOrEqualTo('createdAt', from);
  q.lessThanOrEqualTo('createdAt', to);
  if (businessCaseId) q.equalTo('businessCaseId', businessCaseId);
  q.ascending('createdAt');
  q.limit(lim);
  let rows = [];
  try {
    rows = await q.find({ useMasterKey: true });
  } catch {
    return [];
  }
  return rows.map((e) => ({
    objectId: e.id,
    createdAt: iso(e.get('createdAt')),
    completedAt: iso(e.get('completedAt')),
    userId: e.get('userId') || '',
    transactionType: e.get('transactionType') || '',
    amount: e.get('amount'),
    transactionNumber: e.get('transactionNumber') || '',
    businessCaseId: e.get('businessCaseId') || '',
    status: e.get('status') || '',
    reference: e.get('reference') || '',
  }));
}

async function fetchInvoices(from, to, businessCaseId, lim) {
  const q = new Parse.Query('Invoice');
  q.greaterThanOrEqualTo('createdAt', from);
  q.lessThanOrEqualTo('createdAt', to);
  if (businessCaseId) q.equalTo('businessCaseId', businessCaseId);
  q.ascending('createdAt');
  q.limit(lim);
  let rows = [];
  try {
    rows = await q.find({ useMasterKey: true });
  } catch {
    return [];
  }
  return rows.map((e) => ({
    objectId: e.id,
    createdAt: iso(e.get('createdAt')),
    invoiceNumber: e.get('invoiceNumber') || '',
    invoiceType: e.get('invoiceType') || '',
    userId: e.get('userId') || e.get('customerId') || '',
    batchId: e.get('batchId') || '',
    tradeId: e.get('tradeId') || '',
    orderId: e.get('orderId') || '',
    businessCaseId: e.get('businessCaseId') || '',
    totalAmount: e.get('totalAmount'),
    source: e.get('source') || '',
  }));
}

const DATA_DICTIONARY = {
  version: 1,
  description: 'FIN1 Prüfer-Export: Spalten für CSV-Dateien (UTF-8, Komma-getrennt).',
  correlationField: 'businessCaseId',
  tables: {
    accountStatement: {
      parseClass: 'AccountStatement',
      purpose: 'Personenkonto / Kontoauszug-Zeilen (Sub-Ledger).',
      columns: {
        objectId: 'Parse objectId',
        createdAt: 'Buchungszeitpunkt (UTC, ISO-8601)',
        userId: 'Nutzer (Investor/Trader)',
        entryType: 'Technischer Buchungstyp (z. B. trade_buy, commission_debit)',
        amount: 'Betragsänderung',
        balanceAfter: 'Saldo nach Zeile',
        tradeId: 'Verknüpfung Trade',
        tradeNumber: 'Anzeige Trade-Nummer',
        investmentId: 'Verknüpfung Investment',
        investmentNumber: 'Anzeige Investment-Nummer',
        referenceDocumentId: 'Parse objectId des Belegs (Document)',
        referenceDocumentNumber: 'Belegnummer (accountingDocumentNumber)',
        businessCaseId: 'Korrelations-ID für Wirtschaftsvorfall',
        businessReference: 'Kurzreferenz Text (TRD/Beleg/Inv.)',
        description: 'Buchungstext',
        source: 'Herkunft (z. B. backend)',
      },
    },
    appLedgerEntry: {
      parseClass: 'AppLedgerEntry',
      purpose: 'App-Hauptbuch (Doppelbuch-Sätze, einzelne Zeile).',
      columns: {
        objectId: 'Parse objectId',
        createdAt: 'Zeitpunkt (UTC)',
        account: 'Internes Konto (z. B. CLT-LIAB-AVA)',
        side: 'debit oder credit',
        amount: 'Betrag',
        userId: 'Zugeordneter Nutzer falls vorhanden',
        userRole: 'Rolle',
        transactionType: 'Ledger-Transaktionstyp',
        referenceId: 'Fachliche Referenz (Trade, Wallet, Batch, …)',
        referenceType: 'Typ der referenceId',
        description: 'Text',
        metadataLeg: 'Idempotenz-/Komponenten-Schlüssel (metadata.leg)',
        businessCaseId: 'Aus metadata.businessCaseId',
        referenceDocumentNumber: 'Belegnummer falls in metadata',
      },
    },
    document: {
      parseClass: 'Document',
      purpose: 'Belege / PDF-Metadaten',
      columns: {
        objectId: 'Parse objectId',
        createdAt: 'Erstellzeit',
        userId: 'Eigentümer',
        type: 'Belegtyp',
        accountingDocumentNumber: 'Buchhaltungs-Belegnummer',
        documentNumber: 'Alternative Dokumentnummer',
        tradeId: 'Trade-Verknüpfung',
        investmentId: 'Investment-Verknüpfung',
        referenceId: 'Externe Referenz',
        referenceType: 'Referenztyp',
        businessCaseId: 'Korrelations-ID',
        source: 'Herkunft',
      },
    },
    walletTransaction: {
      parseClass: 'WalletTransaction',
      purpose: 'Wallet-Bewegungen',
      columns: {
        objectId: 'Parse objectId',
        createdAt: 'Anlagezeit',
        completedAt: 'Abschlusszeit',
        userId: 'Nutzer',
        transactionType: 'Typ (deposit, withdrawal, …)',
        amount: 'Betrag',
        transactionNumber: 'Fortlaufende TXN-Nummer',
        businessCaseId: 'Korrelations-ID',
        status: 'Status',
        reference: 'Optionale Referenz',
      },
    },
    invoice: {
      parseClass: 'Invoice',
      purpose: 'Rechnungen (Ausgangsrechnungen / Service Charge)',
      columns: {
        objectId: 'Parse objectId',
        createdAt: 'Erstellzeit',
        invoiceNumber: 'Rechnungsnummer',
        invoiceType: 'Typ (service_charge, buy_invoice, …)',
        userId: 'Kunde',
        batchId: 'Batch / Gruppierung',
        tradeId: 'Optional',
        orderId: 'Optional',
        businessCaseId: 'Korrelations-ID',
        totalAmount: 'Gesamtbetrag',
        source: 'Herkunft',
      },
    },
  },
};

async function handleExportAuditorFinancialCsv(request) {
  requirePermission(request, 'getFinancialDashboard');
  const params = request.params || {};
  const { from, to } = parseRange(params);
  const lim = limitN(params);
  const businessCaseId = String(params.businessCaseId || '').trim() || null;

  const [
    accountStatementRows,
    appLedgerRows,
    documentRows,
    walletRows,
    invoiceRows,
  ] = await Promise.all([
    fetchAccountStatements(from, to, businessCaseId, lim),
    fetchAppLedgerEntries(from, to, businessCaseId, lim),
    fetchDocuments(from, to, businessCaseId, lim),
    fetchWalletTransactions(from, to, businessCaseId, lim),
    fetchInvoices(from, to, businessCaseId, lim),
  ]);

  const astHeaders = [
    'objectId', 'createdAt', 'userId', 'entryType', 'amount', 'balanceAfter',
    'tradeId', 'tradeNumber', 'investmentId', 'investmentNumber',
    'referenceDocumentId', 'referenceDocumentNumber', 'businessCaseId',
    'businessReference', 'description', 'source',
  ];
  const aleHeaders = [
    'objectId', 'createdAt', 'account', 'side', 'amount', 'userId', 'userRole',
    'transactionType', 'referenceId', 'referenceType', 'description',
    'metadataLeg', 'businessCaseId', 'referenceDocumentId', 'referenceDocumentNumber',
  ];
  const docHeaders = [
    'objectId', 'createdAt', 'userId', 'type', 'accountingDocumentNumber',
    'documentNumber', 'tradeId', 'investmentId', 'referenceId', 'referenceType',
    'businessCaseId', 'source',
  ];
  const wtHeaders = [
    'objectId', 'createdAt', 'completedAt', 'userId', 'transactionType',
    'amount', 'transactionNumber', 'businessCaseId', 'status', 'reference',
  ];
  const invHeaders = [
    'objectId', 'createdAt', 'invoiceNumber', 'invoiceType', 'userId',
    'batchId', 'tradeId', 'orderId', 'businessCaseId', 'totalAmount', 'source',
  ];

  return {
    generatedAt: new Date().toISOString(),
    parameters: {
      dateFrom: from.toISOString(),
      dateTo: to.toISOString(),
      businessCaseId: businessCaseId || '',
      limitPerSection: lim,
    },
    rowCounts: {
      accountStatement: accountStatementRows.length,
      appLedgerEntry: appLedgerRows.length,
      document: documentRows.length,
      walletTransaction: walletRows.length,
      invoice: invoiceRows.length,
    },
    dataDictionary: DATA_DICTIONARY,
    csv: {
      accountStatement: rowsToCsv(astHeaders, accountStatementRows),
      appLedgerEntry: rowsToCsv(aleHeaders, appLedgerRows),
      document: rowsToCsv(docHeaders, documentRows),
      walletTransaction: rowsToCsv(wtHeaders, walletRows),
      invoice: rowsToCsv(invHeaders, invoiceRows),
    },
  };
}

function registerAuditorExportFunctions() {
  Parse.Cloud.define('exportAuditorFinancialCsv', handleExportAuditorFinancialCsv);
}

module.exports = {
  registerAuditorExportFunctions,
  handleExportAuditorFinancialCsv,
  DATA_DICTIONARY,
};
