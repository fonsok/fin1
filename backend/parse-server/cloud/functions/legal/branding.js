'use strict';

const { requireAdminRole, requirePermission } = require('../../utils/permissions');
const { loadConfig, invalidateCache } = require('../../utils/configHelper/index.js');
const { normalizeString } = require('./shared');

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

    const appName = normalizeString(request.params.appName);
    const platformName = normalizeString(request.params.platformName);
    const reason = normalizeString(request.params.reason || 'Update legal branding');

    if (!appName) {
      throw new Parse.Error(Parse.Error.INVALID_VALUE, 'appName is required');
    }

    const Configuration = Parse.Object.extend('Configuration');
    const query = new Parse.Query(Configuration);
    query.equalTo('isActive', true);
    query.descending('updatedAt');
    let cfg = await query.first({ useMasterKey: true });
    if (!cfg) {
      cfg = new Configuration();
      cfg.set('isActive', true);
    }

    cfg.set('legalAppName', appName);
    if (platformName) cfg.set('legalPlatformName', platformName);
    cfg.set('updatedBy', request.user?.id ?? null);
    cfg.set('updatedByEmail', request.user?.get?.('email') ?? null);
    cfg.set('updatedByRole', request.user?.get?.('role') ?? null);
    cfg.set('updatedReason', reason);

    await cfg.save(null, { useMasterKey: true });
    invalidateCache();

    const fresh = await loadConfig(true);
    return {
      success: true,
      appName: fresh?.legal?.appName ?? appName,
      platformName: fresh?.legal?.platformName ?? platformName ?? 'App',
    };
  });
}

module.exports = { registerLegalBrandingFunctions };
