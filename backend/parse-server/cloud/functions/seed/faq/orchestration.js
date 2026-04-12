'use strict';

const { requireAdminRole } = require('../../../utils/permissions');
const { enforceMasterOnly, deleteAllFAQObjects } = require('./helpers');

function registerFAQOrchestrationFunctions() {
  Parse.Cloud.define('seedFAQData', async (request) => {
    if (!request.master) {
      requireAdminRole(request);
    }

    const opts = request.master
      ? { useMasterKey: true }
      : { sessionToken: request.user.getSessionToken() };

    const results = {};
    try {
      results.categories = await Parse.Cloud.run('seedFAQCategories', {}, opts);
    } catch (e) {
      results.categories = { success: false, error: e.message };
    }

    try {
      results.faqs = await Parse.Cloud.run('seedFAQs', {}, opts);
    } catch (e) {
      results.faqs = { success: false, error: e.message };
    }

    return results;
  });

  Parse.Cloud.define('deleteAllFAQData', async (request) => {
    enforceMasterOnly(request);
    const deleted = await deleteAllFAQObjects();
    return { success: true, ...deleted };
  });

  Parse.Cloud.define('forceReseedFAQData', async (request) => {
    const allowed = request.master || (request.user && request.user.get('role') === 'admin');
    if (!allowed) {
      throw new Parse.Error(Parse.Error.OPERATION_FORBIDDEN, 'Master key or admin role required');
    }

    await deleteAllFAQObjects();

    const opts = request.master
      ? { useMasterKey: true }
      : { sessionToken: request.user.getSessionToken() };
    const seedParams = request.master ? { runWithMasterKey: true, forceReseed: true } : { forceReseed: true };

    const results = {};
    try {
      results.categories = await Parse.Cloud.run('seedFAQCategories', seedParams, opts);
    } catch (e) {
      results.categories = { success: false, error: e.message };
    }
    try {
      results.faqs = await Parse.Cloud.run('seedFAQs', seedParams, opts);
    } catch (e) {
      results.faqs = { success: false, error: e.message };
    }
    return results;
  });
}

module.exports = { registerFAQOrchestrationFunctions };
