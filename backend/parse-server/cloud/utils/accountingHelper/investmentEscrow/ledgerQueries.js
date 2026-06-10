'use strict';

const { round2 } = require('../shared');
const {
  CLT_LIAB_AVA,
  CLT_LIAB_PTR,
  CLT_LIAB_PPS,
  CLT_LIAB_TRD_LEGACY,
} = require('../clientLiabilityAccounts');
const {
  POOL_TRADE_ACCOUNTS,
  TRANSACTION_TYPE,
  REFERENCE_TYPE,
  TRADE_SETTLEMENT_ESCROW_LEGS,
} = require('./constants');

async function hasEscrowLeg(investmentId, leg, { tradeId, sellOrderId } = {}) {
  const q = new Parse.Query('AppLedgerEntry');
  q.equalTo('referenceId', investmentId);
  q.containedIn('referenceType', [REFERENCE_TYPE, REFERENCE_TYPE.toLowerCase()]);
  q.equalTo('transactionType', TRANSACTION_TYPE);
  q.equalTo('metadata.leg', leg);
  const tradeKey = tradeId != null ? String(tradeId).trim() : '';
  const sellKey = sellOrderId != null ? String(sellOrderId).trim() : '';
  if (sellKey) q.equalTo('metadata.sellOrderId', sellKey);
  if (tradeKey) q.equalTo('metadata.tradeId', tradeKey);
  const hit = await q.first({ useMasterKey: true });
  return Boolean(hit);
}

async function sumEscrowLegCreditForTrade(investmentId, leg, { tradeId, account } = {}) {
  const q = new Parse.Query('AppLedgerEntry');
  q.equalTo('referenceId', investmentId);
  q.containedIn('referenceType', [REFERENCE_TYPE, REFERENCE_TYPE.toLowerCase()]);
  q.equalTo('transactionType', TRANSACTION_TYPE);
  q.equalTo('side', 'credit');
  if (account) {
    q.equalTo('account', account);
  }
  q.limit(500);
  const rows = await q.find({ useMasterKey: true });
  const tradeKey = tradeId != null ? String(tradeId).trim() : '';
  return rows.reduce((sum, e) => {
    const m = e.get('metadata') || {};
    if (m.leg !== leg) return sum;
    if (tradeKey && String(m.tradeId || '').trim() !== tradeKey) return sum;
    return round2(sum + (Number(e.get('amount')) || 0));
  }, 0);
}

async function sumPartialSellPpsPendingForTrade(investmentId, tradeId) {
  const tradeKey = String(tradeId || '').trim();
  if (!tradeKey) return 0;
  const legs = ['partialSellRelease', 'partialSellProfitRecognition'];
  let total = 0;
  for (const leg of legs) {
    total += await sumEscrowLegCreditForTrade(investmentId, leg, {
      tradeId: tradeKey,
      account: CLT_LIAB_PPS,
    });
  }
  return round2(total);
}

async function sumEscrowLegDebitForTrade(investmentId, leg, { tradeId, account } = {}) {
  const q = new Parse.Query('AppLedgerEntry');
  q.equalTo('referenceId', investmentId);
  q.containedIn('referenceType', [REFERENCE_TYPE, REFERENCE_TYPE.toLowerCase()]);
  q.equalTo('transactionType', TRANSACTION_TYPE);
  q.equalTo('side', 'debit');
  if (account) {
    const accounts = account === CLT_LIAB_PTR
      ? [CLT_LIAB_PTR, CLT_LIAB_TRD_LEGACY]
      : [account];
    q.containedIn('account', accounts);
  }
  q.limit(500);
  const rows = await q.find({ useMasterKey: true });
  const tradeKey = tradeId != null ? String(tradeId).trim() : '';
  return rows.reduce((sum, e) => {
    const m = e.get('metadata') || {};
    if (m.leg !== leg) return sum;
    if (tradeKey && String(m.tradeId || '').trim() !== tradeKey) return sum;
    return round2(sum + (Number(e.get('amount')) || 0));
  }, 0);
}

async function sumEscrowPoolTradeDebitForLeg(investmentId, leg) {
  const q = new Parse.Query('AppLedgerEntry');
  q.equalTo('referenceId', investmentId);
  q.containedIn('referenceType', [REFERENCE_TYPE, REFERENCE_TYPE.toLowerCase()]);
  q.equalTo('transactionType', TRANSACTION_TYPE);
  q.containedIn('account', POOL_TRADE_ACCOUNTS);
  q.equalTo('side', 'debit');
  q.limit(500);
  const rows = await q.find({ useMasterKey: true });
  return rows.reduce((sum, e) => {
    const m = e.get('metadata') || {};
    if (m.leg !== leg) return sum;
    return round2(sum + (Number(e.get('amount')) || 0));
  }, 0);
}

/** Restbetrag auf AVA (reserveCapitalTradeSplit oder Legacy tradingResidualReturn). */
async function sumCapitalSplitToAvailable(investmentId) {
  const q = new Parse.Query('AppLedgerEntry');
  q.equalTo('referenceId', investmentId);
  q.containedIn('referenceType', [REFERENCE_TYPE, REFERENCE_TYPE.toLowerCase()]);
  q.equalTo('transactionType', TRANSACTION_TYPE);
  q.limit(500);
  const rows = await q.find({ useMasterKey: true });
  return rows.reduce((sum, e) => {
    const m = e.get('metadata') || {};
    const amt = Number(e.get('amount')) || 0;
    if (m.leg === 'reserveCapitalTradeSplit' && e.get('account') === CLT_LIAB_AVA && e.get('side') === 'credit') {
      return round2(sum + amt);
    }
    if (m.leg === 'tradingResidualReturn' && POOL_TRADE_ACCOUNTS.includes(e.get('account')) && e.get('side') === 'debit') {
      return round2(sum + amt);
    }
    return sum;
  }, 0);
}

/**
 * GoB: Folgebuchungen (deploy, release, …) beziehen sich auf denselben Eigenbeleg wie `leg: reserve`.
 * Liest `metadata.referenceDocumentId` / `referenceDocumentNumber` von einer bestehenden Reserve-Zeile.
 */
async function eigenbelegRefFromReserveLeg(investmentId) {
  const q = new Parse.Query('AppLedgerEntry');
  q.equalTo('referenceId', investmentId);
  q.containedIn('referenceType', [REFERENCE_TYPE, REFERENCE_TYPE.toLowerCase()]);
  q.equalTo('transactionType', TRANSACTION_TYPE);
  q.limit(100);
  const rows = await q.find({ useMasterKey: true });
  for (const e of rows) {
    const m = e.get('metadata') || {};
    if (m.leg !== 'reserve') continue;
    const id = String(m.referenceDocumentId || '').trim();
    const num = String(m.referenceDocumentNumber || '').trim();
    if (id && num) {
      return { referenceDocumentId: id, referenceDocumentNumber: num };
    }
  }
  return {};
}

async function sumPtrPoolCapitalReleasedForTrade(investmentId, tradeId) {
  const tradeKey = String(tradeId || '').trim();
  const partial = await sumEscrowLegDebitForTrade(investmentId, 'partialSellRelease', {
    tradeId: tradeKey || undefined,
    account: CLT_LIAB_PTR,
  });
  const settlement = await sumEscrowLegDebitForTrade(investmentId, 'tradeSettlementPoolRelease', {
    tradeId: tradeKey || undefined,
    account: CLT_LIAB_PTR,
  });
  return round2(partial + settlement);
}

/** True when Collection-Bill-Settlement (inkl. Teil-Verkauf-Pfad) bereits Escrow gebucht hat. */
async function hasTradeSettlementEscrow(investmentId) {
  for (const leg of TRADE_SETTLEMENT_ESCROW_LEGS) {
    if (await hasEscrowLeg(investmentId, leg)) return true;
  }
  return false;
}

module.exports = {
  hasEscrowLeg,
  sumEscrowLegCreditForTrade,
  sumPartialSellPpsPendingForTrade,
  sumEscrowLegDebitForTrade,
  sumEscrowPoolTradeDebitForLeg,
  sumCapitalSplitToAvailable,
  eigenbelegRefFromReserveLeg,
  sumPtrPoolCapitalReleasedForTrade,
  hasTradeSettlementEscrow,
};
