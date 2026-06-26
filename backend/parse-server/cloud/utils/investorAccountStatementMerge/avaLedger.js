'use strict';

const { round2 } = require('../accountingHelper/shared');

/** AVA-Leg: Debit = weniger verfügbar → negatives signed amount (wie AccountStatement). */
function signedAmountFromAvaLedgerRow(row) {
  const raw = Number(row.get('amount')) || 0;
  const side = row.get('side');
  const signed = side === 'credit' ? raw : -raw;
  return parseFloat(signed.toFixed(2));
}

function syntheticEntryTypeFromLedgerRow(row) {
  const tt = String(row.get('transactionType') || '');
  const meta = row.get('metadata') || {};
  if (tt === 'appServiceCharge') {
    return 'app_service_charge';
  }
  if (tt === 'investmentEscrow') {
    const leg = String(meta.leg || 'unknown').trim();
    return `investment_escrow_${leg}`;
  }
  return tt || 'app_ledger';
}

/**
 * AccountStatement `residual_return` und AVA-Haben aus `reserveCapitalTradeSplit`
 * (splitPart available) sind dieselbe Kundenbewegung — nur einmal in der Timeline.
 */
function buildResidualReturnDedupKeys(stmtEntries) {
  const keys = new Set();
  for (const e of stmtEntries) {
    if (String(e.get('entryType') || '') !== 'residual_return') continue;
    const invId = String(e.get('investmentId') || '').trim();
    const tradeId = String(e.get('tradeId') || '').trim();
    const amt = round2(Math.abs(Number(e.get('amount') || 0)));
    if (!invId || amt <= 0) continue;
    keys.add(`${invId}|${tradeId}|${amt}`);
    keys.add(`${invId}|${amt}`);
  }
  return keys;
}

function isDuplicateAvaResidualLedgerRow(row, residualKeys) {
  if (!residualKeys || residualKeys.size === 0) return false;
  if (row.get('account') !== 'CLT-LIAB-AVA' || row.get('side') !== 'credit') return false;

  const meta = row.get('metadata') || {};
  const leg = String(meta.leg || '').trim();
  const residualLegs = new Set([
    'reserveCapitalTradeSplit',
    'deployResidualToAvailable',
    'tradingResidualReturn',
  ]);
  if (!residualLegs.has(leg)) return false;
  if (leg === 'reserveCapitalTradeSplit' && meta.splitPart !== 'available') return false;

  const refType = String(row.get('referenceType') || '');
  const invId = refType === 'Investment' ? String(row.get('referenceId') || '').trim() : '';
  const tradeId = String(meta.tradeId || row.get('tradeId') || '').trim();
  const amt = round2(Number(row.get('amount') || 0));
  if (!invId || amt <= 0) return false;

  return residualKeys.has(`${invId}|${tradeId}|${amt}`) || residualKeys.has(`${invId}|${amt}`);
}

/**
 * `investment_return` bucht den Überweisungsbetrag (netto inkl. Provision). Legacy
 * `commission_debit`-Zeilen auf dem Personenkonto wären eine Doppelbelastung.
 */
function buildSettlementTransferDedupKeys(stmtEntries) {
  const keys = new Set();
  for (const e of stmtEntries) {
    if (String(e.get('entryType') || '') !== 'investment_return') continue;
    const tradeId = String(e.get('tradeId') || '').trim();
    const investmentId = String(e.get('investmentId') || '').trim();
    if (tradeId && investmentId) {
      keys.add(`${tradeId}::${investmentId}`);
    }
  }
  return keys;
}

function isDuplicateSettlementCommissionDebit(stmt, transferKeys) {
  if (!transferKeys || transferKeys.size === 0) return false;
  if (String(stmt.get('entryType') || '') !== 'commission_debit') return false;
  const tradeId = String(stmt.get('tradeId') || '').trim();
  const investmentId = String(stmt.get('investmentId') || '').trim();
  if (!tradeId || !investmentId) return false;
  return transferKeys.has(`${tradeId}::${investmentId}`);
}

module.exports = {
  signedAmountFromAvaLedgerRow,
  syntheticEntryTypeFromLedgerRow,
  buildResidualReturnDedupKeys,
  isDuplicateAvaResidualLedgerRow,
  buildSettlementTransferDedupKeys,
  isDuplicateSettlementCommissionDebit,
};
