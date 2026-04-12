'use strict';

const { logPermissionCheck } = require('../../utils/permissions');
const { requirePermissionWithTestAuth, requireAdminRoleWithTestAuth } = require('../../utils/testAuthMiddleware');
const { loadConfig, CRITICAL_PARAMETERS } = require('../../utils/configHelper/index.js');
const { buildDisplay } = require('./shared');

function registerConfigurationReadFunctions() {
  Parse.Cloud.define('getConfiguration', async (request) => {
    await requireAdminRoleWithTestAuth(request);

    const config = await loadConfig(true);
    await logPermissionCheck(request, 'getConfiguration', 'Configuration', config._id || 'default');

    const flatConfig = {
      ...config.financial,
      ...config.limits,
      // Align with admin portal PARAMETER_DEFINITIONS (snake_case)
      daily_transaction_limit: config.limits.dailyTransactionLimit,
      weekly_transaction_limit: config.limits.weeklyTransactionLimit,
      monthly_transaction_limit: config.limits.monthlyTransactionLimit,
    };

    return {
      config: flatConfig,
      financial: config.financial,
      limits: config.limits,
      display: buildDisplay(config),
      metadata: {
        lastUpdated: config._updatedAt,
        updatedBy: config._updatedBy,
      },
      criticalParameters: CRITICAL_PARAMETERS,
    };
  });

  Parse.Cloud.define('getPendingConfigurationChanges', async (request) => {
    await requirePermissionWithTestAuth(request, 'getPendingApprovals');

    const query = new Parse.Query('FourEyesRequest');
    query.equalTo('requestType', 'configuration_change');
    query.equalTo('status', 'pending');
    query.greaterThan('expiresAt', new Date());
    query.descending('createdAt');

    const isDevelopment = process.env.NODE_ENV !== 'production';
    if (!isDevelopment) {
      query.notEqualTo('requesterId', request.user.id);
    } else {
      console.log('🔧 Development mode: Showing all pending requests (including own)');
    }

    const requests = await query.find({ useMasterKey: true });

    return {
      requests: requests.map((r) => ({
        id: r.id,
        parameterName: r.get('metadata').parameterName,
        oldValue: r.get('metadata').oldValue,
        newValue: r.get('metadata').newValue,
        reason: r.get('metadata').reason,
        requesterId: r.get('requesterId'),
        requesterEmail: r.get('requesterEmail'),
        requesterRole: r.get('requesterRole'),
        createdAt: r.get('createdAt'),
        expiresAt: r.get('expiresAt'),
      })),
      total: requests.length,
    };
  });

  Parse.Cloud.define('getConfigurationChangeHistory', async (request) => {
    await requirePermissionWithTestAuth(request, 'getAuditLogs');

    const { limit = 50, skip = 0 } = request.params;

    const query = new Parse.Query('AuditLog');
    query.equalTo('resourceType', 'Configuration');
    query.descending('createdAt');
    query.limit(limit);
    query.skip(skip);

    const logs = await query.find({ useMasterKey: true });
    const total = await query.count({ useMasterKey: true });

    return {
      logs: logs.map((l) => l.toJSON()),
      total,
    };
  });
}

module.exports = { registerConfigurationReadFunctions };
