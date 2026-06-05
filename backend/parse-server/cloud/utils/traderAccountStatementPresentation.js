'use strict';

const { round2 } = require('./accountingHelper/shared');
const { collectLedgerUserIdCandidates } = require('./canonicalUserId');
const { buildUserInvoiceOrQueryBranches } = require('../functions/tradingInvoiceQuery');
const {
  isMirrorPoolOrderLeg,
  isMirrorPoolTradeLeg,
} = require('../services/poolMirrorActivation/poolActivationPolicy');

const TRADE_CASH_ENTRY_TYPES = new Set(['trade_buy', 'trade_sell']);
const CUSTOMER_PASSTHROUGH_ENTRY_TYPES = new Set([
  'commission_credit',
  'deposit',
  'withdrawal',
]);

const CUSTOMER_DISPLAY_ENTRY_RANK = Object.freeze({
  deposit: 5,
  withdrawal: 5,
  trade_buy: 10,
  trade_sell: 30,
  trading_fees: 40,
  commission_credit: 70,
});

function customerDisplayEntryRank(entryType) {
  return CUSTOMER_DISPLAY_ENTRY_RANK[String(entryType || '')] ?? 50;
}

const SETTLEMENT_INVOICE_TYPES = new Set([
  'buy',
  'sell',
  'buy_invoice',
  'sell_invoice',
]);

/** Max source rows loaded per AccountStatement / Invoice query (timeline may be shorter after merge). */
const TIMELINE_SOURCE_LIMIT = 500;

function dedupeParseObjectsById(rows) {
  const seen = new Set();
  return rows.filter((row) => {
    if (!row?.id || seen.has(row.id)) return false;
    seen.add(row.id);
    return true;
  });
}

function iso(d) {
  if (!d || !(d instanceof Date)) return new Date(0).toISOString();
  return d.toISOString();
}

function tradeCoverageKeys(tradeId, tradeNumber) {
  const keys = [];
  if (tradeId) {
    const trimmed = String(tradeId).trim();
    if (trimmed) keys.push(`id:${trimmed}`);
  }
  if (tradeNumber !== undefined && tradeNumber !== null && tradeNumber !== '') {
    keys.push(`num:${tradeNumber}`);
  }
  return keys;
}

function markTradeCovered(set, tradeId, tradeNumber) {
  for (const key of tradeCoverageKeys(tradeId, tradeNumber)) {
    set.add(key);
  }
}

function isTradeCovered(set, tradeId, tradeNumber) {
  return tradeCoverageKeys(tradeId, tradeNumber).some((key) => set.has(key));
}

function isTraderExecutionBelegNumber(number) {
  const n = String(number || '');
  return n.startsWith('TSC') || n.startsWith('TBC') || n.startsWith('TFS');
}

function belegRank(number) {
  if (isTraderExecutionBelegNumber(number)) return 3;
  if (String(number).includes('-INV-')) return 1;
  return 2;
}

function traderCashLegDedupKey(row) {
  const entryType = row.get('entryType');
  const tradeNumber = row.get('tradeNumber');
  // Customer view: one buy/sell cash line per trade number (paired legs may duplicate tradeId).
  if (tradeNumber !== undefined && tradeNumber !== null && tradeNumber !== '') {
    return `num:${tradeNumber}#${entryType}`;
  }
  const tradeId = row.get('tradeId');
  if (tradeId) {
    const trimmed = String(tradeId).trim();
    if (trimmed) return `${trimmed}#${entryType}`;
  }
  return null;
}

function prefersTraderExecutionBeleg(candidate, existing) {
  const candidateNumber = candidate.get('referenceDocumentNumber') || '';
  const existingNumber = existing.get('referenceDocumentNumber') || '';
  const candidateIsExecution = isTraderExecutionBelegNumber(candidateNumber);
  const existingIsExecution = isTraderExecutionBelegNumber(existingNumber);
  if (candidateIsExecution !== existingIsExecution) {
    return candidateIsExecution;
  }
  const candidateAt = candidate.get('createdAt') || new Date(0);
  const existingAt = existing.get('createdAt') || new Date(0);
  return candidateAt.getTime() > existingAt.getTime();
}

function deduplicatedTraderCashLegs(rows) {
  const passthrough = [];
  const bestByKey = new Map();

  for (const row of rows) {
    if (!TRADE_CASH_ENTRY_TYPES.has(String(row.get('entryType') || ''))) {
      passthrough.push(row);
      continue;
    }
    const key = traderCashLegDedupKey(row);
    if (!key) {
      passthrough.push(row);
      continue;
    }
    const existing = bestByKey.get(key);
    if (!existing || prefersTraderExecutionBeleg(row, existing)) {
      bestByKey.set(key, row);
    }
  }

  return [...passthrough, ...bestByKey.values()];
}

function isSettlementTradeInvoice(invoice) {
  const type = String(invoice.get('invoiceType') || '').toLowerCase();
  return SETTLEMENT_INVOICE_TYPES.has(type);
}

function invoiceTransactionType(invoice) {
  const type = String(invoice.get('invoiceType') || '').toLowerCase();
  const side = String(invoice.get('side') || '').toLowerCase();
  if (type.includes('sell') || side === 'sell') return 'sell';
  if (type.includes('buy') || side === 'buy') return 'buy';
  return null;
}

function invoiceOccurredAt(invoice) {
  return invoice.get('invoiceDate') || invoice.get('createdAt') || new Date();
}

function parseInstrumentFromTrade(trade, order) {
  const buyOrder = trade?.get?.('buyOrder') || {};
  const sellOrder = trade?.get?.('sellOrder') || {};
  const sellOrders = trade?.get?.('sellOrders') || [];
  const embeddedOrder = (sellOrder.wkn ? sellOrder : null)
    || (sellOrders[0] || null)
    || (buyOrder.wkn || buyOrder.symbol ? buyOrder : null);

  const wknOrIsin = String(
    trade?.get?.('wkn')
    || embeddedOrder?.wkn
    || embeddedOrder?.symbol
    || trade?.get?.('symbol')
    || order?.get?.('wkn')
    || order?.get?.('symbol')
    || '',
  ).trim();
  const securitiesDirection = String(
    order?.get?.('optionDirection')
    || embeddedOrder?.optionDirection
    || trade?.get?.('securityType')
    || '',
  ).trim();
  const underlyingAsset = String(
    order?.get?.('underlyingAsset')
    || embeddedOrder?.underlyingAsset
    || '',
  ).trim();
  const strikePrice = String(
    order?.get?.('strikePrice')
    || embeddedOrder?.strikePrice
    || '',
  ).trim();
  const issuer = String(
    order?.get?.('issuer')
    || embeddedOrder?.issuer
    || trade?.get?.('securityName')
    || '',
  ).trim();
  const quantityValue = trade?.get?.('quantity') ?? order?.get?.('executedQuantity') ?? order?.get?.('quantity');
  const quantity = quantityValue != null ? String(quantityValue) : '';

  return { wknOrIsin, securitiesDirection, underlyingAsset, strikePrice, issuer, quantity };
}

function parseInstrumentFromInvoice(invoice) {
  const lineItems = invoice.get('lineItems') || [];
  const primary = lineItems.find((item) => String(item?.itemType || '') === 'securities')
    || lineItems[0];
  const description = String(primary?.description || '').trim();
  const components = description
    .split(' - ')
    .map((part) => part.trim())
    .filter(Boolean);

  const instrument = {
    wknOrIsin: components[0] || '',
    securitiesDirection: components[1] || '',
    underlyingAsset: components[2] || '',
    strikePrice: components[3] || '',
    issuer: components[4] || '',
    quantity: primary?.quantity != null ? String(primary.quantity) : '',
  };
  return instrument;
}

function tradeStatementTitle(transactionType, instrument) {
  const directionLabel = transactionType === 'sell' ? 'VERKAUF' : 'KAUF';
  const parts = [];
  if (instrument.wknOrIsin) parts.push(instrument.wknOrIsin);
  if (instrument.securitiesDirection
    && instrument.securitiesDirection.toUpperCase() !== directionLabel) {
    parts.push(instrument.securitiesDirection);
  }
  if (instrument.underlyingAsset) parts.push(instrument.underlyingAsset);
  if (parts.length === 0) return directionLabel;
  return `${directionLabel} ${parts.join(' · ')}`;
}

function allocatedTradingFees(feesEntry, tradeBuyGross, tradeSellGross, forBuySide) {
  if (!feesEntry) return 0;
  const totalFees = Math.abs(Number(feesEntry.get('amount') || 0));
  if (totalFees <= 0) return 0;
  const denominator = tradeBuyGross + tradeSellGross;
  if (denominator <= 0.005) return totalFees;
  const sideGross = forBuySide ? tradeBuyGross : tradeSellGross;
  if (sideGross <= 0) return 0;
  return round2(totalFees * (sideGross / denominator));
}

function preferredBackendBeleg(tradeId, tradeNumber, entryType, cashLegRows) {
  const matches = cashLegRows.filter((row) => {
    if (String(row.get('entryType') || '') !== entryType) return false;
    if (tradeId && String(row.get('tradeId') || '').trim() === String(tradeId).trim()) return true;
    if (tradeNumber != null && row.get('tradeNumber') === tradeNumber) return true;
    return false;
  });
  if (!matches.length) return { referenceDocumentId: null, referenceDocumentNumber: null };
  const best = matches.reduce((a, b) => (
    belegRank(a.get('referenceDocumentNumber') || '') >= belegRank(b.get('referenceDocumentNumber') || '')
      ? a
      : b
  ));
  return {
    referenceDocumentId: best.get('referenceDocumentId') || null,
    referenceDocumentNumber: best.get('referenceDocumentNumber') || null,
  };
}

function signedNetAmount(transactionType, netAmount) {
  const absAmount = Math.abs(Number(netAmount) || 0);
  return transactionType === 'sell' ? absAmount : -absAmount;
}

function buildDisplayEventFromInvoice(invoice, cashLegRows) {
  const transactionType = invoiceTransactionType(invoice);
  if (!transactionType) return null;

  const instrument = parseInstrumentFromInvoice(invoice);
  const beleg = preferredBackendBeleg(
    invoice.get('tradeId'),
    invoice.get('tradeNumber'),
    transactionType === 'sell' ? 'trade_sell' : 'trade_buy',
    cashLegRows,
  );
  const netAmount = Math.abs(Number(invoice.get('totalAmount') || 0));
  const tradeNumber = invoice.get('tradeNumber');
  const tradeNumberStr = tradeNumber != null ? String(tradeNumber) : '';

  return {
    objectId: `invoice-display:${invoice.id}:${transactionType}`,
    entryType: transactionType === 'sell' ? 'trade_sell' : 'trade_buy',
    amount: signedNetAmount(transactionType, netAmount),
    at: invoiceOccurredAt(invoice),
    tradeId: invoice.get('tradeId') || null,
    tradeNumber: tradeNumber ?? null,
    referenceDocumentId: beleg.referenceDocumentId,
    referenceDocumentNumber: beleg.referenceDocumentNumber || invoice.get('invoiceNumber') || null,
    description: `Netto ${transactionType === 'sell' ? 'Verkauf' : 'Kauf'} (Rechnung ${invoice.get('invoiceNumber') || ''})`,
    source: 'customer_display',
    statementTitle: tradeStatementTitle(transactionType, instrument),
    transactionTypeLabel: transactionType,
    wknOrIsin: instrument.wknOrIsin || null,
    underlyingAsset: instrument.underlyingAsset || null,
    securitiesDirection: instrument.securitiesDirection || null,
    quantity: instrument.quantity || null,
    strikePrice: instrument.strikePrice || null,
    issuer: instrument.issuer || null,
    displayAmountMode: 'netCash',
    netAmount,
  };
}

function buildDisplayEventsFromBackendLegs({
  legs,
  feesEntry,
  tradeBuyGross,
  tradeSellGross,
  transactionType,
  tradeInstrument,
}) {
  const legGrossTotal = legs.reduce((sum, leg) => sum + Math.abs(Number(leg.get('amount') || 0)), 0);
  if (legGrossTotal <= 0) return [];

  const feeShare = allocatedTradingFees(
    feesEntry,
    tradeBuyGross,
    tradeSellGross,
    transactionType === 'buy',
  );
  const net = Math.max(0, round2(legGrossTotal - feeShare));
  const representative = legs.reduce((best, leg) => {
    const bestAt = best.get('createdAt') || new Date(0);
    const legAt = leg.get('createdAt') || new Date(0);
    return legAt.getTime() >= bestAt.getTime() ? leg : best;
  }, legs[0]);

  const instrument = tradeInstrument || { wknOrIsin: '', securitiesDirection: '', underlyingAsset: '' };
  const tradeNumber = representative.get('tradeNumber');
  const hasInstrument = Boolean(instrument.wknOrIsin || instrument.securitiesDirection || instrument.underlyingAsset);

  return [{
    objectId: `stmt-display:${representative.id}`,
    entryType: transactionType === 'sell' ? 'trade_sell' : 'trade_buy',
    amount: signedNetAmount(transactionType, net),
    at: representative.get('createdAt') || new Date(),
    tradeId: representative.get('tradeId') || null,
    tradeNumber: tradeNumber ?? null,
    referenceDocumentId: representative.get('referenceDocumentId') || null,
    referenceDocumentNumber: representative.get('referenceDocumentNumber') || null,
    description: representative.get('description') || '',
    source: 'customer_display',
    statementTitle: hasInstrument
      ? tradeStatementTitle(transactionType, instrument)
      : (tradeNumber != null
        ? `${transactionType === 'sell' ? 'VERKAUF' : 'KAUF'} · Trade #${String(tradeNumber).padStart(3, '0')}`
        : (transactionType === 'sell' ? 'VERKAUF' : 'KAUF')),
    transactionTypeLabel: transactionType,
    wknOrIsin: instrument.wknOrIsin || null,
    underlyingAsset: instrument.underlyingAsset || null,
    securitiesDirection: instrument.securitiesDirection || null,
    quantity: instrument.quantity || null,
    strikePrice: instrument.strikePrice || null,
    issuer: instrument.issuer || null,
    displayAmountMode: 'netCash',
    netAmount: net,
  }];
}

function isTraderCustomerVisibleTrade(tradeId, tradeById, orderByTradeId) {
  if (!tradeId) return true;
  const trade = tradeById.get(tradeId);
  if (trade && isMirrorPoolTradeLeg(trade)) return false;
  const order = orderByTradeId.get(tradeId);
  if (order && isMirrorPoolOrderLeg(order)) return false;
  return true;
}

function buildNetTradeDisplayEvents(stmtEntries, invoices, instrumentContext = {}) {
  const { tradeById = new Map(), orderByTradeId = new Map() } = instrumentContext;
  const cashLegRows = deduplicatedTraderCashLegs(
    stmtEntries.filter((row) => TRADE_CASH_ENTRY_TYPES.has(String(row.get('entryType') || ''))),
  );

  const feesByTradeKey = new Map();
  for (const row of stmtEntries) {
    if (String(row.get('entryType') || '') !== 'trading_fees') continue;
    for (const key of tradeCoverageKeys(row.get('tradeId'), row.get('tradeNumber'))) {
      feesByTradeKey.set(key, row);
    }
  }

  const events = [];
  const coveredBuy = new Set();
  const coveredSell = new Set();

  const settlementInvoices = invoices
    .filter(isSettlementTradeInvoice)
    .sort((a, b) => {
      const ta = invoiceOccurredAt(a).getTime();
      const tb = invoiceOccurredAt(b).getTime();
      return ta - tb;
    });

  for (const invoice of settlementInvoices) {
    const invoiceTradeId = invoice.get('tradeId');
    if (!isTraderCustomerVisibleTrade(invoiceTradeId, tradeById, orderByTradeId)) {
      continue;
    }
    const event = buildDisplayEventFromInvoice(invoice, cashLegRows);
    if (!event) continue;
    const alreadyCovered = event.transactionTypeLabel === 'buy'
      ? isTradeCovered(coveredBuy, event.tradeId, event.tradeNumber)
      : isTradeCovered(coveredSell, event.tradeId, event.tradeNumber);
    if (alreadyCovered) continue;
    events.push(event);
    if (event.transactionTypeLabel === 'buy') {
      markTradeCovered(coveredBuy, event.tradeId, event.tradeNumber);
    } else {
      markTradeCovered(coveredSell, event.tradeId, event.tradeNumber);
    }
  }

  const legsByTrade = new Map();
  for (const leg of cashLegRows) {
    const key = tradeCoverageKeys(leg.get('tradeId'), leg.get('tradeNumber'))[0]
      || `stmt:${leg.id}`;
    if (!legsByTrade.has(key)) legsByTrade.set(key, []);
    legsByTrade.get(key).push(leg);
  }

  for (const [, legs] of legsByTrade) {
    const tradeId = legs[0]?.get('tradeId') || null;
    if (!isTraderCustomerVisibleTrade(tradeId, tradeById, orderByTradeId)) {
      continue;
    }
    const tradeNumber = legs[0]?.get('tradeNumber') ?? null;
    const feeKey = tradeCoverageKeys(tradeId, tradeNumber).find((k) => feesByTradeKey.has(k));
    const feesEntry = feeKey ? feesByTradeKey.get(feeKey) : null;

    const buyLegs = legs.filter((leg) => leg.get('entryType') === 'trade_buy');
    const sellLegs = legs.filter((leg) => leg.get('entryType') === 'trade_sell');
    const tradeBuyGross = buyLegs.reduce((sum, leg) => sum + Math.abs(Number(leg.get('amount') || 0)), 0);
    const tradeSellGross = sellLegs.reduce((sum, leg) => sum + Math.abs(Number(leg.get('amount') || 0)), 0);

    const trade = tradeId ? tradeById.get(tradeId) : null;
    const order = tradeId ? orderByTradeId.get(tradeId) : null;
    const tradeInstrument = parseInstrumentFromTrade(trade, order);

    if (buyLegs.length > 0 && !isTradeCovered(coveredBuy, tradeId, tradeNumber)) {
      events.push(...buildDisplayEventsFromBackendLegs({
        legs: buyLegs,
        feesEntry,
        tradeBuyGross,
        tradeSellGross,
        transactionType: 'buy',
        tradeInstrument,
      }));
    }

    if (sellLegs.length > 0 && !isTradeCovered(coveredSell, tradeId, tradeNumber)) {
      events.push(...buildDisplayEventsFromBackendLegs({
        legs: sellLegs,
        feesEntry,
        tradeBuyGross,
        tradeSellGross,
        transactionType: 'sell',
        tradeInstrument,
      }));
    }
  }

  return events;
}

function enrichTimelineWithTradeInstruments(timeline, tradeById, orderByTradeId) {
  return timeline.map((event) => {
    if (event.wknOrIsin || !event.tradeId || !event.transactionTypeLabel) {
      return event;
    }
    const trade = tradeById.get(event.tradeId);
    const order = orderByTradeId.get(event.tradeId);
    if (!trade && !order) return event;
    const instrument = parseInstrumentFromTrade(trade, order);
    if (!instrument.wknOrIsin && !instrument.securitiesDirection && !instrument.underlyingAsset) {
      return event;
    }
    return {
      ...event,
      wknOrIsin: instrument.wknOrIsin || event.wknOrIsin,
      underlyingAsset: instrument.underlyingAsset || event.underlyingAsset,
      securitiesDirection: instrument.securitiesDirection || event.securitiesDirection,
      quantity: instrument.quantity || event.quantity,
      strikePrice: instrument.strikePrice || event.strikePrice,
      issuer: instrument.issuer || event.issuer,
      statementTitle: tradeStatementTitle(event.transactionTypeLabel, instrument),
    };
  });
}

async function loadTradeInstrumentContext(tradeIds) {
  const tradeById = new Map();
  const orderByTradeId = new Map();
  if (!tradeIds.length) {
    return { tradeById, orderByTradeId };
  }

  const tradeQuery = new Parse.Query('Trade');
  tradeQuery.containedIn('objectId', tradeIds);
  tradeQuery.limit(tradeIds.length);
  tradeQuery.select(
    'wkn',
    'symbol',
    'securityName',
    'securityType',
    'quantity',
    'buyOrder',
    'sellOrder',
    'sellOrders',
    'tradeNumber',
    'buyLegType',
  );
  const trades = await tradeQuery.find({ useMasterKey: true });
  for (const trade of trades) {
    tradeById.set(trade.id, trade);
  }

  const orderQuery = new Parse.Query('Order');
  orderQuery.containedIn('tradeId', tradeIds);
  orderQuery.ascending('createdAt');
  orderQuery.limit(Math.min(tradeIds.length * 3, TIMELINE_SOURCE_LIMIT));
  orderQuery.select(
    'tradeId',
    'wkn',
    'symbol',
    'optionDirection',
    'underlyingAsset',
    'strikePrice',
    'issuer',
    'quantity',
    'executedQuantity',
    'legType',
  );
  const orders = await orderQuery.find({ useMasterKey: true });
  for (const order of orders) {
    const tid = order.get('tradeId');
    if (tid && !orderByTradeId.has(tid)) {
      orderByTradeId.set(tid, order);
    }
  }

  return { tradeById, orderByTradeId };
}

function collectTradeIdsFromSources(stmtEntries, invoices, timeline) {
  const ids = new Set();
  for (const row of stmtEntries) {
    const tid = row.get('tradeId');
    if (tid) ids.add(String(tid).trim());
  }
  for (const inv of invoices) {
    const tid = inv.get('tradeId');
    if (tid) ids.add(String(tid).trim());
  }
  for (const event of timeline) {
    if (event.tradeId) ids.add(String(event.tradeId).trim());
  }
  return [...ids].filter(Boolean);
}

function passthroughStatementTitle(entryType) {
  if (entryType === 'commission_credit') return 'Gutschrift Provision';
  if (entryType === 'deposit') return 'Einzahlung';
  if (entryType === 'withdrawal') return 'Auszahlung';
  return null;
}

function buildDisplayEventFromStatementEntry(entry) {
  const entryType = String(entry.get('entryType') || '');
  return {
    objectId: entry.id,
    entryType,
    amount: round2(Number(entry.get('amount') || 0)),
    at: entry.get('createdAt') || new Date(),
    tradeId: entry.get('tradeId') || null,
    tradeNumber: entry.get('tradeNumber') ?? null,
    referenceDocumentId: entry.get('referenceDocumentId') || null,
    referenceDocumentNumber: entry.get('referenceDocumentNumber') || null,
    description: entry.get('description') || entryType,
    source: 'customer_display',
    statementTitle: passthroughStatementTitle(entryType),
    transactionTypeLabel: null,
    wknOrIsin: null,
    underlyingAsset: null,
    securitiesDirection: null,
    quantity: null,
    strikePrice: null,
    issuer: null,
    displayAmountMode: null,
    netAmount: Math.abs(Number(entry.get('amount') || 0)),
  };
}

async function fetchTraderStatementRows(userKeys) {
  if (!userKeys?.length) return { rows: [], truncated: false };
  const q = new Parse.Query('AccountStatement');
  q.containedIn('userId', userKeys);
  q.ascending('createdAt');
  q.limit(TIMELINE_SOURCE_LIMIT + 1);
  const fetched = dedupeParseObjectsById(await q.find({ useMasterKey: true }));
  const truncated = fetched.length > TIMELINE_SOURCE_LIMIT;
  return {
    rows: truncated ? fetched.slice(0, TIMELINE_SOURCE_LIMIT) : fetched,
    truncated,
  };
}

async function fetchTraderSettlementInvoices(user) {
  const stableId = user.get('stableId') || user.id;
  const branches = buildUserInvoiceOrQueryBranches({
    stableId,
    parseUserId: user.id,
    role: 'trader',
    invoiceType: null,
    tradeIds: [],
  });
  if (!branches.length) return { rows: [], truncated: false };
  const settlementTypes = Array.from(SETTLEMENT_INVOICE_TYPES);
  for (const branch of branches) {
    branch.containedIn('invoiceType', settlementTypes);
  }
  const query = branches.length === 1 ? branches[0] : Parse.Query.or(...branches);
  query.ascending('invoiceDate');
  query.limit(TIMELINE_SOURCE_LIMIT + 1);
  const fetched = dedupeParseObjectsById(await query.find({ useMasterKey: true }));
  const truncated = fetched.length > TIMELINE_SOURCE_LIMIT;
  return {
    rows: truncated ? fetched.slice(0, TIMELINE_SOURCE_LIMIT) : fetched,
    truncated,
  };
}

/**
 * SSOT Kundensicht: AccountStatement-Rohbuchungen + Rechnungen → Netto-Zeilen.
 */
async function loadTraderAccountStatementSourceData(user) {
  const userKeys = collectLedgerUserIdCandidates(user);
  const [stmtResult, invoiceResult] = await Promise.all([
    fetchTraderStatementRows(userKeys),
    fetchTraderSettlementInvoices(user),
  ]);
  return {
    userKeys,
    stmtEntries: stmtResult.rows,
    invoices: invoiceResult.rows,
    sourceTruncated: stmtResult.truncated || invoiceResult.truncated,
  };
}

/**
 * Chronologische Timeline (älteste zuerst) inkl. laufendem Saldo.
 */
function buildTraderCustomerTimeline({
  stmtEntries,
  invoices,
  initialBalance,
  instrumentContext = {},
}) {
  const { tradeById = new Map(), orderByTradeId = new Map() } = instrumentContext;
  const tradeEvents = buildNetTradeDisplayEvents(stmtEntries, invoices, instrumentContext);
  const latestTradeAt = new Map();

  for (const event of tradeEvents) {
    const atMs = event.at instanceof Date ? event.at.getTime() : 0;
    if (event.tradeId) {
      const key = `id:${event.tradeId}`;
      const prev = latestTradeAt.get(key) || 0;
      if (atMs >= prev) latestTradeAt.set(key, atMs);
    }
    if (event.tradeNumber != null && event.tradeNumber !== '') {
      const key = `num:${event.tradeNumber}`;
      const prev = latestTradeAt.get(key) || 0;
      if (atMs >= prev) latestTradeAt.set(key, atMs);
    }
  }

  const passthrough = stmtEntries
    .filter((entry) => CUSTOMER_PASSTHROUGH_ENTRY_TYPES.has(String(entry.get('entryType') || '')))
    .filter((entry) => isTraderCustomerVisibleTrade(
      entry.get('tradeId'),
      tradeById,
      orderByTradeId,
    ))
    .map(buildDisplayEventFromStatementEntry);

  for (const event of passthrough) {
    if (event.entryType !== 'commission_credit') continue;
    const tradeLatest = (event.tradeId && latestTradeAt.get(`id:${event.tradeId}`))
      || (event.tradeNumber != null && latestTradeAt.get(`num:${event.tradeNumber}`))
      || 0;
    if (tradeLatest) {
      event.at = new Date(tradeLatest + 1);
    }
  }

  const combined = [...tradeEvents, ...passthrough].sort((a, b) => {
    const ta = a.at instanceof Date ? a.at.getTime() : 0;
    const tb = b.at instanceof Date ? b.at.getTime() : 0;
    if (ta !== tb) return ta - tb;
    const rankDiff = customerDisplayEntryRank(a.entryType) - customerDisplayEntryRank(b.entryType);
    if (rankDiff !== 0) return rankDiff;
    return String(a.objectId).localeCompare(String(b.objectId));
  });

  let running = round2(initialBalance);
  return combined.map((event) => {
    const balanceBefore = running;
    running = round2(running + event.amount);
    return {
      ...event,
      balanceBefore,
      balanceAfter: running,
    };
  });
}

function timelineRowMatchesEntryType(row, entryType) {
  if (!entryType) return true;
  return String(row.entryType || '') === entryType;
}

function buildTraderDisplayApiRow(event, canonicalUserId) {
  const tradeNumber = event.tradeNumber;
  const tradeNumberPadded = tradeNumber != null
    ? String(tradeNumber).padStart(3, '0')
    : null;

  return {
    objectId: event.objectId,
    userId: canonicalUserId,
    entryType: event.entryType,
    amount: event.amount,
    balanceBefore: event.balanceBefore,
    balanceAfter: event.balanceAfter,
    tradeId: event.tradeId,
    tradeNumber: tradeNumberPadded != null ? Number(tradeNumber) : null,
    investmentId: null,
    investmentNumber: null,
    businessReference: tradeNumberPadded ? `TRD-${tradeNumberPadded}` : null,
    description: event.description,
    source: event.source,
    referenceDocumentId: event.referenceDocumentId,
    referenceDocumentNumber: event.referenceDocumentNumber,
    createdAt: iso(event.at),
    statementTitle: event.statementTitle,
    transactionType: event.transactionTypeLabel,
    wknOrIsin: event.wknOrIsin,
    underlyingAsset: event.underlyingAsset,
    securitiesDirection: event.securitiesDirection,
    quantity: event.quantity,
    strikePrice: event.strikePrice,
    issuer: event.issuer,
    displayAmountMode: event.displayAmountMode,
    netAmount: event.netAmount,
  };
}

/**
 * API-Zeilen: chronologisch aufsteigend (älteste zuerst), Pagination danach.
 */
function traderCustomerTimelineToApiRows(user, timeline, opts = {}) {
  const { entryType = null, limit = 50, skip = 0 } = opts;
  const filtered = entryType
    ? timeline.filter((row) => timelineRowMatchesEntryType(row, entryType))
    : timeline;
  const page = filtered.slice(skip, skip + limit);
  const canonicalUserId = user.get('stableId') || user.id;
  const rows = page.map((row) => buildTraderDisplayApiRow(row, canonicalUserId));
  return {
    rows,
    total: filtered.length,
    hasMore: skip + rows.length < filtered.length,
  };
}

/**
 * Builds customer timeline with optional Trade/Order instrument enrichment.
 */
async function buildTraderCustomerTimelineForUser({ stmtEntries, invoices, initialBalance }) {
  const tradeIds = collectTradeIdsFromSources(stmtEntries, invoices, []);
  const instrumentContext = await loadTradeInstrumentContext(tradeIds);
  let timeline = buildTraderCustomerTimeline({
    stmtEntries,
    invoices,
    initialBalance,
    instrumentContext,
  });
  timeline = enrichTimelineWithTradeInstruments(
    timeline,
    instrumentContext.tradeById,
    instrumentContext.orderByTradeId,
  );
  return timeline;
}

module.exports = {
  TIMELINE_SOURCE_LIMIT,
  loadTraderAccountStatementSourceData,
  buildTraderCustomerTimeline,
  buildTraderCustomerTimelineForUser,
  traderCustomerTimelineToApiRows,
  buildNetTradeDisplayEvents,
  enrichTimelineWithTradeInstruments,
  parseInstrumentFromTrade,
  parseInstrumentFromInvoice,
  tradeStatementTitle,
};
