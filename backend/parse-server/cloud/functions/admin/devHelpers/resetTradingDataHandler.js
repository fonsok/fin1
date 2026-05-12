'use strict';

const { getInitialAccountBalance } = require('../../../utils/configHelper/index.js');
const { round2 } = require('../../../utils/accountingHelper/shared');
const {
  envTrue,
  writeDevMaintenanceAudit,
  runWithDevTradingDataResetDestroy,
} = require('./shared');
const { CLASSES_TO_WIPE } = require('./resetTradingDataClasses');
const { seedInitialBalancesFromConfig } = require('./resetTradingDataSeedBalances');
const { collectTradingResetTargets } = require('./resetTradingDataCollectTargets');
const { createTradingResetScopedOps } = require('./resetTradingDataScopedOps');

function assertDevTradingResetAllowed() {
  const nodeEnv = String(process.env.NODE_ENV || '').toLowerCase();
  const enabled = envTrue('ALLOW_DEV_TRADING_RESET');
  const allowInProd = envTrue('ALLOW_DEV_TRADING_RESET_IN_PRODUCTION');

  if (!enabled) {
    throw new Parse.Error(Parse.Error.OPERATION_FORBIDDEN, 'DEV reset disabled (ALLOW_DEV_TRADING_RESET=false).');
  }
  if (nodeEnv === 'production' && !allowInProd) {
    throw new Parse.Error(
      Parse.Error.OPERATION_FORBIDDEN,
      'DEV reset blocked in production (set ALLOW_DEV_TRADING_RESET_IN_PRODUCTION=true to override).',
    );
  }
  return { nodeEnv };
}

async function handleDevResetTradingTestData(request) {
  const { nodeEnv } = assertDevTradingResetAllowed();

  const {
    dryRun = true,
    scope = 'all',
    sinceHours = 24,
    testEmailDomain = '@test.com',
    testUserIdPrefix = 'user:',
    testUsernames = ['investor1', 'investor2', 'investor3', 'investor4', 'investor5', 'trader1', 'trader2', 'trader3'],
    reseedInitialBalance = false,
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

  const targets = await collectTradingResetTargets({
    normalizedScope,
    sinceDate,
    testEmailDomain,
    testUserIdPrefix,
    testUsernames,
  });

  const { countScoped, destroyScoped } = createTradingResetScopedOps({
    normalizedScope,
    sinceDate,
    targets,
  });

  const counts = {};
  for (const cls of CLASSES_TO_WIPE) {
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
    for (const cls of CLASSES_TO_WIPE) {
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
}

module.exports = {
  handleDevResetTradingTestData,
};
