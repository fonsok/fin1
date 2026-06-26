'use strict';

const { requireAdminRole } = require('../../../utils/permissions');
const { SIGNUP_RUN_EMAIL_REGEX } = require('../../../utils/testUserCatalog');
const { envTrue, writeDevMaintenanceAudit } = require('./shared');

function assertDevSignupRunCleanupAllowed() {
  const nodeEnv = String(process.env.NODE_ENV || '').toLowerCase();
  const enabled = envTrue('ALLOW_DEV_SIGNUP_RUN_CLEANUP') || envTrue('ALLOW_DEV_TRADING_RESET');
  const allowInProd = envTrue('ALLOW_DEV_SIGNUP_RUN_CLEANUP_IN_PRODUCTION')
    || envTrue('ALLOW_DEV_TRADING_RESET_IN_PRODUCTION');

  if (!enabled) {
    throw new Parse.Error(
      Parse.Error.OPERATION_FORBIDDEN,
      'cleanupSignupRunUsers disabled (set ALLOW_DEV_SIGNUP_RUN_CLEANUP=true or ALLOW_DEV_TRADING_RESET=true).',
    );
  }
  if (nodeEnv === 'production' && !allowInProd) {
    throw new Parse.Error(
      Parse.Error.OPERATION_FORBIDDEN,
      'cleanupSignupRunUsers blocked in production (set ALLOW_DEV_SIGNUP_RUN_CLEANUP_IN_PRODUCTION=true).',
    );
  }
  return { nodeEnv };
}

async function userHasFinancialActivity(userId) {
  const [investments, trades] = await Promise.all([
    new Parse.Query('Investment').equalTo('investorId', userId).limit(1).count({ useMasterKey: true }),
    new Parse.Query('Trade').equalTo('traderId', userId).limit(1).count({ useMasterKey: true }),
  ]);
  return investments > 0 || trades > 0;
}

async function destroyOnboardingArtifacts(userId) {
  const progress = await new Parse.Query('OnboardingProgress')
    .equalTo('userId', userId)
    .limit(100)
    .find({ useMasterKey: true });
  if (progress.length) {
    await Parse.Object.destroyAll(progress, { useMasterKey: true });
  }
}

/**
 * Dev-only: remove DEBUG Get-Started runs (signup+{ts}@test.com).
 * Preserves canonical iOS debug-list users (investorN/traderN@test.com).
 */
async function handleDevCleanupSignupRunUsers(request) {
  requireAdminRole(request);
  const { nodeEnv } = assertDevSignupRunCleanupAllowed();

  const apply = request.params?.dryRun === false || request.params?.dryRun === 'false';
  const limit = Math.min(Math.max(Number(request.params?.limit) || 500, 1), 1000);

  const query = new Parse.Query(Parse.User);
  query.matches('email', SIGNUP_RUN_EMAIL_REGEX, 'i');
  query.limit(limit);
  const users = await query.find({ useMasterKey: true });

  const results = [];
  let deleted = 0;
  let skipped = 0;

  for (const user of users) {
    const row = {
      objectId: user.id,
      email: user.get('email'),
      role: user.get('role'),
      customerNumber: user.get('customerNumber') || null,
    };

    if (await userHasFinancialActivity(user.id)) {
      skipped += 1;
      results.push({ ...row, action: 'skipped', reason: 'has_financial_activity' });
      continue;
    }

    if (!apply) {
      results.push({ ...row, action: 'would_delete' });
      continue;
    }

    try {
      await destroyOnboardingArtifacts(user.id);
      await user.destroy({ useMasterKey: true });
      deleted += 1;
      results.push({ ...row, action: 'deleted' });
    } catch (err) {
      skipped += 1;
      results.push({ ...row, action: 'failed', reason: err.message || String(err) });
    }
  }

  return {
    dryRun: !apply,
    nodeEnv,
    matched: users.length,
    deleted,
    skipped,
    previewCount: results.length,
    results: results.slice(0, 50),
    ranAt: new Date().toISOString(),
  };
}

async function handleDevCleanupSignupRunUsersWithAudit(request) {
  const result = await handleDevCleanupSignupRunUsers(request);
  await writeDevMaintenanceAudit({
    action: result.dryRun ? 'dev_cleanup_signup_run_users_dry_run' : 'dev_cleanup_signup_run_users',
    request,
    payload: {
      matched: result.matched,
      deleted: result.deleted,
      skipped: result.skipped,
      dryRun: result.dryRun,
    },
  });
  return result;
}

function registerDevCleanupSignupRunUsers() {
  Parse.Cloud.define('cleanupSignupRunUsers', handleDevCleanupSignupRunUsersWithAudit);
}

module.exports = {
  handleDevCleanupSignupRunUsers,
  registerDevCleanupSignupRunUsers,
};
