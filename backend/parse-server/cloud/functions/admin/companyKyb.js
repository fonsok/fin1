'use strict';

const { readCustomerNumber } = require('../../utils/userIdentity');

const { requirePermission, logPermissionCheck } = require('../../utils/permissions');
const { applyQuerySort } = require('../../utils/applyQuerySort');

const VALID_DECISIONS = ['approved', 'rejected', 'more_info_requested'];

// ---------------------------------------------------------------------------
// getCompanyKybSubmissions
// ---------------------------------------------------------------------------
Parse.Cloud.define('getCompanyKybSubmissions', async (request) => {
  requirePermission(request, 'getCompanyKybSubmissions');

  const {
    status = 'pending_review',
    limit = 50,
    skip = 0,
  } = request.params || {};

  function buildKybUserQuery() {
    const q = new Parse.Query(Parse.User);
    q.equalTo('accountType', 'company');
    q.equalTo('companyKybCompleted', true);
    if (status !== 'all') {
      q.equalTo('companyKybStatus', status);
    }
    return q;
  }

  const countQuery = buildKybUserQuery();
  const total = await countQuery.count({ useMasterKey: true });

  const pageQuery = buildKybUserQuery();
  applyQuerySort(pageQuery, request.params || {}, {
    allowed: ['companyKybCompletedAt', 'lastName'],
    defaultField: 'companyKybCompletedAt',
    defaultDesc: true,
  });
  pageQuery.skip(skip);
  pageQuery.limit(limit);

  const users = await pageQuery.find({ useMasterKey: true });

  await logPermissionCheck(request, 'getCompanyKybSubmissions', 'User', 'list');

  const formatDate = (d) => {
    if (!d) return null;
    if (d instanceof Date) return d.toISOString();
    if (d.iso) return d.iso;
    return d;
  };

  return {
    submissions: users.map((u) => ({
      userId: u.id,
      customerNumber: readCustomerNumber(u),
      email: u.get('email'),
      firstName: u.get('firstName'),
      lastName: u.get('lastName'),
      companyKybStatus: u.get('companyKybStatus'),
      companyKybStep: u.get('companyKybStep'),
      companyKybCompletedAt: formatDate(u.get('companyKybCompletedAt')),
      createdAt: formatDate(u.createdAt),
    })),
    total,
  };
});

// ---------------------------------------------------------------------------
// getCompanyKybSubmissionDetail
// ---------------------------------------------------------------------------
Parse.Cloud.define('getCompanyKybSubmissionDetail', async (request) => {
  requirePermission(request, 'getCompanyKybSubmissionDetail');

  const { userId } = request.params || {};
  if (!userId) {
    throw new Parse.Error(Parse.Error.INVALID_VALUE, 'userId required');
  }

  const user = await new Parse.Query(Parse.User).get(userId, { useMasterKey: true });
  await logPermissionCheck(request, 'getCompanyKybSubmissionDetail', 'User', userId);

  if (user.get('accountType') !== 'company') {
    throw new Parse.Error(Parse.Error.INVALID_VALUE, 'User is not a company account');
  }

  // Fetch audit trail (completed steps with submitted data)
  const auditQuery = new Parse.Query('CompanyKybAudit');
  auditQuery.equalTo('userId', userId);
  auditQuery.ascending('completedAt');
  const auditEntries = await auditQuery.find({ useMasterKey: true });

  // Fetch saved progress (draft data per step)
  const progressQuery = new Parse.Query('CompanyKybProgress');
  progressQuery.equalTo('userId', userId);
  progressQuery.ascending('updatedAt');
  const progressEntries = await progressQuery.find({ useMasterKey: true });

  let mergedData = {};
  for (const p of progressEntries) {
    const stepData = p.get('data');
    if (stepData && typeof stepData === 'object') {
      Object.assign(mergedData, stepData);
    }
  }

  const formatDate = (d) => {
    if (!d) return null;
    if (d instanceof Date) return d.toISOString();
    if (d.iso) return d.iso;
    return d;
  };

  return {
    user: {
      objectId: user.id,
      customerNumber: readCustomerNumber(user),
      email: user.get('email'),
      firstName: user.get('firstName'),
      lastName: user.get('lastName'),
      accountType: user.get('accountType'),
      companyKybStatus: user.get('companyKybStatus'),
      companyKybStep: user.get('companyKybStep'),
      companyKybCompleted: user.get('companyKybCompleted') || false,
      companyKybCompletedAt: formatDate(user.get('companyKybCompletedAt')),
      companyKybReviewedAt: formatDate(user.get('companyKybReviewedAt')),
      companyKybReviewedBy: user.get('companyKybReviewedBy') || null,
      companyKybReviewNotes: user.get('companyKybReviewNotes') || null,
    },
    auditTrail: auditEntries.map((a) => ({
      objectId: a.id,
      step: a.get('step'),
      completedAt: formatDate(a.get('completedAt')),
      schemaVersion: a.get('schemaVersion'),
      answers: a.get('answers') || null,
      fullData: a.get('fullData') || null,
    })),
    mergedData: Object.keys(mergedData).length > 0 ? mergedData : null,
  };
});

// ---------------------------------------------------------------------------
// reviewCompanyKyb
// ---------------------------------------------------------------------------
Parse.Cloud.define('reviewCompanyKyb', async (request) => {
  requirePermission(request, 'reviewCompanyKyb');

  const { userId, decision, notes } = request.params || {};

  if (!userId) {
    throw new Parse.Error(Parse.Error.INVALID_VALUE, 'userId required');
  }
  if (!decision || !VALID_DECISIONS.includes(decision)) {
    throw new Parse.Error(
      Parse.Error.INVALID_VALUE,
      `decision must be one of: ${VALID_DECISIONS.join(', ')}`
    );
  }
  if ((decision === 'rejected' || decision === 'more_info_requested') && (!notes || !notes.trim())) {
    throw new Parse.Error(Parse.Error.INVALID_VALUE, 'Rejection or info request requires notes explaining the reason');
  }

  const user = await new Parse.Query(Parse.User).get(userId, { useMasterKey: true });

  if (user.get('accountType') !== 'company') {
    throw new Parse.Error(Parse.Error.INVALID_VALUE, 'User is not a company account');
  }

  const currentStatus = user.get('companyKybStatus');
  if (currentStatus !== 'pending_review') {
    throw new Parse.Error(
      Parse.Error.OPERATION_FORBIDDEN,
      `Cannot review: KYB status is '${currentStatus}', expected 'pending_review'`
    );
  }

  const reviewerId = request.user.id;
  const reviewerRole = request.user.get('role');
  const reviewerEmail = request.user.get('email');
  const now = new Date();

  // Update user KYB status
  user.set('companyKybStatus', decision);
  user.set('companyKybReviewedAt', now);
  user.set('companyKybReviewedBy', reviewerId);
  user.set('companyKybReviewNotes', notes || null);
  user.increment('companyKybRevision', 1);

  await user.save(null, { useMasterKey: true });

  // Create CompanyKybAudit entry for the review action
  const CompanyKybAudit = Parse.Object.extend('CompanyKybAudit');
  const audit = new CompanyKybAudit();
  audit.set('userId', userId);
  audit.set('step', `review_${decision}`);
  audit.set('completedAt', now);
  audit.set('schemaVersion', 1);
  audit.set('answers', {
    decision,
    reviewerId,
    reviewerRole,
    reviewerEmail,
    notes: notes || null,
  });
  await audit.save(null, { useMasterKey: true });

  // Create AuditLog entry
  const AuditLog = Parse.Object.extend('AuditLog');
  const log = new AuditLog();
  log.set('logType', 'action');
  log.set('action', `company_kyb_${decision}`);
  log.set('userId', reviewerId);
  log.set('userRole', reviewerRole);
  log.set('resourceType', 'User');
  log.set('resourceId', userId);
  log.set('oldValues', { companyKybStatus: 'pending_review' });
  log.set('newValues', { companyKybStatus: decision });
  log.set('metadata', {
    performedBy: reviewerId,
    performedByRole: reviewerRole,
    performedByEmail: reviewerEmail,
    notes: notes || null,
    ip: request.ip,
  });
  await log.save(null, { useMasterKey: true });

  await logPermissionCheck(request, 'reviewCompanyKyb', 'User', userId);

  const messages = {
    approved: 'Company KYB approved successfully.',
    rejected: 'Company KYB rejected. User will be notified.',
    more_info_requested: 'Additional information requested. User will be notified.',
  };

  return {
    success: true,
    decision,
    userId,
    message: messages[decision],
  };
});

// ---------------------------------------------------------------------------
// resetCompanyKyb  –  Allows an admin to reset a rejected/more_info_requested
//                     KYB back to 'draft' so the user can re-enter the wizard.
//                     Previous CompanyKybProgress and CompanyKybAudit data are
//                     preserved (pre-fill + audit history).
// ---------------------------------------------------------------------------
Parse.Cloud.define('resetCompanyKyb', async (request) => {
  requirePermission(request, 'resetCompanyKyb');

  const { userId, notes } = request.params || {};

  if (!userId) {
    throw new Parse.Error(Parse.Error.INVALID_VALUE, 'userId required');
  }

  const user = await new Parse.Query(Parse.User).get(userId, { useMasterKey: true });

  if (user.get('accountType') !== 'company') {
    throw new Parse.Error(Parse.Error.INVALID_VALUE, 'User is not a company account');
  }

  const RESETTABLE_STATUSES = ['rejected', 'more_info_requested'];
  const currentStatus = user.get('companyKybStatus');
  if (!RESETTABLE_STATUSES.includes(currentStatus)) {
    throw new Parse.Error(
      Parse.Error.OPERATION_FORBIDDEN,
      `Cannot reset: KYB status is '${currentStatus}', expected one of: ${RESETTABLE_STATUSES.join(', ')}`
    );
  }

  const reviewerId = request.user.id;
  const reviewerRole = request.user.get('role');
  const reviewerEmail = request.user.get('email');
  const now = new Date();

  user.set('companyKybStatus', 'draft');
  user.set('companyKybCompleted', false);
  user.unset('companyKybStep');
  user.unset('companyKybReviewedAt');
  user.unset('companyKybReviewedBy');
  user.unset('companyKybReviewNotes');
  user.increment('companyKybRevision', 1);

  await user.save(null, { useMasterKey: true });

  const CompanyKybAudit = Parse.Object.extend('CompanyKybAudit');
  const audit = new CompanyKybAudit();
  audit.set('userId', userId);
  audit.set('step', 'reset');
  audit.set('completedAt', now);
  audit.set('schemaVersion', 1);
  audit.set('answers', {
    previousStatus: currentStatus,
    resetBy: reviewerId,
    resetByRole: reviewerRole,
    resetByEmail: reviewerEmail,
    notes: notes || null,
  });
  await audit.save(null, { useMasterKey: true });

  const AuditLog = Parse.Object.extend('AuditLog');
  const log = new AuditLog();
  log.set('logType', 'action');
  log.set('action', 'company_kyb_reset');
  log.set('userId', reviewerId);
  log.set('userRole', reviewerRole);
  log.set('resourceType', 'User');
  log.set('resourceId', userId);
  log.set('oldValues', { companyKybStatus: currentStatus, companyKybCompleted: true });
  log.set('newValues', { companyKybStatus: 'draft', companyKybCompleted: false });
  log.set('metadata', {
    performedBy: reviewerId,
    performedByRole: reviewerRole,
    performedByEmail: reviewerEmail,
    notes: notes || null,
    ip: request.ip,
  });
  await log.save(null, { useMasterKey: true });

  await logPermissionCheck(request, 'resetCompanyKyb', 'User', userId);

  return {
    success: true,
    userId,
    message: `Company KYB reset from '${currentStatus}' to 'draft'. User can now re-submit.`,
  };
});
