'use strict';

/**
 * searchDocuments — server-side Beleg-Suche.
 *
 * Gibt eine paginierte Liste von Parse `Document`-Belegen zurück, gefiltert nach:
 *   - documentNumber       (case-insensitive Substring auf accountingDocumentNumber/documentNumber)
 *   - type                 (DocumentType.rawValue oder Liste davon)
 *   - userId               (Parse objectId; "stable" wird durch User.userId zugelassen)
 *   - investmentId         (Pointer/String)
 *   - tradeId              (Pointer/String)
 *   - dateFrom / dateTo    (createdAt window, ISO; backend-Belege ohne uploadedAt)
 *   - search               (freier Substring auf name + accountingDocumentNumber)
 *   - limit / skip         (Pagination, default 25 / 0; max 100)
 *
 * Designentscheidungen (robust + ressourcenschonend):
 *   - Whitelist statt freier Felder, um teure Scans zu verhindern.
 *   - `containedIn` für Typenliste, sonst `equalTo` (indexable).
 *   - Substring-Match nur über `matches(...)` mit case-insensitive Flag UND Längenlimit
 *     auf den Suchbegriff (Schutz vor unbounded ReDoS).
 *   - `count: true` nur wenn der Aufrufer es explizit anfordert (`includeTotal`),
 *     ansonsten nur Page + Has-More (deutlich billiger bei großen Datasets).
 *   - `select(...)` reduziert Payload-Bytes; `accountingSummaryText` nur bei
 *     Einzelabruf (`getDocumentByObjectId`), nicht im Listing.
 *
 * Permission: `getFinancialDashboard` (analog zu App-Ledger / Auditor-Export).
 *
 * Zusätzlich: `getDocumentByLedgerReference` — Einzelabruf per `objectId` oder exakter
 * `referenceDocumentNumber` (GoB: zuerst `accountingDocumentNumber`, sonst `documentNumber`;
 * Mehrdeutigkeit oder fehlender Datensatz → Parse-Fehler).
 */

const { requirePermission } = require('../../../utils/permissions');
const { applyQuerySort, resolveListSortOrder } = require('../../../utils/applyQuerySort');
const { enrichDocumentsWithPartyFields } = require('./documentPartyPresentation');

const MAX_LIMIT = 100;
const DEFAULT_LIMIT = 25;
const MAX_SEARCH_TERM_LENGTH = 80;
const ALLOWED_SORT_FIELDS = ['uploadedAt', 'createdAt', 'accountingDocumentNumber', 'name'];

/**
 * Parse/Mongo may store dates as Date, ISO string, or legacy `{ __type: 'Date', iso }`.
 * Backend `Document` rows often omit `uploadedAt` — callers should fall back to `createdAt`.
 */
function serializeParseDateValue(value) {
  if (value == null || value === '') return null;
  if (value instanceof Date) {
    return Number.isNaN(value.getTime()) ? null : value.toISOString();
  }
  if (typeof value === 'object') {
    const iso = value.iso ?? value.ISO;
    if (typeof iso === 'string' && iso.trim()) {
      return serializeParseDateValue(iso);
    }
  }
  if (typeof value === 'string') {
    const trimmed = value.trim();
    if (!trimmed) return null;
    const d = new Date(trimmed);
    return Number.isNaN(d.getTime()) ? trimmed : d.toISOString();
  }
  if (typeof value === 'number' && Number.isFinite(value)) {
    const d = new Date(value);
    return Number.isNaN(d.getTime()) ? null : d.toISOString();
  }
  return null;
}

function documentTimestampRaw(doc) {
  return doc.get('uploadedAt') ?? doc.get('createdAt') ?? doc.createdAt ?? null;
}

function escapeForRegex(input) {
  return String(input || '').replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
}

function normalizeStringList(value) {
  if (!value) return [];
  if (Array.isArray(value)) {
    return value
      .map((v) => String(v || '').trim())
      .filter((v) => v.length > 0);
  }
  return String(value)
    .split(',')
    .map((v) => v.trim())
    .filter((v) => v.length > 0);
}

function clampInt(raw, { min, max, fallback }) {
  const n = parseInt(raw, 10);
  if (!Number.isFinite(n)) return fallback;
  return Math.max(min, Math.min(max, n));
}

function safeIsoDate(raw) {
  if (!raw) return null;
  try {
    const d = new Date(raw);
    if (Number.isNaN(d.getTime())) return null;
    return d;
  } catch {
    return null;
  }
}

function hasSearchPredicate(params) {
  const types = normalizeStringList(params.type);
  if (types.length > 0) return true;
  if (String(params.userId || '').trim()) return true;
  if (String(params.investmentId || '').trim()) return true;
  if (String(params.tradeId || '').trim()) return true;
  if (String(params.documentNumber || '').trim()) return true;
  if (String(params.search || '').trim()) return true;
  if (safeIsoDate(params.dateFrom) && safeIsoDate(params.dateTo)) return true;
  return false;
}

function applyDocumentScalarFilters(query, params) {
  const types = normalizeStringList(params.type);
  if (types.length === 1) {
    query.equalTo('type', types[0]);
  } else if (types.length > 1) {
    query.containedIn('type', types);
  }

  const userId = String(params.userId || '').trim();
  if (userId) {
    query.equalTo('userId', userId);
  }

  const investmentId = String(params.investmentId || '').trim();
  if (investmentId) {
    query.equalTo('investmentId', investmentId);
  }

  const tradeId = String(params.tradeId || '').trim();
  if (tradeId) {
    query.equalTo('tradeId', tradeId);
  }

  const dateFrom = safeIsoDate(params.dateFrom);
  if (dateFrom) {
    query.greaterThanOrEqualTo('createdAt', dateFrom);
  }
  const dateTo = safeIsoDate(params.dateTo);
  if (dateTo) {
    query.lessThanOrEqualTo('createdAt', dateTo);
  }

  return query;
}

function buildDocumentNumberOrQuery(params, docNumber) {
  const escaped = escapeForRegex(docNumber);
  const acc = applyDocumentScalarFilters(new Parse.Query('Document'), params);
  acc.matches('accountingDocumentNumber', escaped, 'i');
  const doc = applyDocumentScalarFilters(new Parse.Query('Document'), params);
  doc.matches('documentNumber', escaped, 'i');
  return Parse.Query.or(acc, doc);
}

function buildDocumentFreeTextOrQuery(params, freeText) {
  const escaped = escapeForRegex(freeText);
  const name = applyDocumentScalarFilters(new Parse.Query('Document'), params);
  name.matches('name', escaped, 'i');
  const acc = applyDocumentScalarFilters(new Parse.Query('Document'), params);
  acc.matches('accountingDocumentNumber', escaped, 'i');
  const doc = applyDocumentScalarFilters(new Parse.Query('Document'), params);
  doc.matches('documentNumber', escaped, 'i');
  return Parse.Query.or(name, acc, doc);
}

/**
 * Text OR-branches each carry scalar filters — avoids `Parse.Query.and(empty, or)`
 * which can return zero rows on some Parse Server versions.
 */
function buildDocumentSearchQuery(params) {
  const docNumber = String(params.documentNumber || '').trim().slice(0, MAX_SEARCH_TERM_LENGTH);
  const freeText = String(params.search || '').trim().slice(0, MAX_SEARCH_TERM_LENGTH);

  if (docNumber && freeText) {
    return Parse.Query.and(
      buildDocumentNumberOrQuery(params, docNumber),
      buildDocumentFreeTextOrQuery(params, freeText),
    );
  }
  if (docNumber) {
    return buildDocumentNumberOrQuery(params, docNumber);
  }
  if (freeText) {
    return buildDocumentFreeTextOrQuery(params, freeText);
  }
  return applyDocumentScalarFilters(new Parse.Query('Document'), params);
}

const { projectDocumentDetail } = require('./documentBelegPresentation');
const { enrichTraderDocumentMetadata } = require('./documentBelegEnrichment');

function projectDocumentRow(doc) {
  return {
    objectId: doc.id,
    userId: doc.get('userId') || '',
    name: doc.get('name') || '',
    type: doc.get('type') || 'other',
    status: doc.get('status') || '',
    fileURL: doc.get('fileURL') || '',
    size: typeof doc.get('size') === 'number' ? doc.get('size') : 0,
    uploadedAt: serializeParseDateValue(documentTimestampRaw(doc)),
    verifiedAt: serializeParseDateValue(doc.get('verifiedAt')),
    documentNumber: doc.get('documentNumber') || null,
    accountingDocumentNumber: doc.get('accountingDocumentNumber') || null,
    tradeId: doc.get('tradeId') || null,
    investmentId: doc.get('investmentId') || null,
    statementYear: doc.get('statementYear') || null,
    statementMonth: doc.get('statementMonth') || null,
    statementRole: doc.get('statementRole') || null,
  };
}

async function handleSearchDocuments(request) {
  requirePermission(request, 'getFinancialDashboard');

  const params = request.params || {};
  if (!hasSearchPredicate(params)) {
    throw new Parse.Error(
      Parse.Error.INVALID_QUERY,
      'searchDocuments: mindestens ein Filter erforderlich '
      + '(type, userId, investmentId, tradeId, documentNumber, search, oder dateFrom+dateTo).',
    );
  }
  const limit = clampInt(params.limit, { min: 1, max: MAX_LIMIT, fallback: DEFAULT_LIMIT });
  const skip = clampInt(params.skip, { min: 0, max: 10000, fallback: 0 });
  const includeTotal = Boolean(params.includeTotal);

  const finalQuery = buildDocumentSearchQuery(params);

  const sortMeta = applyQuerySort(finalQuery, params, {
    allowed: ALLOWED_SORT_FIELDS,
    defaultField: 'createdAt',
  });

  finalQuery.select([
    'userId', 'name', 'type', 'status', 'fileURL', 'size',
    'uploadedAt', 'createdAt', 'verifiedAt',
    'documentNumber', 'accountingDocumentNumber',
    'tradeId', 'investmentId',
    'statementYear', 'statementMonth', 'statementRole',
  ]);

  finalQuery.skip(skip);
  finalQuery.limit(limit + 1); // +1 for cheap hasMore detection without full count.

  const rowsPlusOne = await finalQuery.find({ useMasterKey: true });
  const hasMore = rowsPlusOne.length > limit;
  const rows = rowsPlusOne.slice(0, limit);

  let total = null;
  if (includeTotal) {
    total = await buildDocumentSearchQuery(params).count({ useMasterKey: true });
  }

  const projected = rows.map(projectDocumentRow);
  const items = await enrichDocumentsWithPartyFields(projected, rows);

  return {
    items,
    hasMore,
    total,
    limit,
    skip,
    sort: {
      sortBy: sortMeta.sortBy,
      sortOrder: sortMeta.sortOrder,
    },
  };
}

async function projectDocumentDetailResponse(doc, metadata) {
  const projected = projectDocumentRow(doc);
  const [enriched] = await enrichDocumentsWithPartyFields([projected], [doc]);
  const meta = metadata ?? doc.get('metadata') ?? {};
  const snapshotTraderName = String(meta.traderDisplayName || '').trim() || null;
  const partyEnrichment = {
    partyDisplayName: enriched.partyDisplayName || snapshotTraderName,
    partyRole: enriched.partyRole,
  };
  return {
    ...enriched,
    ...projectDocumentDetail(doc, metadata, partyEnrichment),
  };
}

async function handleGetDocumentByObjectId(request) {
  requirePermission(request, 'getFinancialDashboard');
  const objectId = String((request.params || {}).objectId || '').trim();
  if (!objectId) {
    throw new Parse.Error(Parse.Error.INVALID_QUERY, 'objectId required');
  }
  const q = new Parse.Query('Document');
  const doc = await q.get(objectId, { useMasterKey: true });
  const metadata = await enrichTraderDocumentMetadata(doc);
  return projectDocumentDetailResponse(doc, metadata);
}

const MAX_LEDGER_DOC_NUMBER_LEN = 80;

/**
 * GoB: exakte Belegnummer (kanonisch `accountingDocumentNumber`, sonst `documentNumber`).
 * Zuerst nur accounting-Feld — vermeidet falsche Treffer, wenn dieselbe Zeichenkette
 * zufällig als documentNumber woanders vorkommt, sobald ein kanonischer Treffer existiert.
 */
async function findSingleDocumentByExactLedgerNumber(canonical) {
  const n = String(canonical || '').trim();
  if (!n || n.length > MAX_LEDGER_DOC_NUMBER_LEN) {
    return null;
  }

  const qAcc = new Parse.Query('Document');
  qAcc.equalTo('accountingDocumentNumber', n);
  qAcc.limit(3);
  const byAcc = await qAcc.find({ useMasterKey: true });
  if (byAcc.length > 1) {
    throw new Parse.Error(
      Parse.Error.INVALID_QUERY,
      `getDocumentByLedgerReference: accountingDocumentNumber nicht eindeutig (${byAcc.length} Treffer für "${n}")`,
    );
  }
  if (byAcc.length === 1) {
    return byAcc[0];
  }

  const qDoc = new Parse.Query('Document');
  qDoc.equalTo('documentNumber', n);
  qDoc.limit(3);
  const byDocNum = await qDoc.find({ useMasterKey: true });
  if (byDocNum.length > 1) {
    throw new Parse.Error(
      Parse.Error.INVALID_QUERY,
      `getDocumentByLedgerReference: documentNumber nicht eindeutig (${byDocNum.length} Treffer für "${n}")`,
    );
  }
  if (byDocNum.length === 1) {
    return byDocNum[0];
  }
  return null;
}

/**
 * Einzelabruf für App-Ledger / GoB-Nachvollziehbarkeit: objectId ODER exakte Belegnummer
 * (wie in AppLedgerEntry.metadata.referenceDocumentNumber).
 */
async function handleGetDocumentByLedgerReference(request) {
  requirePermission(request, 'getFinancialDashboard');
  const params = request.params || {};
  const objectId = String(params.objectId || '').trim();
  const referenceDocumentNumber = String(
    params.referenceDocumentNumber || params.accountingDocumentNumber || '',
  ).trim();

  if (objectId) {
    return handleGetDocumentByObjectId({ ...request, params: { objectId } });
  }

  if (!referenceDocumentNumber) {
    throw new Parse.Error(
      Parse.Error.INVALID_QUERY,
      'getDocumentByLedgerReference: objectId oder referenceDocumentNumber erforderlich',
    );
  }

  const doc = await findSingleDocumentByExactLedgerNumber(referenceDocumentNumber);
  if (!doc) {
    throw new Parse.Error(
      Parse.Error.OBJECT_NOT_FOUND,
      `getDocumentByLedgerReference: kein Beleg zu Nummer "${referenceDocumentNumber}"`,
    );
  }

  const metadata = await enrichTraderDocumentMetadata(doc);
  return projectDocumentDetailResponse(doc, metadata);
}

function registerSearchDocumentsFunctions() {
  Parse.Cloud.define('searchDocuments', handleSearchDocuments);
  Parse.Cloud.define('getDocumentByObjectId', handleGetDocumentByObjectId);
  Parse.Cloud.define('getDocumentByLedgerReference', handleGetDocumentByLedgerReference);
}

module.exports = {
  registerSearchDocumentsFunctions,
  handleSearchDocuments,
  handleGetDocumentByObjectId,
  handleGetDocumentByLedgerReference,
  findSingleDocumentByExactLedgerNumber,
  projectDocumentRow,
  projectDocumentDetailResponse,
  serializeParseDateValue,
  documentTimestampRaw,
  buildDocumentSearchQuery,
};
