'use strict';

const { requirePermission, logPermissionCheck } = require('../../utils/permissions');

Parse.Cloud.define('getComplianceEvents', async (request) => {
  requirePermission(request, 'getComplianceEvents');

  const { severity, reviewed, limit = 50, skip = 0 } = request.params;

  const query = new Parse.Query('ComplianceEvent');

  if (severity) query.equalTo('severity', severity);
  if (reviewed !== undefined) query.equalTo('reviewed', reviewed);

  query.descending('occurredAt');
  query.limit(limit);
  query.skip(skip);

  const events = await query.find({ useMasterKey: true });
  const total = await query.count({ useMasterKey: true });

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

  const { logType, action, userId, resourceType, limit = 100, skip = 0 } = request.params;

  const query = new Parse.Query('AuditLog');

  if (logType) query.equalTo('logType', logType);
  if (action) query.contains('action', action);
  if (userId) query.equalTo('userId', userId);
  if (resourceType) query.equalTo('resourceType', resourceType);

  query.descending('createdAt');
  query.limit(limit);
  query.skip(skip);

  const logs = await query.find({ useMasterKey: true });
  const total = await query.count({ useMasterKey: true });

  return { logs: logs.map(l => l.toJSON()), total };
});
