'use strict';

const { requireAdminRole } = require('../../utils/permissions');

Parse.Cloud.define('getOnboardingFunnel', async (request) => {
  requireAdminRole(request);

  const { days = 30 } = request.params || {};
  const since = new Date(Date.now() - days * 24 * 60 * 60 * 1000);

  const userQuery = new Parse.Query(Parse.User);
  userQuery.greaterThanOrEqualTo('createdAt', since);
  userQuery.containedIn('role', ['investor', 'trader']);
  const totalStarted = await userQuery.count({ useMasterKey: true });

  const completedQuery = new Parse.Query(Parse.User);
  completedQuery.greaterThanOrEqualTo('createdAt', since);
  completedQuery.containedIn('role', ['investor', 'trader']);
  completedQuery.equalTo('onboardingCompleted', true);
  const totalCompleted = await completedQuery.count({ useMasterKey: true });

  const verifiedQuery = new Parse.Query(Parse.User);
  verifiedQuery.greaterThanOrEqualTo('createdAt', since);
  verifiedQuery.containedIn('role', ['investor', 'trader']);
  verifiedQuery.equalTo('isEmailVerified', true);
  const totalEmailVerified = await verifiedQuery.count({ useMasterKey: true });

  const auditQuery = new Parse.Query('OnboardingAudit');
  auditQuery.greaterThanOrEqualTo('completedAt', since);
  auditQuery.limit(10000);
  auditQuery.select('step', 'userId', 'completedAt');
  const audits = await auditQuery.find({ useMasterKey: true });

  const stepCounts = {};
  const userSteps = {};
  for (const a of audits) {
    const step = a.get('step');
    const uid = a.get('userId');
    stepCounts[step] = (stepCounts[step] || 0) + 1;
    if (!userSteps[uid]) userSteps[uid] = [];
    userSteps[uid].push({ step, at: a.get('completedAt') });
  }

  const stepOrder = [
    'emailVerification', 'personal', 'address', 'tax',
    'verification', 'experience', 'risk', 'consents'
  ];
  const funnel = stepOrder.map((step, idx) => {
    const count = stepCounts[step] || 0;
    const prev = idx > 0 ? (stepCounts[stepOrder[idx - 1]] || 0) : totalStarted;
    const dropOff = prev > 0 ? Math.round(((prev - count) / prev) * 100) : 0;
    return { step, count, dropOffPercent: dropOff };
  });

  const stuckThreshold = new Date(Date.now() - 24 * 60 * 60 * 1000);
  const stuckQuery = new Parse.Query(Parse.User);
  stuckQuery.containedIn('role', ['investor', 'trader']);
  stuckQuery.notEqualTo('onboardingCompleted', true);
  stuckQuery.exists('onboardingStep');
  stuckQuery.lessThan('updatedAt', stuckThreshold);
  stuckQuery.greaterThanOrEqualTo('createdAt', since);
  stuckQuery.limit(50);
  stuckQuery.select('email', 'onboardingStep', 'updatedAt', 'createdAt', 'isEmailVerified');
  stuckQuery.descending('updatedAt');
  const stuckUsers = await stuckQuery.find({ useMasterKey: true });

  const stuck = stuckUsers.map(u => ({
    userId: u.id,
    email: u.get('email'),
    lastStep: u.get('onboardingStep'),
    lastActivity: u.get('updatedAt'),
    createdAt: u.get('createdAt'),
    emailVerified: u.get('isEmailVerified') || false,
  }));

  let avgCompletionMinutes = null;
  const completionQuery = new Parse.Query(Parse.User);
  completionQuery.greaterThanOrEqualTo('createdAt', since);
  completionQuery.equalTo('onboardingCompleted', true);
  completionQuery.exists('onboardingCompletedAt');
  completionQuery.limit(200);
  completionQuery.select('createdAt', 'onboardingCompletedAt');
  const completedUsers = await completionQuery.find({ useMasterKey: true });

  if (completedUsers.length > 0) {
    let totalMs = 0;
    let count = 0;
    for (const u of completedUsers) {
      const start = u.get('createdAt');
      const end = u.get('onboardingCompletedAt');
      if (start && end) {
        totalMs += end.getTime() - start.getTime();
        count++;
      }
    }
    if (count > 0) {
      avgCompletionMinutes = Math.round(totalMs / count / 60000);
    }
  }

  return {
    period: { days, since: since.toISOString() },
    summary: {
      totalStarted,
      totalCompleted,
      totalEmailVerified,
      completionRate: totalStarted > 0 ? Math.round((totalCompleted / totalStarted) * 100) : 0,
      avgCompletionMinutes,
    },
    funnel,
    stuckUsers: stuck,
  };
});
