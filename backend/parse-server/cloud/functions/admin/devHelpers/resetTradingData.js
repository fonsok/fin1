'use strict';

const { requireAdminRole } = require('../../../utils/permissions');
const { getInitialAccountBalance } = require('../../../utils/configHelper/index.js');
const { round2 } = require('../../../utils/accountingHelper/shared');
const {
  envTrue,
  writeDevMaintenanceAudit,
  countAll,
  destroyAllInBatches,
  destroyParseObjectsTolerant,
  runWithDevTradingDataResetDestroy,
} = require('./shared');

/**
 * One completed deposit per investor/trader so getWalletBalance matches Configuration.initialAccountBalance.
 * Two-step save (pending → completed) so WalletTransaction afterSave runs GoB receipt + AccountStatement.
 */
async function seedInitialBalancesFromConfig() {
  const amount = round2(Number(await getInitialAccountBalance()) || 0);
  if (amount <= 0) {
    return {
      amountPerUser: 0,
      seededUsers: 0,
      note: 'initialAccountBalance is 0 — no wallet rows created.',
    };
  }

  const userQuery = new Parse.Query(Parse.User);
  userQuery.containedIn('role', ['investor', 'trader']);
  userQuery.limit(1000);
  const users = await userQuery.find({ useMasterKey: true });

  const WalletTransaction = Parse.Object.extend('WalletTransaction');
  let seededUsers = 0;
  const errors = [];

  for (const u of users) {
    const uid = u.id;
    try {
      const tx = new WalletTransaction();
      tx.set('userId', uid);
      tx.set('transactionType', 'deposit');
      tx.set('amount', amount);
      tx.set('status', 'pending');
      tx.set('description', `Startguthaben (Konfiguration initialAccountBalance) nach DEV-Reset`);
      await tx.save(null, { useMasterKey: true });
      tx.set('status', 'completed');
      await tx.save(null, { useMasterKey: true });
      seededUsers += 1;
    } catch (err) {
      errors.push({ userId: uid, message: err.message || String(err) });
    }
  }

  return {
    amountPerUser: amount,
    seededUsers,
    eligibleUsers: users.length,
    errors: errors.length ? errors : undefined,
  };
}

function registerDevResetTradingDataFunctions() {
  Parse.Cloud.define('devResetTradingTestData', async (request) => {
    requireAdminRole(request);

    const nodeEnv = String(process.env.NODE_ENV || '').toLowerCase();
    const enabled = envTrue('ALLOW_DEV_TRADING_RESET');
    const allowInProd = envTrue('ALLOW_DEV_TRADING_RESET_IN_PRODUCTION');

    if (!enabled) {
      throw new Parse.Error(Parse.Error.OPERATION_FORBIDDEN, 'DEV reset disabled (ALLOW_DEV_TRADING_RESET=false).');
    }
    if (nodeEnv === 'production' && !allowInProd) {
      throw new Parse.Error(
        Parse.Error.OPERATION_FORBIDDEN,
        'DEV reset blocked in production (set ALLOW_DEV_TRADING_RESET_IN_PRODUCTION=true to override).'
      );
    }

    const {
      dryRun = true,
      scope = 'all',
      sinceHours = 24,
      testEmailDomain = '@test.com',
      testUserIdPrefix = 'user:',
      testUsernames = ['investor1', 'investor2', 'investor3', 'investor4', 'investor5', 'trader1', 'trader2', 'trader3'],
      /** When false, wallet stays empty after reset (only if dryRun=false). Default: apply active Configuration.initialAccountBalance. */
      reseedInitialBalance = true,
    } = request.params || {};

    const normalizedScope = String(scope || 'all');
    const normalizedSinceHours = Number(sinceHours);
    if (!['all', 'sinceHours', 'testUsers'].includes(normalizedScope)) {
      throw new Parse.Error(Parse.Error.INVALID_VALUE, 'scope must be one of: all, sinceHours, testUsers');
    }
    if (normalizedScope === 'sinceHours' && (!Number.isFinite(normalizedSinceHours) || normalizedSinceHours <= 0)) {
      throw new Parse.Error(Parse.Error.INVALID_VALUE, 'sinceHours must be a positive number');
    }

    const sinceDate = normalizedScope === 'sinceHours'
      ? new Date(Date.now() - normalizedSinceHours * 60 * 60 * 1000)
      : null;

    async function findTestUserIds() {
      const usernameList = Array.isArray(testUsernames)
        ? testUsernames.map(String).map((s) => s.trim()).filter(Boolean)
        : [];

      const queries = [];

      if (usernameList.length) {
        const qUsernames = new Parse.Query(Parse.User);
        qUsernames.containedIn('username', usernameList);
        qUsernames.limit(1000);
        queries.push(qUsernames);
      }

      const domain = String(testEmailDomain || '').trim();
      if (domain) {
        const qEmail = new Parse.Query(Parse.User);
        qEmail.matches('email', `${domain.replace('.', '\\.')}$`, 'i');
        qEmail.limit(1000);
        queries.push(qEmail);
      }

      if (!queries.length) return [];

      const users = queries.length === 1
        ? await queries[0].find({ useMasterKey: true })
        : await Parse.Query.or(...queries).find({ useMasterKey: true });

      return users.map((u) => u.id);
    }

    async function collectTargetIds() {
      if (normalizedScope === 'all') {
        return {
          tradeIds: null,
          orderIds: null,
          investmentIds: null,
          holdingIds: null,
          investmentBatchIds: null,
          userIds: null,
        };
      }

      if (normalizedScope === 'sinceHours' && sinceDate) {
        const trades = await new Parse.Query('Trade').greaterThanOrEqualTo('createdAt', sinceDate).limit(1000).find({ useMasterKey: true });
        const orders = await new Parse.Query('Order').greaterThanOrEqualTo('createdAt', sinceDate).limit(1000).find({ useMasterKey: true });
        const investments = await new Parse.Query('Investment').greaterThanOrEqualTo('createdAt', sinceDate).limit(1000).find({ useMasterKey: true });
        const holdings = await new Parse.Query('Holding').greaterThanOrEqualTo('createdAt', sinceDate).limit(1000).find({ useMasterKey: true });
        const batches = await new Parse.Query('InvestmentBatch').greaterThanOrEqualTo('createdAt', sinceDate).limit(1000).find({ useMasterKey: true });
        return {
          tradeIds: trades.map((t) => t.id),
          orderIds: orders.map((o) => o.id),
          investmentIds: investments.map((i) => i.id),
          holdingIds: holdings.map((h) => h.id),
          investmentBatchIds: batches.map((b) => b.id),
          userIds: null,
        };
      }

      const realUserIds = await findTestUserIds();
      const usernameList = Array.isArray(testUsernames)
        ? testUsernames.map(String).map((s) => s.trim()).filter(Boolean)
        : [];

      const qTrade = new Parse.Query('Trade');
      qTrade.matches('traderId', `^${String(testUserIdPrefix || 'user:')}`, 'i');
      const qTrade2 = new Parse.Query('Trade');
      qTrade2.containedIn('traderId', realUserIds);
      const qTrade3 = new Parse.Query('Trade');
      if (usernameList.length) qTrade3.containedIn('traderId', usernameList);
      const trades = await Parse.Query.or(qTrade, qTrade2, qTrade3).limit(1000).find({ useMasterKey: true });

      const qOrder = new Parse.Query('Order');
      qOrder.matches('traderId', `^${String(testUserIdPrefix || 'user:')}`, 'i');
      const qOrder2 = new Parse.Query('Order');
      qOrder2.containedIn('traderId', realUserIds);
      const qOrder3 = new Parse.Query('Order');
      if (usernameList.length) qOrder3.containedIn('traderId', usernameList);
      const orders = await Parse.Query.or(qOrder, qOrder2, qOrder3).limit(1000).find({ useMasterKey: true });

      const qInv = new Parse.Query('Investment');
      qInv.matches('investorId', `^${String(testUserIdPrefix || 'user:')}`, 'i');
      const qInv2 = new Parse.Query('Investment');
      qInv2.containedIn('investorId', realUserIds);
      const qInv3 = new Parse.Query('Investment');
      if (usernameList.length) qInv3.containedIn('investorId', usernameList);
      const investments = await Parse.Query.or(qInv, qInv2, qInv3).limit(1000).find({ useMasterKey: true });

      const qHold = new Parse.Query('Holding');
      qHold.matches('traderId', `^${String(testUserIdPrefix || 'user:')}`, 'i');
      const qHold2 = new Parse.Query('Holding');
      qHold2.containedIn('traderId', realUserIds);
      const qHold3 = new Parse.Query('Holding');
      if (usernameList.length) qHold3.containedIn('traderId', usernameList);
      const holdings = await Parse.Query.or(qHold, qHold2, qHold3).limit(1000).find({ useMasterKey: true });

      const qBatch = new Parse.Query('InvestmentBatch');
      qBatch.matches('investorId', `^${String(testUserIdPrefix || 'user:')}`, 'i');
      const qBatch2 = new Parse.Query('InvestmentBatch');
      qBatch2.containedIn('investorId', realUserIds);
      const qBatch3 = new Parse.Query('InvestmentBatch');
      if (usernameList.length) qBatch3.containedIn('investorId', usernameList);
      const invBatches = await Parse.Query.or(qBatch, qBatch2, qBatch3).limit(1000).find({ useMasterKey: true });

      return {
        tradeIds: trades.map((t) => t.id),
        orderIds: orders.map((o) => o.id),
        investmentIds: investments.map((i) => i.id),
        holdingIds: holdings.map((h) => h.id),
        investmentBatchIds: invBatches.map((b) => b.id),
        userIds: realUserIds,
      };
    }

    const targets = await collectTargetIds();

    const classesToWipe = [
      'PoolTradeParticipation',
      'Commission',
      'AccountStatement',
      'Document',
      'Invoice',
      'Order',
      'Holding',
      'Trade',
      'WalletTransaction',
      'Investment',
      'InvestmentBatch',
      'BankContraPosting',
      'AppLedgerEntry',
      'Notification',
      'ComplianceEvent',
    ];

    function hasTargets() {
      if (normalizedScope === 'all') return true;
      return (targets.tradeIds?.length || 0) > 0
        || (targets.orderIds?.length || 0) > 0
        || (targets.investmentIds?.length || 0) > 0
        || (targets.holdingIds?.length || 0) > 0
        || (targets.investmentBatchIds?.length || 0) > 0
        || (targets.userIds?.length || 0) > 0;
    }

    async function countScoped(cls) {
      if (normalizedScope === 'all') return countAll(cls);
      if (!hasTargets()) return 0;

      const q = new Parse.Query(cls);
      if (sinceDate) q.greaterThanOrEqualTo('createdAt', sinceDate);

      if (cls === 'Trade' && targets.tradeIds) q.containedIn('objectId', targets.tradeIds);
      else if (cls === 'Order' && targets.orderIds) q.containedIn('objectId', targets.orderIds);
      else if (cls === 'Holding' && targets.holdingIds) q.containedIn('objectId', targets.holdingIds);
      else if (cls === 'Investment' && targets.investmentIds) q.containedIn('objectId', targets.investmentIds);
      else if (cls === 'InvestmentBatch' && targets.investmentBatchIds) q.containedIn('objectId', targets.investmentBatchIds);
      else if (cls === 'PoolTradeParticipation') {
        const ors = [];
        if (targets.tradeIds?.length) {
          const q1 = new Parse.Query(cls);
          q1.containedIn('tradeId', targets.tradeIds);
          if (sinceDate) q1.greaterThanOrEqualTo('createdAt', sinceDate);
          ors.push(q1);
        }
        if (targets.investmentIds?.length) {
          const q2 = new Parse.Query(cls);
          q2.containedIn('investmentId', targets.investmentIds);
          if (sinceDate) q2.greaterThanOrEqualTo('createdAt', sinceDate);
          ors.push(q2);
        }
        return ors.length ? Parse.Query.or(...ors).count({ useMasterKey: true }) : 0;
      } else if (cls === 'Commission') {
        if (targets.tradeIds?.length) q.containedIn('tradeId', targets.tradeIds);
        else return 0;
      } else if (cls === 'AccountStatement') {
        const ors = [];
        if (targets.tradeIds?.length) {
          const q1 = new Parse.Query(cls);
          q1.containedIn('tradeId', targets.tradeIds);
          if (sinceDate) q1.greaterThanOrEqualTo('createdAt', sinceDate);
          ors.push(q1);
        }
        if (targets.userIds?.length) {
          const q2 = new Parse.Query(cls);
          q2.containedIn('userId', targets.userIds);
          if (sinceDate) q2.greaterThanOrEqualTo('createdAt', sinceDate);
          ors.push(q2);
        }
        return ors.length ? Parse.Query.or(...ors).count({ useMasterKey: true }) : 0;
      } else if (cls === 'Document') {
        const ors = [];
        if (targets.tradeIds?.length) {
          const q1 = new Parse.Query(cls);
          q1.containedIn('tradeId', targets.tradeIds);
          if (sinceDate) q1.greaterThanOrEqualTo('createdAt', sinceDate);
          ors.push(q1);
        }
        if (targets.investmentIds?.length) {
          const q2 = new Parse.Query(cls);
          q2.containedIn('investmentId', targets.investmentIds);
          if (sinceDate) q2.greaterThanOrEqualTo('createdAt', sinceDate);
          ors.push(q2);
        }
        if (targets.userIds?.length) {
          const q3 = new Parse.Query(cls);
          q3.containedIn('userId', targets.userIds);
          if (sinceDate) q3.greaterThanOrEqualTo('createdAt', sinceDate);
          ors.push(q3);
        }
        return ors.length ? Parse.Query.or(...ors).count({ useMasterKey: true }) : 0;
      } else if (cls === 'Invoice') {
        const ors = [];
        if (targets.tradeIds?.length) {
          const q1 = new Parse.Query(cls);
          q1.containedIn('tradeId', targets.tradeIds);
          if (sinceDate) q1.greaterThanOrEqualTo('createdAt', sinceDate);
          ors.push(q1);
        }
        if (targets.orderIds?.length) {
          const q2 = new Parse.Query(cls);
          q2.containedIn('orderId', targets.orderIds);
          if (sinceDate) q2.greaterThanOrEqualTo('createdAt', sinceDate);
          ors.push(q2);
        }
        if (targets.userIds?.length) {
          const q3 = new Parse.Query(cls);
          q3.containedIn('userId', targets.userIds);
          if (sinceDate) q3.greaterThanOrEqualTo('createdAt', sinceDate);
          ors.push(q3);
        }
        return ors.length ? Parse.Query.or(...ors).count({ useMasterKey: true }) : 0;
      } else if (cls === 'WalletTransaction') {
        if (targets.userIds?.length) q.containedIn('userId', targets.userIds);
        else return 0;
      } else if (cls === 'BankContraPosting') {
        if (targets.userIds?.length) q.containedIn('investorId', targets.userIds);
        else return 0;
      } else if (cls === 'AppLedgerEntry') {
        if (targets.userIds?.length) q.containedIn('userId', targets.userIds);
        else return 0;
      } else if (cls === 'Notification' || cls === 'ComplianceEvent') {
        if (targets.userIds?.length) q.containedIn('userId', targets.userIds);
        else return 0;
      }

      return q.count({ useMasterKey: true });
    }

    async function destroyScoped(cls) {
      if (normalizedScope === 'all') return destroyAllInBatches(cls, { batchSize: 500 });
      if (!hasTargets()) return 0;

      async function destroyByQuery(query) {
        query.limit(500);
        let deleted = 0;
        // eslint-disable-next-line no-constant-condition
        while (true) {
          const batch = await query.find({ useMasterKey: true });
          if (!batch || batch.length === 0) break;
          const n = await destroyParseObjectsTolerant(batch);
          deleted += n;
          if (n === 0) {
            console.warn(`devReset: destroyScoped destroyByQuery: batch of ${batch.length} undeletable — stop loop.`);
            break;
          }
        }
        return deleted;
      }

      const mkBase = () => {
        const q = new Parse.Query(cls);
        if (sinceDate) q.greaterThanOrEqualTo('createdAt', sinceDate);
        return q;
      };

      if (cls === 'Trade') {
        if (!targets.tradeIds?.length) return 0;
        const q = mkBase();
        q.containedIn('objectId', targets.tradeIds);
        return destroyByQuery(q);
      }
      if (cls === 'Order') {
        if (!targets.orderIds?.length) return 0;
        const q = mkBase();
        q.containedIn('objectId', targets.orderIds);
        return destroyByQuery(q);
      }
      if (cls === 'Holding') {
        if (!targets.holdingIds?.length) return 0;
        const q = mkBase();
        q.containedIn('objectId', targets.holdingIds);
        return destroyByQuery(q);
      }
      if (cls === 'Investment') {
        if (!targets.investmentIds?.length) return 0;
        const q = mkBase();
        q.containedIn('objectId', targets.investmentIds);
        return destroyByQuery(q);
      }
      if (cls === 'InvestmentBatch') {
        if (!targets.investmentBatchIds?.length) return 0;
        const q = mkBase();
        q.containedIn('objectId', targets.investmentBatchIds);
        return destroyByQuery(q);
      }
      if (cls === 'PoolTradeParticipation') {
        const ors = [];
        if (targets.tradeIds?.length) {
          const q1 = mkBase();
          q1.containedIn('tradeId', targets.tradeIds);
          ors.push(q1);
        }
        if (targets.investmentIds?.length) {
          const q2 = mkBase();
          q2.containedIn('investmentId', targets.investmentIds);
          ors.push(q2);
        }
        if (!ors.length) return 0;
        return destroyByQuery(ors.length === 1 ? ors[0] : Parse.Query.or(...ors));
      }
      if (cls === 'Commission') {
        if (!targets.tradeIds?.length) return 0;
        const q = mkBase();
        q.containedIn('tradeId', targets.tradeIds);
        return destroyByQuery(q);
      }
      if (cls === 'AccountStatement') {
        const ors = [];
        if (targets.tradeIds?.length) {
          const q1 = mkBase();
          q1.containedIn('tradeId', targets.tradeIds);
          ors.push(q1);
        }
        if (targets.userIds?.length) {
          const q2 = mkBase();
          q2.containedIn('userId', targets.userIds);
          ors.push(q2);
        }
        if (!ors.length) return 0;
        return destroyByQuery(ors.length === 1 ? ors[0] : Parse.Query.or(...ors));
      }
      if (cls === 'Document') {
        const ors = [];
        if (targets.tradeIds?.length) {
          const q1 = mkBase();
          q1.containedIn('tradeId', targets.tradeIds);
          ors.push(q1);
        }
        if (targets.investmentIds?.length) {
          const q2 = mkBase();
          q2.containedIn('investmentId', targets.investmentIds);
          ors.push(q2);
        }
        if (targets.userIds?.length) {
          const q3 = mkBase();
          q3.containedIn('userId', targets.userIds);
          ors.push(q3);
        }
        if (!ors.length) return 0;
        return destroyByQuery(ors.length === 1 ? ors[0] : Parse.Query.or(...ors));
      }
      if (cls === 'Invoice') {
        const ors = [];
        if (targets.tradeIds?.length) {
          const q1 = mkBase();
          q1.containedIn('tradeId', targets.tradeIds);
          ors.push(q1);
        }
        if (targets.orderIds?.length) {
          const q2 = mkBase();
          q2.containedIn('orderId', targets.orderIds);
          ors.push(q2);
        }
        if (targets.userIds?.length) {
          const q3 = mkBase();
          q3.containedIn('userId', targets.userIds);
          ors.push(q3);
        }
        if (!ors.length) return 0;
        return destroyByQuery(ors.length === 1 ? ors[0] : Parse.Query.or(...ors));
      }
      if (cls === 'WalletTransaction') {
        if (!targets.userIds?.length) return 0;
        const q = mkBase();
        q.containedIn('userId', targets.userIds);
        return destroyByQuery(q);
      }
      if (cls === 'BankContraPosting') {
        if (!targets.userIds?.length) return 0;
        const q = mkBase();
        q.containedIn('investorId', targets.userIds);
        return destroyByQuery(q);
      }
      if (cls === 'AppLedgerEntry') {
        if (!targets.userIds?.length) return 0;
        const q = mkBase();
        q.containedIn('userId', targets.userIds);
        return destroyByQuery(q);
      }
      if (cls === 'Notification' || cls === 'ComplianceEvent') {
        if (!targets.userIds?.length) return 0;
        const q = mkBase();
        q.containedIn('userId', targets.userIds);
        return destroyByQuery(q);
      }

      if (sinceDate) {
        const q = mkBase();
        return destroyByQuery(q);
      }
      return 0;
    }

    const counts = {};
    for (const cls of classesToWipe) {
      counts[cls] = await countScoped(cls);
    }

    const initialBalPreview = round2(Number(await getInitialAccountBalance()) || 0);
    let investorTraderCount = 0;
    if (reseedInitialBalance && initialBalPreview > 0) {
      const cq = new Parse.Query(Parse.User);
      cq.containedIn('role', ['investor', 'trader']);
      investorTraderCount = await cq.count({ useMasterKey: true });
    }

    if (dryRun) {
      const result = {
        dryRun: true,
        nodeEnv,
        scope: normalizedScope,
        sinceHours: normalizedScope === 'sinceHours' ? normalizedSinceHours : undefined,
        testEmailDomain: normalizedScope === 'testUsers' ? String(testEmailDomain || '') : undefined,
        testUserIdPrefix: normalizedScope === 'testUsers' ? String(testUserIdPrefix || '') : undefined,
        counts,
        willDeleteTotal: Object.values(counts).reduce((a, b) => a + (b || 0), 0),
        reseedInitialBalance: !!reseedInitialBalance,
        configInitialAccountBalance: initialBalPreview,
        wouldSeedWalletDeposits: reseedInitialBalance && initialBalPreview > 0 ? investorTraderCount : 0,
        note: 'Dry-run only. Set dryRun=false to execute. Templates/legal/config are preserved. After execute, each investor/trader gets one completed deposit = active Configuration.initialAccountBalance (unless reseedInitialBalance=false).',
      };
      await writeDevMaintenanceAudit({
        action: 'dev_reset_trading_test_data_dry_run',
        request,
        payload: result,
      });
      return result;
    }

    const deleted = {};
    await runWithDevTradingDataResetDestroy(async () => {
      for (const cls of classesToWipe) {
        deleted[cls] = await destroyScoped(cls);
      }
    });

    let walletReseed = null;
    if (reseedInitialBalance) {
      try {
        walletReseed = await seedInitialBalancesFromConfig();
      } catch (err) {
        walletReseed = { error: err.message || String(err) };
      }
    } else {
      walletReseed = { skipped: true, reason: 'reseedInitialBalance=false' };
    }

    const result = {
      dryRun: false,
      nodeEnv,
      scope: normalizedScope,
      sinceHours: normalizedScope === 'sinceHours' ? normalizedSinceHours : undefined,
      counts,
      deleted,
      deletedTotal: Object.values(deleted).reduce((a, b) => a + (b || 0), 0),
      reseedInitialBalance: !!reseedInitialBalance,
      configInitialAccountBalance: initialBalPreview,
      walletReseed,
      completedAt: new Date().toISOString(),
    };
    await writeDevMaintenanceAudit({
      action: 'dev_reset_trading_test_data_execute',
      request,
      payload: result,
    });
    return result;
  });
}

module.exports = { registerDevResetTradingDataFunctions };
