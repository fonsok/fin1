'use strict';

const { requireAdminRole, requirePermission } = require('../../utils/permissions');
const { loadConfig } = require('../../utils/configHelper/index.js');

function registerLegalBrandingFunctions() {
  Parse.Cloud.define('getLegalBranding', async (request) => {
    requireAdminRole(request);
    requirePermission(request, 'manageTemplates');

    const cfg = await loadConfig(true);
    return {
      appName: cfg?.legal?.appName ?? 'FIN1',
      platformName: cfg?.legal?.platformName ?? 'App',
      updatedAt: cfg?._updatedAt ?? null,
      updatedBy: cfg?._updatedBy ?? null,
    };
  });

  Parse.Cloud.define('updateLegalBranding', async (request) => {
    requireAdminRole(request);
    requirePermission(request, 'manageTemplates');

    throw new Parse.Error(
      Parse.Error.OPERATION_FORBIDDEN,
      'updateLegalBranding is deprecated: use requestConfigurationChange with parameterName "legalAppName" (4-eyes).',
    );
  });
}

module.exports = { registerLegalBrandingFunctions };
