'use strict';

/**
 * SSOT: Trader Personenkonto / Kundensicht-Buchungen dürfen nur am TRADER-Leg hängen.
 * MIRROR_POOL ist Pool-/Investoren-Abrechnung — nie trade_buy/trade_sell/commission_credit am Mirror.
 */

const { isMirrorPoolTradeLeg } = require('./poolActivationPolicy');
const {
  getTraderTradeForPairedMirrorLeg,
  getMirrorTradeForPairedTraderLeg,
} = require('../../utils/pairedTradeMirrorSync');
const { roleFromEntryType } = require('../../utils/accountingHelper/settlementGLRules');
const { audit } = require('../../utils/structuredLogger');

const TRADER_CUSTOMER_ENTRY_TYPES = Object.freeze([
  'trade_buy',
  'trade_sell',
  'trading_fees',
  'commission_credit',
  'withholding_tax_debit',
  'solidarity_surcharge_debit',
  'church_tax_debit',
]);

const TRADER_CUSTOMER_ENTRY_TYPE_SET = new Set(TRADER_CUSTOMER_ENTRY_TYPES);

function isTraderCustomerFacingEntryType(entryType) {
  return TRADER_CUSTOMER_ENTRY_TYPE_SET.has(String(entryType || ''));
}

function resolvesAsTraderBooking({ entryType, userRole }) {
  const role = String(userRole || roleFromEntryType(entryType) || '').trim().toLowerCase();
  if (role === 'investor') return false;
  return isTraderCustomerFacingEntryType(entryType);
}

async function loadTradeById(tradeId) {
  if (!tradeId) return null;
  try {
    return await new Parse.Query('Trade').get(String(tradeId), { useMasterKey: true });
  } catch (_) {
    return null;
  }
}

/**
 * Resolve tradeId/tradeNumber for trader-facing AccountStatement rows.
 * Redirects MIRROR_POOL → paired TRADER leg; throws if impossible.
 */
async function resolveTraderCustomerBookingContext({
  tradeId,
  tradeNumber,
  entryType,
  userRole,
  trade: tradeObj,
}) {
  if (!resolvesAsTraderBooking({ entryType, userRole })) {
    return {
      tradeId: tradeId || null,
      tradeNumber: tradeNumber ?? null,
      trade: tradeObj || null,
      redirected: false,
    };
  }

  if (!tradeId) {
    throw new Error(`Trader customer booking requires tradeId (entryType=${entryType})`);
  }

  const trade = tradeObj || await loadTradeById(tradeId);
  if (!trade) {
    throw new Error(`Trader customer booking: Trade not found (${tradeId})`);
  }

  if (!isMirrorPoolTradeLeg(trade)) {
    return {
      tradeId: trade.id,
      tradeNumber: trade.get('tradeNumber') ?? tradeNumber ?? null,
      trade,
      redirected: false,
    };
  }

  const traderLeg = await getTraderTradeForPairedMirrorLeg(trade);
  if (!traderLeg) {
    const message = `Trader customer booking blocked: MIRROR_POOL trade ${trade.id} has no paired TRADER leg (entryType=${entryType})`;
    audit.error('settlement.traderBooking.mirrorLegBlocked', {
      mirrorTradeId: trade.id,
      entryType,
      message,
    });
    throw new Error(message);
  }

  audit.info('settlement.traderBooking.mirrorLegRedirect', {
    mirrorTradeId: trade.id,
    traderTradeId: traderLeg.id,
    entryType,
    message: 'Redirected trader customer booking from MIRROR_POOL to TRADER leg',
  });

  return {
    tradeId: traderLeg.id,
    tradeNumber: traderLeg.get('tradeNumber') ?? tradeNumber ?? null,
    trade: traderLeg,
    redirected: true,
    sourceMirrorTradeId: trade.id,
  };
}

/**
 * settleAndDistribute: pool economics vs trader Personenkonto trennen.
 */
async function resolveTraderSettlementBookingTrade(trade) {
  if (!trade) {
    return {
      traderBookingTrade: null,
      poolSettlementTrade: null,
      invokedOnMirrorLeg: false,
    };
  }

  if (isMirrorPoolTradeLeg(trade)) {
    const traderLeg = await getTraderTradeForPairedMirrorLeg(trade);
    return {
      traderBookingTrade: traderLeg,
      poolSettlementTrade: trade,
      invokedOnMirrorLeg: true,
    };
  }

  return {
    traderBookingTrade: trade,
    poolSettlementTrade: trade,
    invokedOnMirrorLeg: false,
  };
}

/**
 * Admin repair: welche Trade-Rows gehören zum Paar (TRADER + MIRROR_POOL).
 */
async function resolvePairedRepairScope(trade) {
  if (!trade) {
    return {
      settlementTrade: null,
      poolTrade: null,
      traderLeg: null,
      tradeIdsForCleanup: [],
    };
  }

  if (isMirrorPoolTradeLeg(trade)) {
    const traderLeg = await getTraderTradeForPairedMirrorLeg(trade);
    const tradeIdsForCleanup = [trade.id];
    if (traderLeg && traderLeg.id !== trade.id) tradeIdsForCleanup.push(traderLeg.id);
    return {
      settlementTrade: traderLeg || trade,
      poolTrade: trade,
      traderLeg: traderLeg || null,
      tradeIdsForCleanup,
      redirectedFromMirror: Boolean(traderLeg),
    };
  }

  const mirrorLeg = await getMirrorTradeForPairedTraderLeg(trade);
  const tradeIdsForCleanup = [trade.id];
  if (mirrorLeg && mirrorLeg.id !== trade.id) tradeIdsForCleanup.push(mirrorLeg.id);
  return {
    settlementTrade: trade,
    poolTrade: mirrorLeg || trade,
    traderLeg: trade,
    tradeIdsForCleanup,
    redirectedFromMirror: false,
  };
}

module.exports = {
  TRADER_CUSTOMER_ENTRY_TYPES,
  TRADER_CUSTOMER_ENTRY_TYPE_SET,
  isTraderCustomerFacingEntryType,
  resolvesAsTraderBooking,
  resolveTraderCustomerBookingContext,
  resolveTraderSettlementBookingTrade,
  resolvePairedRepairScope,
  loadTradeById,
};
