'use strict';

const { round2 } = require('../utils/accountingHelper/shared');
const {
  assessPoolMirrorCapacity,
  validatePoolMirrorReservationCapacity,
} = require('../utils/poolMirrorBuyCap');
const { createNotification } = require('../triggers/investmentTriggerHelpers');
const { loadConfig } = require('../utils/configHelper/index.js');
const { resolveTraderParseUser } = require('../utils/resolveTraderParseUser');
const { resolveCanonicalUserId } = require('../utils/canonicalUserId');

const ALERT_CLASS = 'PoolMirrorCapacityAlert';

async function findActiveAlert(investorId, traderId) {
  const q = new Parse.Query(ALERT_CLASS);
  q.equalTo('investorId', investorId);
  q.equalTo('traderId', traderId);
  q.equalTo('isActive', true);
  return q.first({ useMasterKey: true });
}

async function handleGetPoolMirrorCapacity(request) {
  const user = request.user;
  if (!user) throw new Parse.Error(Parse.Error.INVALID_SESSION_TOKEN, 'Anmeldung erforderlich.');

  const { traderId, traderUsername, traderName, additionalAmount } = request.params || {};
  if ((!traderId || typeof traderId !== 'string') && !traderUsername) {
    throw new Parse.Error(Parse.Error.INVALID_VALUE, 'Parameter „traderId“ oder „traderUsername“ erforderlich.');
  }

  const trader = await resolveTraderParseUser(
    { traderId, traderUsername, traderDisplayName: traderName },
    Parse,
  );
  if (!trader) {
    throw new Parse.Error(Parse.Error.OBJECT_NOT_FOUND, 'Trader nicht gefunden oder nicht aktiv.');
  }
  const resolvedTraderId = await resolveCanonicalUserId(trader.id);

  const capacity = await assessPoolMirrorCapacity(resolvedTraderId, {
    additionalAmount: additionalAmount != null ? Number(additionalAmount) : 0,
  });

  const alert = await findActiveAlert(user.id, resolvedTraderId);

  return {
    ...capacity,
    resolvedTraderId,
    alertSubscribed: Boolean(alert),
    alertId: alert?.id || null,
  };
}

async function handleSetPoolMirrorCapacityAlert(request) {
  const user = request.user;
  if (!user) throw new Parse.Error(Parse.Error.INVALID_SESSION_TOKEN, 'Anmeldung erforderlich.');
  if (user.get('role') !== 'investor') {
    throw new Parse.Error(Parse.Error.OPERATION_FORBIDDEN, 'Nur für Investoren verfügbar.');
  }

  const { traderId, traderUsername, traderName, enabled } = request.params || {};
  if ((!traderId || typeof traderId !== 'string') && !traderUsername) {
    throw new Parse.Error(Parse.Error.INVALID_VALUE, 'Parameter „traderId“ oder „traderUsername“ erforderlich.');
  }
  const trader = await resolveTraderParseUser(
    { traderId, traderUsername, traderDisplayName: traderName },
    Parse,
  );
  if (!trader) {
    throw new Parse.Error(Parse.Error.OBJECT_NOT_FOUND, 'Trader nicht gefunden oder nicht aktiv.');
  }
  const resolvedTraderId = await resolveCanonicalUserId(trader.id);
  const wantActive = enabled === true || enabled === 'true' || enabled === 1;

  const Alert = Parse.Object.extend(ALERT_CLASS);
  let row = await findActiveAlert(user.id, resolvedTraderId);

  if (wantActive) {
    if (!row) {
      row = new Alert();
      row.set('investorId', user.id);
      row.set('traderId', resolvedTraderId);
    }
    row.set('isActive', true);
    row.unset('notifiedAt');
    await row.save(null, { useMasterKey: true });
    return { success: true, subscribed: true, alertId: row.id };
  }

  if (row) {
    row.set('isActive', false);
    await row.save(null, { useMasterKey: true });
  }
  return { success: true, subscribed: false, alertId: row?.id || null };
}

/**
 * Notify investors who subscribed when pool queue has capacity again.
 * @param {string} traderId
 */
async function notifyPoolMirrorCapacityAvailable(traderId) {
  const tid = String(traderId || '').trim();
  if (!tid) return { notified: 0 };

  const config = await loadConfig(true);
  const capacity = await assessPoolMirrorCapacity(tid, { config });
  if (!capacity.capEnabled || capacity.isFull) {
    return { notified: 0, skipped: 'still_full_or_disabled' };
  }

  const minInv = Number(config.limits?.minInvestment) || 20;
  if ((capacity.remainingCapacity || 0) < minInv) {
    return { notified: 0, skipped: 'remaining_below_min_investment' };
  }

  const q = new Parse.Query(ALERT_CLASS);
  q.equalTo('traderId', tid);
  q.equalTo('isActive', true);
  q.limit(500);
  const alerts = await q.find({ useMasterKey: true });
  if (!alerts.length) return { notified: 0 };

  const remainingLabel = new Intl.NumberFormat('de-DE', { style: 'currency', currency: 'EUR' })
    .format(capacity.remainingCapacity || 0);

  let notified = 0;
  for (const alert of alerts) {
    const investorId = alert.get('investorId');
    if (!investorId) continue;
    const lastNotified = alert.get('notifiedAt');
    if (lastNotified && Date.now() - new Date(lastNotified).getTime() < 60_000) {
      continue;
    }

    await createNotification(
      investorId,
      'pool_mirror_capacity_available',
      'investment',
      'Investment wieder möglich',
      `Bei Ihrem Trader steht für das nächste Trade wieder Kapital im Pool-Mirror zur Verfügung (ca. ${remainingLabel}).`,
      'high',
    );

    alert.set('notifiedAt', new Date());
    await alert.save(null, { useMasterKey: true });
    notified += 1;
  }

  return { notified };
}

module.exports = {
  handleGetPoolMirrorCapacity,
  handleSetPoolMirrorCapacityAlert,
  notifyPoolMirrorCapacityAvailable,
  validatePoolMirrorReservationCapacity,
};
