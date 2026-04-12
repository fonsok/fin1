'use strict';

const { requirePermission, logPermissionCheck } = require('../../utils/permissions');
const { applyQuerySort } = require('../../utils/applyQuerySort');

Parse.Cloud.define('getComplianceEvents', async (request) => {
  requirePermission(request, 'getComplianceEvents');

  const { severity, reviewed, limit = 50, skip = 0 } = request.params;

  function buildEventQuery() {
    const q = new Parse.Query('ComplianceEvent');
    if (severity) q.equalTo('severity', severity);
    if (reviewed !== undefined) q.equalTo('reviewed', reviewed);
    return q;
  }

  const countQuery = buildEventQuery();
  const total = await countQuery.count({ useMasterKey: true });

  const pageQuery = buildEventQuery();
  applyQuerySort(pageQuery, request.params || {}, {
    allowed: ['occurredAt', 'severity'],
    defaultField: 'occurredAt',
    defaultDesc: true,
  });
  pageQuery.skip(skip);
  pageQuery.limit(limit);

  const events = await pageQuery.find({ useMasterKey: true });

  return { events: events.map(e => e.toJSON()), total };
});

Parse.Cloud.define('reviewComplianceEvent', async (request) => {
  requirePermission(request, 'reviewComplianceEvent');

  const { eventId, notes } = request.params;

  if (!eventId) {
    throw new Parse.Error(Parse.Error.INVALID_VALUE, 'eventId required');
  }

  const event = await new Parse.Query('ComplianceEvent').get(eventId, { useMasterKey: true });

  event.set('reviewed', true);
  event.set('reviewedBy', request.user.id);
  event.set('reviewedAt', new Date());
  event.set('reviewNotes', notes);

  await event.save(null, { useMasterKey: true });

  await logPermissionCheck(request, 'reviewComplianceEvent', 'ComplianceEvent', eventId);

  return { success: true };
});

Parse.Cloud.define('getAuditLogs', async (request) => {
  requirePermission(request, 'getAuditLogs');

  const {
    logType,
    action,
    userId,
    resourceType,
    limit = 100,
    skip = 0,
  } = request.params;

  function buildAuditQuery() {
    const q = new Parse.Query('AuditLog');
    if (logType) q.equalTo('logType', logType);
    if (action) q.contains('action', action);
    if (userId) q.equalTo('userId', userId);
    if (resourceType) q.equalTo('resourceType', resourceType);
    return q;
  }

  const countQuery = buildAuditQuery();
  const total = await countQuery.count({ useMasterKey: true });

  const pageQuery = buildAuditQuery();
  applyQuerySort(pageQuery, request.params || {}, {
    allowed: ['createdAt'],
    defaultField: 'createdAt',
    defaultDesc: true,
  });
  pageQuery.skip(skip);
  pageQuery.limit(limit);

  const logs = await pageQuery.find({ useMasterKey: true });

  return { logs: logs.map(l => l.toJSON()), total };
});
