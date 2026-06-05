'use strict';

const { round2 } = require('../../utils/accountingHelper/shared');
const {
  computeTradingFeesWithBreakdown,
} = require('../../utils/accountingHelper/settlementTradeMath');
const { calculateOrderFees } = require('../../utils/helpers');

function stmtRowToEvent(row) {
  return {
    objectId: row.id,
    entryType: String(row.get('entryType') || ''),
    amount: round2(Number(row.get('amount') || 0)),
    at: row.get('createdAt') || new Date(0),
    tradeId: row.get('tradeId') || null,
    tradeNumber: row.get('tradeNumber') ?? null,
    description: row.get('description') || '',
    referenceDocumentId: row.get('referenceDocumentId') || null,
    referenceDocumentNumber: row.get('referenceDocumentNumber') || null,
    source: row.get('source') || 'backend',
    _row: row,
  };
}

function eventToMockRow(event) {
  if (event._row) return event._row;
  return {
    id: event.objectId,
    get: (key) => {
      const map = {
        entryType: event.entryType,
        amount: event.amount,
        createdAt: event.at,
        tradeId: event.tradeId,
        tradeNumber: event.tradeNumber,
        description: event.description,
        referenceDocumentId: event.referenceDocumentId,
        referenceDocumentNumber: event.referenceDocumentNumber,
        source: event.source,
      };
      return map[key];
    },
  };
}

function compareEvents(a, b) {
  const ta = a.at instanceof Date ? a.at.getTime() : 0;
  const tb = b.at instanceof Date ? b.at.getTime() : 0;
  if (ta !== tb) return ta - tb;
  return String(a.objectId).localeCompare(String(b.objectId));
}

function computeBuyOnlyTradingFees(trade) {
  const buyOrder = trade.get('buyOrder');
  if (!buyOrder) {
    return { totalFees: 0 };
  }
  const fees = calculateOrderFees(Number(buyOrder.totalAmount || 0), true);
  return {
    totalFees: round2(
      (fees.orderFee || 0) + (fees.exchangeFee || 0) + (fees.foreignCosts || 0),
    ),
  };
}

function makeSyntheticTradingFeeEvent({
  trade,
  tradeId,
  tradeNumber,
  amount,
  at,
  phase,
  referenceFrom,
}) {
  const tn = tradeNumber != null ? String(tradeNumber).padStart(3, '0') : '???';
  const symbol = trade?.get?.('symbol') || '';
  const phaseLabel = phase === 'buy' ? 'Kauf' : 'Verkauf';
  return {
    objectId: `ledger-fee-${phase}:${tradeId}:${at.getTime()}`,
    entryType: 'trading_fees',
    amount: round2(amount),
    at,
    tradeId,
    tradeNumber,
    description: `Handelsgebühren ${phaseLabel} Trade #${tn}${symbol ? ` (${symbol})` : ''}`,
    referenceDocumentId: referenceFrom?.referenceDocumentId || null,
    referenceDocumentNumber: referenceFrom?.referenceDocumentNumber || null,
    source: referenceFrom?.source || 'ledger_expansion',
    _row: null,
  };
}

function feeRowNearBuy(feeRows, buyEvent, buyFeesTotal) {
  if (!buyEvent) return false;
  const buyMs = buyEvent.at instanceof Date ? buyEvent.at.getTime() : 0;
  return feeRows.some((fee) => {
    const feeMs = fee.at instanceof Date ? fee.at.getTime() : 0;
    const nearBuy = Math.abs(feeMs - buyMs) <= 120_000;
    const buySized = Math.abs(Math.abs(fee.amount) - buyFeesTotal) < 0.05;
    return nearBuy && buySized;
  });
}

/**
 * Admin Ledger: Handelsgebühren getrennt nach Kauf- und Verkaufsphase anzeigen.
 *
 * **Trader-only.** Diese Erweiterung synthetisiert Kauf/Verkauf-Splits aus
 * `Trade.buyOrder` / `Trade.sellOrders` und greift damit auf **Trader-side**
 * `calculateOrderFees`-Beträge zurück. Für Investor-AccountStatement-Gruppen
 * (kein `trade_buy`-Event, keine `trading_fees`-Rohzeile) wäre das Ergebnis
 * falsch — Investor-Splits stammen aus der `investorCollectionBill.metadata`
 * und werden durch `applyInvestorGoBCollectionBillFeeGranularity` injiziert.
 * Wir erkennen den Trader-Fall hier strikt am Vorhandensein einer
 * `trade_buy`-Markeroder einer bestehenden aggregierten `trading_fees`-Zeile;
 * fehlen beide, geben wir die Events **unverändert** zurück.
 */
function expandSingleTradeLedgerEvents(events, trade) {
  if (!trade || !events.length) return events;

  const sorted = [...events].sort(compareEvents);
  const buy = sorted.find((e) => e.entryType === 'trade_buy');
  const feeRows = sorted.filter((e) => e.entryType === 'trading_fees');

  // Investor-Statements haben weder `trade_buy` noch aggregierte
  // `trading_fees` desselben Trades — Trader-Fee-Splits dürfen dort nicht
  // synthetisiert werden (vgl. CB-Granularität für Investor).
  if (!buy && feeRows.length === 0) {
    return sorted;
  }

  const buyFees = computeBuyOnlyTradingFees(trade);
  const { totalFees } = computeTradingFeesWithBreakdown(trade);
  const sellFeesAmount = round2(Math.max(0, totalFees - buyFees.totalFees));
  const hasBuyFeeRow = feeRowNearBuy(feeRows, buy, buyFees.totalFees);

  const out = [];

  for (const event of sorted) {
    if (event.entryType === 'trading_fees') {
      continue;
    }
    out.push(event);
    if (event.entryType === 'trade_buy' && buyFees.totalFees > 0.005 && !hasBuyFeeRow) {
      out.push(makeSyntheticTradingFeeEvent({
        trade,
        tradeId: event.tradeId,
        tradeNumber: event.tradeNumber,
        amount: -buyFees.totalFees,
        at: new Date((event.at instanceof Date ? event.at : new Date()).getTime() + 1),
        phase: 'buy',
        referenceFrom: feeRows[0] || event,
      }));
    }
  }

  if (feeRows.length === 1 && totalFees > 0.005) {
    const fee = feeRows[0];
    if (sellFeesAmount > 0.005) {
      out.push(makeSyntheticTradingFeeEvent({
        trade,
        tradeId: fee.tradeId,
        tradeNumber: fee.tradeNumber,
        amount: -sellFeesAmount,
        at: fee.at instanceof Date ? fee.at : new Date(),
        phase: 'sell',
        referenceFrom: fee,
      }));
    } else {
      out.push(fee);
    }
  } else if (feeRows.length === 0 && sellFeesAmount > 0.005) {
    const lastSell = sorted.filter((e) => e.entryType === 'trade_sell').pop();
    const anchor = lastSell || buy;
    const at = anchor?.at instanceof Date
      ? new Date(anchor.at.getTime() + (lastSell ? 2 : 3))
      : new Date();
    out.push(makeSyntheticTradingFeeEvent({
      trade,
      tradeId: anchor?.tradeId || buy?.tradeId,
      tradeNumber: anchor?.tradeNumber ?? buy?.tradeNumber,
      amount: -sellFeesAmount,
      at,
      phase: 'sell',
      referenceFrom: anchor,
    }));
  } else if (feeRows.length > 1) {
    out.push(...feeRows);
  }

  return out.sort(compareEvents);
}

function expandTraderLedgerStmtEntries(stmtEntries, tradesById) {
  if (!stmtEntries?.length) return stmtEntries;

  const byTrade = new Map();
  const noTrade = [];

  for (const row of stmtEntries) {
    const event = stmtRowToEvent(row);
    if (!event.tradeId) {
      noTrade.push(event);
      continue;
    }
    if (!byTrade.has(event.tradeId)) byTrade.set(event.tradeId, []);
    byTrade.get(event.tradeId).push(event);
  }

  const expanded = [...noTrade];
  for (const [, events] of byTrade) {
    const tradeId = events[0]?.tradeId;
    expanded.push(...expandSingleTradeLedgerEvents(events, tradesById.get(tradeId)));
  }

  expanded.sort(compareEvents);
  return expanded.map(eventToMockRow);
}

async function loadTradesByIds(tradeIds) {
  const map = new Map();
  if (!tradeIds?.length) return map;
  const unique = [...new Set(tradeIds.filter(Boolean))];
  const q = new Parse.Query('Trade');
  q.containedIn('objectId', unique);
  q.limit(unique.length);
  q.select('buyOrder', 'sellOrder', 'sellOrders', 'symbol', 'tradeNumber');
  const rows = await q.find({ useMasterKey: true });
  for (const trade of rows) {
    map.set(trade.id, trade);
  }
  return map;
}

module.exports = {
  expandTraderLedgerStmtEntries,
  loadTradesByIds,
  computeBuyOnlyTradingFees,
  expandSingleTradeLedgerEvents,
};
