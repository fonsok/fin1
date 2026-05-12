'use strict';

const { newBusinessCaseId } = require('../utils/accountingHelper/businessCaseId');
const { generateSequentialNumber, generateInvestorInvestmentNumber } = require('../utils/helpers');
const { getAppServiceChargeRateForAccountType } = require('../utils/configHelper/index.js');
const { round2 } = require('../utils/accountingHelper/shared');
const { validateInvestmentAmountAgainstLimits } = require('../utils/investmentLimitsValidation');
const { assertNoDuplicateInvestmentSplit } = require('./investmentDuplicateGuard');

Parse.Cloud.beforeSave('Investment', async (request) => {
  const investment = request.object;
  const isNew = !investment.existed();

  if (isNew) {
    await assertNoDuplicateInvestmentSplit(investment, Parse);

    if (!investment.get('businessCaseId')) {
      investment.set('businessCaseId', newBusinessCaseId());
    }

    if (!investment.get('investmentNumber')) {
      const investorIdForNumber = String(investment.get('investorId') || '').trim();
      const investmentNumber = investorIdForNumber
        ? await generateInvestorInvestmentNumber(investorIdForNumber)
        : await generateSequentialNumber('INV', 'Investment', 'investmentNumber');
      investment.set('investmentNumber', investmentNumber);
    }

    const amount = investment.get('amount');
    const limitCheck = await validateInvestmentAmountAgainstLimits(amount);
    if (!limitCheck.valid) {
      throw new Parse.Error(Parse.Error.INVALID_VALUE, limitCheck.error);
    }

    const investorId = investment.get('investorId');
    const traderId = investment.get('traderId');
    if (investorId === traderId) {
      throw new Parse.Error(Parse.Error.INVALID_VALUE,
        'Investoren können nicht im eigenen Pool investieren.');
    }

    // ADR-007: App Service Charge is billed via Invoice/service_charge (+ AppLedger),
    // not by reducing investment notional — keep initialValue/currentValue == amount.
    const accountType = ((request.user && request.user.get('accountType')) || 'individual');
    const configuredRate = await getAppServiceChargeRateForAccountType(accountType);
    const serviceChargeRate = investment.get('serviceChargeRate') || configuredRate;
    const isCompany = String(accountType).toLowerCase() === 'company';
    const grossCharge = round2(amount * serviceChargeRate);
    const serviceChargeNet = isCompany ? grossCharge : round2(grossCharge / 1.19);
    const serviceChargeVat = isCompany ? 0 : round2(grossCharge - serviceChargeNet);

    investment.set('serviceChargeRate', serviceChargeRate);
    investment.set('serviceChargeAmount', serviceChargeNet);
    investment.set('serviceChargeVat', serviceChargeVat);
    investment.set('serviceChargeTotal', round2(serviceChargeNet + serviceChargeVat));
    investment.set('initialValue', amount);
    investment.set('currentValue', amount);

    investment.set('status', 'reserved');
    investment.set('profit', 0);
    investment.set('profitPercentage', 0);
    investment.set('totalCommissionPaid', 0);
    investment.set('numberOfTrades', 0);
    investment.set('reservedAt', new Date());

    const expiresAt = new Date();
    expiresAt.setHours(expiresAt.getHours() + 24);
    investment.set('reservationExpiresAt', expiresAt);

    try {
      const traderQuery = new Parse.Query(Parse.User);
      const trader = await traderQuery.get(traderId, { useMasterKey: true });
      if (trader) {
        const profileQuery = new Parse.Query('UserProfile');
        profileQuery.equalTo('userId', traderId);
        const profile = await profileQuery.first({ useMasterKey: true });

        if (profile) {
          investment.set('traderName', `${profile.get('firstName')} ${profile.get('lastName').charAt(0)}.`);
        }
      }
    } catch (err) {
      console.warn('beforeSave Investment: trader snapshot skipped:', err.message);
    }
  }

  if (!isNew && request.original) {
    const oldStatus = request.original.get('status');
    const newStatus = investment.get('status');

    const validTransitions = {
      reserved: ['active', 'completed', 'cancelled'],
      active: ['executing', 'paused', 'closing', 'completed', 'cancelled'],
      executing: ['active', 'paused', 'completed'],
      paused: ['active', 'closing', 'cancelled'],
      closing: ['completed'],
      completed: [],
      cancelled: [],
    };

    if (oldStatus !== newStatus) {
      const allowed = validTransitions[oldStatus] || [];
      if (!allowed.includes(newStatus)) {
        throw new Parse.Error(Parse.Error.INVALID_VALUE,
          `Ungültiger Statuswechsel von „${oldStatus}“ zu „${newStatus}“.`);
      }

      if (newStatus === 'active') {
        investment.set('activatedAt', new Date().toISOString());
        investment.set('reservationStatus', 'active');
      } else if (newStatus === 'completed') {
        investment.set('completedAt', new Date().toISOString());
        investment.set('reservationStatus', 'completed');
      } else if (newStatus === 'cancelled') {
        investment.set('cancelledAt', new Date().toISOString());
        investment.set('reservationStatus', 'cancelled');
      }
    }
  }
});
