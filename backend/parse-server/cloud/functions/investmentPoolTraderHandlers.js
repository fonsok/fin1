'use strict';

const { round2 } = require('../utils/accountingHelper/shared');
const investmentEscrow = require('../utils/accountingHelper/investmentEscrow');
const { traderOwnsInvestment } = require('./investmentAccess');

async function handleTraderActivateReservedInvestment(request) {
  const user = request.user;
  if (!user) throw new Parse.Error(Parse.Error.INVALID_SESSION_TOKEN, 'Anmeldung erforderlich.');

  const role = user.get('role');
  if (role !== 'trader') {
    throw new Parse.Error(Parse.Error.OPERATION_FORBIDDEN, 'Trader-Rolle erforderlich.');
  }

  const { investmentId } = request.params || {};
  if (!investmentId) throw new Parse.Error(Parse.Error.INVALID_VALUE, 'Parameter „investmentId“ erforderlich.');

  const Investment = Parse.Object.extend('Investment');
  let investment;
  try {
    investment = await new Parse.Query(Investment).get(investmentId, { useMasterKey: true });
  } catch {
    throw new Parse.Error(Parse.Error.OBJECT_NOT_FOUND, 'Investment nicht gefunden.');
  }

  if (!traderOwnsInvestment(investment, user)) {
    const traderIdRaw = String(investment.get('traderId') || '');
    const looksLikeMockTraderId = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(traderIdRaw);
    if (!looksLikeMockTraderId) {
      throw new Parse.Error(Parse.Error.OPERATION_FORBIDDEN, 'Vorgang nicht erlaubt.');
    }
    console.warn(`⚠️ traderActivateReservedInvestment: ownership fallback for mock trader id ${traderIdRaw}, user=${user.id}`);
  }

  if (investment.get('status') !== 'reserved') {
    throw new Parse.Error(Parse.Error.INVALID_VALUE, 'Nur reservierte Investments können aktiviert werden.');
  }

  investment.set('status', 'active');
  investment.set('reservationStatus', 'active');
  await investment.save(null, { useMasterKey: true });

  try {
    await investmentEscrow.bookDeployToTrading({
      investorId: investment.get('investorId'),
      amount: round2(investment.get('amount') || 0),
      investmentId: investment.id,
      investmentNumber: investment.get('investmentNumber') || '',
      businessCaseId: String(investment.get('businessCaseId') || '').trim(),
    });
  } catch (err) {
    console.error(`❌ bookDeployToTrading (traderActivate) idempotent repair ${investment.id}:`, err.message);
  }

  return { success: true, investmentId: investment.id, status: 'active' };
}

async function handleGetPoolInvestmentsForTrader(request) {
  const user = request.user;
  if (!user) throw new Parse.Error(Parse.Error.INVALID_SESSION_TOKEN, 'Anmeldung erforderlich.');
  if (user.get('role') !== 'trader') {
    throw new Parse.Error(Parse.Error.OPERATION_FORBIDDEN, 'Trader-Rolle erforderlich.');
  }

  const { traderId } = request.params || {};
  if (!traderId || typeof traderId !== 'string') {
    throw new Parse.Error(Parse.Error.INVALID_VALUE, 'Parameter „traderId“ erforderlich.');
  }

  const q = new Parse.Query('Investment');
  q.equalTo('traderId', traderId);
  q.descending('createdAt');
  q.limit(500);
  const rows = await q.find({ useMasterKey: true });

  return {
    results: rows.map((r) => r.toJSON()),
  };
}

async function handleRecordPoolTradeParticipation(request) {
  const user = request.user;
  if (!user) throw new Parse.Error(Parse.Error.INVALID_SESSION_TOKEN, 'Anmeldung erforderlich.');
  if (user.get('role') !== 'trader') {
    throw new Parse.Error(Parse.Error.OPERATION_FORBIDDEN, 'Trader-Rolle erforderlich.');
  }

  const {
    tradeId,
    investmentId,
    poolReservationId,
    poolNumber,
    allocatedAmount,
    totalTradeValue,
    ownershipPercentage,
    profitShare = null,
  } = request.params || {};

  if (!tradeId || !investmentId) {
    throw new Parse.Error(Parse.Error.INVALID_VALUE, 'tradeId und investmentId sind erforderlich.');
  }

  const existing = await new Parse.Query('PoolTradeParticipation')
    .equalTo('tradeId', tradeId)
    .equalTo('investmentId', investmentId)
    .first({ useMasterKey: true });

  const PoolParticipation = Parse.Object.extend('PoolTradeParticipation');
  const row = existing || new PoolParticipation();
  row.set('tradeId', tradeId);
  row.set('investmentId', investmentId);
  if (poolReservationId) row.set('poolReservationId', poolReservationId);
  if (Number.isFinite(poolNumber)) row.set('poolNumber', poolNumber);
  if (Number.isFinite(allocatedAmount)) row.set('allocatedAmount', allocatedAmount);
  if (Number.isFinite(totalTradeValue)) row.set('totalTradeValue', totalTradeValue);
  if (Number.isFinite(ownershipPercentage)) row.set('ownershipPercentage', ownershipPercentage);
  row.set('isSettled', Number.isFinite(profitShare));
  if (Number.isFinite(profitShare)) row.set('profitShare', profitShare);

  await row.save(null, { useMasterKey: true });
  return row.toJSON();
}

async function handleUpdatePoolTradeParticipation(request) {
  const user = request.user;
  if (!user) throw new Parse.Error(Parse.Error.INVALID_SESSION_TOKEN, 'Anmeldung erforderlich.');
  if (user.get('role') !== 'trader') {
    throw new Parse.Error(Parse.Error.OPERATION_FORBIDDEN, 'Trader-Rolle erforderlich.');
  }

  const { participationId, ...payload } = request.params || {};
  if (!participationId) {
    throw new Parse.Error(Parse.Error.INVALID_VALUE, 'participationId ist erforderlich.');
  }

  const row = await new Parse.Query('PoolTradeParticipation').get(participationId, { useMasterKey: true });
  if (Number.isFinite(payload.allocatedAmount)) row.set('allocatedAmount', payload.allocatedAmount);
  if (Number.isFinite(payload.totalTradeValue)) row.set('totalTradeValue', payload.totalTradeValue);
  if (Number.isFinite(payload.ownershipPercentage)) row.set('ownershipPercentage', payload.ownershipPercentage);
  if (payload.poolReservationId) row.set('poolReservationId', payload.poolReservationId);
  if (Number.isFinite(payload.poolNumber)) row.set('poolNumber', payload.poolNumber);
  if (Number.isFinite(payload.profitShare)) {
    row.set('profitShare', payload.profitShare);
    row.set('isSettled', true);
  }

  await row.save(null, { useMasterKey: true });
  return row.toJSON();
}

module.exports = {
  handleTraderActivateReservedInvestment,
  handleGetPoolInvestmentsForTrader,
  handleRecordPoolTradeParticipation,
  handleUpdatePoolTradeParticipation,
};
