'use strict';

const { round2 } = require('../accountingHelper/shared');

function dateMs(at) {
  if (!at || !(at instanceof Date)) return 0;
  const t = at.getTime();
  return Number.isFinite(t) ? t : 0;
}

function stmtInvId(row) {
  if (row.kind !== 'stmt') return '';
  return String(row.stmt.get('investmentId') || '').trim();
}

function stmtTradeId(row) {
  if (row.kind !== 'stmt') return '';
  return String(row.stmt.get('tradeId') || '').trim();
}

function stmtEntryType(row) {
  if (row.kind !== 'stmt') return '';
  return String(row.stmt.get('entryType') || '').trim();
}

function matchesInvAndTrade(row, invId, tradeId) {
  if (stmtInvId(row) !== invId) return false;
  const tid = stmtTradeId(row);
  if (!tradeId) return true;
  if (!tid) return true;
  return tid === tradeId;
}

function findFirstInvestmentActivateIndex(rows, invId) {
  for (let i = 0; i < rows.length; i += 1) {
    const row = rows[i];
    if (row.kind !== 'stmt') continue;
    if (stmtEntryType(row) !== 'investment_activate') continue;
    if (stmtInvId(row) !== invId) continue;
    return i;
  }
  return -1;
}

/** Verkaufsgebühren-Zeitpunkt: letzte `residual_return`, sonst letzte `investment_return`, sonst letzte `trade_sell`. */
function findLastStmtIndexByType(rows, entryType, invId, tradeId) {
  let last = -1;
  for (let i = 0; i < rows.length; i += 1) {
    const row = rows[i];
    if (row.kind !== 'stmt') continue;
    if (stmtEntryType(row) !== entryType) continue;
    if (!matchesInvAndTrade(row, invId, tradeId)) continue;
    last = i;
  }
  return last;
}

function findSellFeeAnchorIndex(rows, invId, tradeId) {
  const r = findLastStmtIndexByType(rows, 'residual_return', invId, tradeId);
  if (r >= 0) return r;
  const ret = findLastStmtIndexByType(rows, 'investment_return', invId, tradeId);
  if (ret >= 0) return ret;
  return findLastStmtIndexByType(rows, 'trade_sell', invId, tradeId);
}

function feeComponentLabel(side, key) {
  const part = key === 'orderFee' ? 'Ordergebühr'
    : key === 'exchangeFee' ? 'Börsenplatzgebühr'
      : key === 'foreignCosts' ? 'Fremdkostenpauschale'
        : 'Gebühr';
  return side === 'buy' ? `${part} (Kauf)` : `${part} (Verkauf)`;
}

function syntheticTradingFeeStmtRow({
  objectId,
  createdAt,
  amount,
  tradeId,
  tradeNumber,
  investmentId,
  description,
  referenceDocumentId,
  referenceDocumentNumber,
}) {
  return {
    id: objectId,
    get: (key) => {
      const map = {
        entryType: 'trading_fees',
        amount,
        createdAt,
        tradeId,
        tradeNumber: tradeNumber ?? null,
        investmentId,
        description,
        referenceDocumentId: referenceDocumentId || null,
        referenceDocumentNumber: referenceDocumentNumber || null,
        source: 'ledger_goB_collection_bill_fees',
      };
      return map[key];
    },
  };
}

function recomputeInvestorLedgerBalances(timelineRows, initialBalance) {
  let running = initialBalance;
  return timelineRows.map((row) => {
    const balanceBefore = parseFloat(running.toFixed(2));
    running += row.amount;
    const balanceAfter = parseFloat(running.toFixed(2));
    return {
      ...row,
      balanceBefore,
      balanceAfter,
    };
  });
}

/**
 * Admin Ledger (GoB): Handelsgebühren laut Collection-Bill **einzeln** buchen — Kaufkomponenten
 * unmittelbar nach `investment_activate`, Verkaufskomponenten nach `residual_return` (fallback
 * `investment_return` / `trade_sell`). Aggregierte `trading_fees` desselben `tradeId` werden entfernt.
 *
 * @param {Array} timeline — Ausgabe von `buildInvestorLedgerGoBTimeline`
 * @param {Array<{ investmentId?: string|null, tradeId?: string|null, documentId: string, documentNumber?: string|null, feeComponents: Array<{ side: string, key: string, amount: number }> }>} bills
 */
function applyInvestorGoBCollectionBillFeeGranularity(timeline, bills, initialBalance) {
  if (!timeline || timeline.length === 0 || !bills || bills.length === 0) {
    return timeline;
  }

  const syntheticRows = [];
  const tradesToStrip = new Set();

  for (const bill of bills) {
    const tradeId = String(bill.tradeId || '').trim();
    const invId = String(bill.investmentId || '').trim();
    if (!tradeId || !invId) continue;

    const components = bill.feeComponents || [];
    const buyParts = components.filter((f) => f.side === 'buy' && round2(Number(f.amount) || 0) > 0);
    const sellParts = components.filter((f) => f.side === 'sell' && round2(Number(f.amount) || 0) > 0);
    if (buyParts.length === 0 && sellParts.length === 0) continue;

    const activateIdx = findFirstInvestmentActivateIndex(timeline, invId);
    const sellAnchorIdx = findSellFeeAnchorIndex(timeline, invId, tradeId);
    if (activateIdx < 0 || sellAnchorIdx < 0) continue;

    const beleg = bill.documentNumber || bill.documentId;
    const activateMs = dateMs(timeline[activateIdx].at);
    const sellAnchorRawMs = dateMs(timeline[sellAnchorIdx].at);
    const lastBuySlotMs = activateMs + buyParts.length;
    const sellBaseMs = Math.max(sellAnchorRawMs, lastBuySlotMs);

    tradesToStrip.add(tradeId);

    let seq = 0;
    for (const f of buyParts) {
      const amt = round2(Number(f.amount) || 0);
      if (amt <= 0) continue;
      const ms = activateMs + (++seq);
      syntheticRows.push({
        kind: 'stmt',
        at: new Date(ms),
        tie: `goB-cb:${bill.documentId}:buy:${f.key}:${ms}`,
        amount: -amt,
        stmt: syntheticTradingFeeStmtRow({
          objectId: `goB-cb:${bill.documentId}:buy:${f.key}:${ms}`,
          createdAt: new Date(ms),
          amount: -amt,
          tradeId,
          tradeNumber: bill.tradeNumber,
          investmentId: invId,
          description: `Handelsgebühren Kauf: ${feeComponentLabel('buy', f.key)} (laut Beleg ${beleg})`,
          referenceDocumentId: bill.documentId,
          referenceDocumentNumber: bill.documentNumber || null,
        }),
      });
    }

    seq = 0;
    for (const f of sellParts) {
      const amt = round2(Number(f.amount) || 0);
      if (amt <= 0) continue;
      const ms = sellBaseMs + (++seq);
      syntheticRows.push({
        kind: 'stmt',
        at: new Date(ms),
        tie: `goB-cb:${bill.documentId}:sell:${f.key}:${ms}`,
        amount: -amt,
        stmt: syntheticTradingFeeStmtRow({
          objectId: `goB-cb:${bill.documentId}:sell:${f.key}:${ms}`,
          createdAt: new Date(ms),
          amount: -amt,
          tradeId,
          tradeNumber: bill.tradeNumber,
          investmentId: invId,
          description: `Handelsgebühren Verkauf: ${feeComponentLabel('sell', f.key)} (laut Beleg ${beleg})`,
          referenceDocumentId: bill.documentId,
          referenceDocumentNumber: bill.documentNumber || null,
        }),
      });
    }
  }

  if (tradesToStrip.size === 0) return timeline;

  const filtered = timeline.filter((row) => {
    if (row.kind !== 'stmt') return true;
    if (stmtEntryType(row) !== 'trading_fees') return true;
    const tid = stmtTradeId(row);
    if (!tid || !tradesToStrip.has(tid)) return true;
    return false;
  });

  const merged = [...filtered, ...syntheticRows];
  merged.sort((a, b) => {
    const ta = dateMs(a.at);
    const tb = dateMs(b.at);
    if (ta !== tb) return ta - tb;
    return String(a.tie).localeCompare(String(b.tie));
  });

  return recomputeInvestorLedgerBalances(merged, initialBalance);
}

module.exports = {
  applyInvestorGoBCollectionBillFeeGranularity,
};
