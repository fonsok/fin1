'use strict';

/**
 * Customer-visible closing balance — same merge as `getAccountStatement` / Admin „Kundensicht“.
 * See ADR-019 Phase 3b.
 */

const { loadConfig } = require('../configHelper/index.js');
const {
  loadInvestorAccountStatementSourceData,
  buildInvestorMergedTimeline,
} = require('../investorAccountStatementMerge');
const {
  loadTraderAccountStatementSourceData,
  buildTraderCustomerTimelineForUser,
} = require('../traderAccountStatementPresentation');
const { normalizeEuro, euroToCents, withinCentsTolerance } = require('./moneyCents');
const { audit } = require('../structuredLogger');

async function loadInitialAccountBalance() {
  const liveConfig = await loadConfig(true);
  return typeof liveConfig.financial?.initialAccountBalance === 'number'
    ? liveConfig.financial.initialAccountBalance
    : 0.0;
}

/**
 * @param {import('parse/node').User} user
 * @returns {Promise<number>} cent-aligned EUR
 */
async function computeCustomerClosingBalanceForUser(user) {
  const initialBalance = await loadInitialAccountBalance();
  const role = String(user.get('role') || '').toLowerCase();
  const isTrader = role === 'trader';

  if (isTrader) {
    const { stmtEntries, invoices } = await loadTraderAccountStatementSourceData(user);
    const timeline = await buildTraderCustomerTimelineForUser({
      stmtEntries,
      invoices,
      initialBalance,
    });
    if (!timeline.length) {
      return normalizeEuro(initialBalance);
    }
    return normalizeEuro(timeline[timeline.length - 1].balanceAfter);
  }

  const { stmtEntries, avaRows } = await loadInvestorAccountStatementSourceData(user);
  const timeline = buildInvestorMergedTimeline({
    stmtEntries,
    avaRows,
    initialBalance,
  });
  if (!timeline.length) {
    return normalizeEuro(initialBalance);
  }
  return normalizeEuro(timeline[timeline.length - 1].balanceAfter);
}

/**
 * @param {string} userId Parse objectId
 */
async function computeCustomerClosingBalanceForUserId(userId) {
  const uid = String(userId || '').trim();
  if (!uid) {
    throw new Error('computeCustomerClosingBalanceForUserId: userId is required');
  }
  const user = await new Parse.Query(Parse.User).get(uid, { useMasterKey: true });
  if (!user) {
    throw new Error(`computeCustomerClosingBalanceForUserId: user not found (${uid})`);
  }
  return computeCustomerClosingBalanceForUser(user);
}

/**
 * Logs when Mongo `UserCashBalance` drifts from customer timeline (ops; does not block reads).
 * @param {string} userId
 * @param {number} storedBalance
 * @param {number} customerBalance
 */
function auditUserCashBalanceDriftIfNeeded(userId, storedBalance, customerBalance) {
  if (!Number.isFinite(Number(storedBalance))) {
    return;
  }
  const storedCents = euroToCents(storedBalance);
  const customerCents = euroToCents(customerBalance);
  if (withinCentsTolerance(storedCents, customerCents)) {
    return;
  }
  audit.warn('userCashBalance.customerTimelineDrift', {
    userId,
    storedBalance: normalizeEuro(storedBalance),
    customerBalance: normalizeEuro(customerBalance),
    deltaCents: customerCents - storedCents,
    message: 'UserCashBalance.currentBalance differs from customer merge timeline',
  });
}

module.exports = {
  loadInitialAccountBalance,
  computeCustomerClosingBalanceForUser,
  computeCustomerClosingBalanceForUserId,
  auditUserCashBalanceDriftIfNeeded,
};
