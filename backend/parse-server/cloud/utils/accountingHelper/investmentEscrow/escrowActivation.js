'use strict';

const { round2, resolveTradeBuyPrice } = require('../shared');
const { computeInvestorBuyLeg } = require('../legs');
const { buildPoolBuySnapshot } = require('../../../services/poolMirrorActivation/poolBuySnapshot');
const { loadConfig } = require('../../configHelper/index.js');
const { mergeInvestorFeeConfig } = require('../feeConfigSnapshot');
const { ensureBusinessCaseIdForTrade } = require('../businessCaseId');
const { bookAccountStatementEntry } = require('../statements');
const { resolveCanonicalUserId } = require('../../canonicalUserId');
const { audit } = require('../../structuredLogger');
const { hasEscrowLeg, eigenbelegRefFromReserveLeg } = require('./ledgerQueries');
const { bookReserveCapitalTradeSplit } = require('./escrowCapitalSplit');

/**
 * SSOT für RSV→PTR/AVA bei Aktivierung: gleiche Einstandslogik wie `buildPoolBuySnapshot`
 * (costBasisPerShare, floor Stück), nicht Bid-Solver `computeInvestorBuyLeg`.
 */
async function resolveActivationCapitalSplitAmounts(investment, trade, nominal) {
  const tradeId = trade.id;
  const participation = await new Parse.Query('PoolTradeParticipation')
    .equalTo('investmentId', investment.id)
    .equalTo('tradeId', tradeId)
    .descending('createdAt')
    .first({ useMasterKey: true });

  const snap = participation?.get('buySnapshot');
  if (snap && Number(snap.poolCapitalAllocated) > 0) {
    return {
      tradingAmount: round2(snap.poolCapitalAllocated),
      residualAmt: round2(Math.max(0, Number(snap.residualAmount) || 0)),
      poolPieces: Number(snap.poolPieces) || 0,
      basis: 'buySnapshot',
    };
  }

  const buyOrder = trade.get('buyOrder') || {};
  const fromSnapshot = buildPoolBuySnapshot(trade, nominal, buyOrder);
  if (fromSnapshot?.poolCapitalAllocated > 0) {
    return {
      tradingAmount: round2(fromSnapshot.poolCapitalAllocated),
      residualAmt: round2(Math.max(0, fromSnapshot.residualAmount || 0)),
      poolPieces: Number(fromSnapshot.poolPieces) || 0,
      basis: 'poolBuySnapshot',
    };
  }

  const tradeBuyPrice = resolveTradeBuyPrice(trade);
  if (!(tradeBuyPrice > 0)) {
    return { tradingAmount: 0, residualAmt: 0, basis: 'no_buy_price' };
  }

  let liveFinancial = {};
  try {
    const globalConfig = await loadConfig();
    liveFinancial = globalConfig?.financial || {};
  } catch (_) {
    liveFinancial = {};
  }
  const feeConfig = mergeInvestorFeeConfig(investment, trade, liveFinancial);
  const buyLeg = computeInvestorBuyLeg(nominal, tradeBuyPrice, feeConfig);
  const residualAmt = round2(Math.max(0, buyLeg?.residualAmount || 0));
  return {
    tradingAmount: round2(nominal - residualAmt),
    residualAmt,
    poolPieces: Number(buyLeg?.quantity) || 0,
    basis: 'computeInvestorBuyLeg_fallback',
  };
}

/**
 * Bei Aktivierung (Pool/Trade bekannt): GoB-Split aus RSV
 *   Soll RSV (Nominal) / Haben PTR (Einstand) / Haben AVA (Rest).
 * Parallel `residual_return` auf dem Kundenkonto. Idempotent pro investmentId + tradeId.
 */
async function ensureReserveCapitalTradeSplitOnActivation(investment, trade) {
  if (!investment?.id || !trade?.id) {
    return { skipped: true, reason: 'missing_refs' };
  }

  const nominal = round2(Number(investment.get('amount') || 0));
  if (nominal <= 0) {
    return { skipped: true, reason: 'zero_nominal' };
  }

  const tradeId = trade.id;
  const { tradingAmount, residualAmt, basis } = await resolveActivationCapitalSplitAmounts(
    investment,
    trade,
    nominal,
  );
  if (!(tradingAmount > 0) || round2(tradingAmount + residualAmt) !== nominal) {
    console.warn(
      `ensureReserveCapitalTradeSplitOnActivation: invalid split for trade ${tradeId} `
      + `(${investment.id}) basis=${basis} trading=${tradingAmount} residual=${residualAmt}`,
    );
    return { skipped: true, reason: 'invalid_split', basis, tradingAmount, residualAmt };
  }

  const investorId = investment.get('investorId');
  const investmentNumber = investment.get('investmentNumber') || '';
  const tradeNumber = trade.get('tradeNumber') || trade.get('number') || '';
  const businessCaseId = await ensureBusinessCaseIdForTrade(trade);

  const splitAlreadyBooked = await hasEscrowLeg(investment.id, 'reserveCapitalTradeSplit', { tradeId });
  if (!splitAlreadyBooked) {
    await bookReserveCapitalTradeSplit({
      investorId,
      nominal,
      tradingAmount,
      availableAmount: residualAmt,
      investmentId: investment.id,
      investmentNumber,
      tradeId,
      tradeNumber,
      businessCaseId,
    });
  }

  if (residualAmt > 0) {
    const eigenbelegRef = await eigenbelegRefFromReserveLeg(investment.id);
    const canonicalUserId = await resolveCanonicalUserId(investorId);
    const existingResidualStmt = await new Parse.Query('AccountStatement')
      .equalTo('userId', canonicalUserId)
      .equalTo('investmentId', investment.id)
      .equalTo('tradeId', tradeId)
      .equalTo('entryType', 'residual_return')
      .equalTo('source', 'backend')
      .first({ useMasterKey: true });
    if (!existingResidualStmt) {
      await bookAccountStatementEntry({
        userId: canonicalUserId,
        entryType: 'residual_return',
        amount: residualAmt,
        tradeId,
        tradeNumber,
        investmentId: investment.id,
        investmentNumber,
        description: investmentNumber
          ? `Restbetrag aus Investment ${investmentNumber}`
          : `Restbetrag aus Investment (Rundungsdifferenz Stückkauf)`,
        ...eigenbelegRef,
        businessCaseId,
      });
    }
  }

  if (!splitAlreadyBooked) {
    audit.info('escrow.activation.split', {
      investmentId: investment.id,
      tradeId: tradeId || null,
      businessCaseId,
      nominal,
      tradingAmount,
      residualAmount: residualAmt,
      message: '📒 ensureReserveCapitalTradeSplitOnActivation: RSV→TRD + AVA',
    });
  }

  // Investor-App / GoB: gebuchte Kaufseite (Total Buy Cost = nominal − Rest) persistieren,
  // damit die UI nicht das Reservierungs-Nominal anzeigt, sobald die Position aktiv ist.
  try {
    const existingPool = Number(investment.get('poolTradingAmount') || 0);
    if (
      !Number.isFinite(existingPool)
      || existingPool <= 0.005
      || Math.abs(existingPool - tradingAmount) > 0.02
    ) {
      investment.set('poolTradingAmount', tradingAmount);
      await investment.save(null, { useMasterKey: true });
    }
  } catch (err) {
    audit.warn('escrow.activation.poolTradingAmount.persistFailure', {
      investmentId: investment.id,
      tradeId: tradeId || null,
      businessCaseId,
      error: err && err.message ? err.message : String(err),
      message: 'ensureReserveCapitalTradeSplitOnActivation: poolTradingAmount persist failed',
    });
  }

  return {
    skipped: splitAlreadyBooked,
    reason: splitAlreadyBooked ? 'already_booked' : undefined,
    basis,
    nominal,
    tradingAmount,
    availableAmount: residualAmt,
  };
}

module.exports = {
  resolveActivationCapitalSplitAmounts,
  ensureReserveCapitalTradeSplitOnActivation,
};
