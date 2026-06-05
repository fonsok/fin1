'use strict';

const { newBusinessCaseId } = require('../utils/accountingHelper/businessCaseId');
const { generateSequentialNumber, generateInvestorInvestmentNumber } = require('../utils/helpers');
const { getAppServiceChargeRateForAccountType, loadConfig } = require('../utils/configHelper/index.js');
const { round2 } = require('../utils/accountingHelper/shared');
const { validateInvestmentAmountAgainstLimits } = require('../utils/investmentLimitsValidation');
const { validatePoolMirrorReservationCapacity } = require('../utils/poolMirrorBuyCap');
const { isBatchPoolCapValidated } = require('../utils/investmentBatchContext');
const { assertNoDuplicateInvestmentSplit } = require('./investmentDuplicateGuard');
const { resolveCanonicalUserId } = require('../utils/canonicalUserId');
const {
  runPendingSchemaMigrations,
} = require('../utils/schemaMigration/schemaMigrationRunner');

/**
 * GoB: Schema-Migrationen (`SchemaMigration`-Audit) müssen vor Client-Saves mit
 * neuen Feldern (z. B. `feeConfigSnapshot`) durchlaufen — sonst CLP `addField`.
 *
 * Lazy: einmal pro Prozess.
 */
let schemaMigrationEnsurePromise = null;
function ensureSchemaMigrationsOnce() {
  if (!schemaMigrationEnsurePromise) {
    schemaMigrationEnsurePromise = runPendingSchemaMigrations({ stopOnError: false })
      .then((r) => ({ ok: Boolean(r && r.ok), result: r }))
      .catch((err) => {
        schemaMigrationEnsurePromise = null;
        return { ok: false, error: err && err.message ? err.message : String(err) };
      });
  }
  return schemaMigrationEnsurePromise;
}

Parse.Cloud.beforeSave('Investment', async (request) => {
  const investment = request.object;
  const isNew = !investment.existed();

  const rawInvestorId = String(investment.get('investorId') || '').trim();
  const rawTraderId = String(investment.get('traderId') || '').trim();
  if (rawInvestorId || rawTraderId) {
    const [canonicalInvestorId, canonicalTraderId] = await Promise.all([
      rawInvestorId ? resolveCanonicalUserId(rawInvestorId) : Promise.resolve(''),
      rawTraderId ? resolveCanonicalUserId(rawTraderId) : Promise.resolve(''),
    ]);
    if (canonicalInvestorId) investment.set('investorId', canonicalInvestorId);
    if (canonicalTraderId) investment.set('traderId', canonicalTraderId);
  }

  const statusForReservation = String(investment.get('status') || '').trim();
  if (!investment.get('reservationStatus') && statusForReservation) {
    if (statusForReservation === 'reserved') {
      investment.set('reservationStatus', 'reserved');
    } else if (statusForReservation === 'active' || statusForReservation === 'executing') {
      investment.set('reservationStatus', 'active');
    } else if (statusForReservation === 'completed') {
      investment.set('reservationStatus', 'completed');
    } else if (statusForReservation === 'cancelled') {
      investment.set('reservationStatus', 'cancelled');
    }
  }

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

    const batchIdForCap = String(investment.get('batchId') || '').trim();
    const skipPerSplitPoolCap = batchIdForCap
      && isBatchPoolCapValidated(investorId, batchIdForCap);
    if (!skipPerSplitPoolCap) {
      const poolCapCheck = await validatePoolMirrorReservationCapacity(traderId, amount);
      if (!poolCapCheck.valid) {
        throw new Parse.Error(Parse.Error.OPERATION_FORBIDDEN, poolCapCheck.error);
      }
    }
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

    // GoB: Handelsgebühren-Parameter (Order-/Börsen-/Fremdkosten) zum Reservierungszeitpunkt einfrieren,
    // damit Aktivierung, Collection Bill und Residual mit derselben Basis rechnen wie späteres Settlement.
    // `ensureSchemaMigrationsOnce` führt versionierte Schema-Migrationen aus (Master-Key),
    // bevor der Client-Save den CLP-`addField`-Check auslöst.
    try {
      const ensure = await ensureSchemaMigrationsOnce();
      if (ensure && ensure.ok) {
        const liveCfg = await loadConfig();
        const fin = liveCfg && liveCfg.financial ? liveCfg.financial : {};
        investment.set('feeConfigSnapshot', JSON.parse(JSON.stringify(fin)));
      } else {
        console.warn('beforeSave Investment: feeConfigSnapshot skipped (schema migrations not ok)');
      }
    } catch (err) {
      console.warn('beforeSave Investment: feeConfigSnapshot skipped:', err.message);
    }

    investment.set('status', 'reserved');
    investment.set('reservationStatus', 'reserved');
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
        const existingUsername = String(investment.get('traderUsername') || '').trim();
        if (!existingUsername) {
          const un = String(trader.get('username') || '').trim().toLowerCase();
          if (un) investment.set('traderUsername', un);
        }
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

  const { buildInvestmentSearchBlob } = require('../utils/adminListSearch');
  investment.set('adminSearchBlob', buildInvestmentSearchBlob(investment));
});
