'use strict';

const { requireAdminRole } = require('../../utils/permissions');

Parse.Cloud.define('seedAllMockData', async (request) => {
  requireAdminRole(request);

  const results = {};

  // Seed test users (5 investors + 10 traders)
  try {
    results.testUsers = await Parse.Cloud.run('seedTestUsers', {}, { sessionToken: request.user.getSessionToken() });
  } catch (e) {
    results.testUsers = { success: false, error: e.message };
  }

  // Seed FAQ data (categories + articles)
  try {
    results.faqData = await Parse.Cloud.run('seedFAQData', {}, { sessionToken: request.user.getSessionToken() });
  } catch (e) {
    results.faqData = { success: false, error: e.message };
  }

  // Seed tickets
  try {
    results.tickets = await Parse.Cloud.run('seedMockTickets', {}, { sessionToken: request.user.getSessionToken() });
  } catch (e) {
    results.tickets = { success: false, error: e.message };
  }

  // Seed compliance events
  try {
    results.complianceEvents = await Parse.Cloud.run('seedMockComplianceEvents', {}, { sessionToken: request.user.getSessionToken() });
  } catch (e) {
    results.complianceEvents = { success: false, error: e.message };
  }

  // Seed audit logs
  try {
    results.auditLogs = await Parse.Cloud.run('seedMockAuditLogs', {}, { sessionToken: request.user.getSessionToken() });
  } catch (e) {
    results.auditLogs = { success: false, error: e.message };
  }

  // Seed CSR templates
  try {
    results.csrTemplates = await Parse.Cloud.run('seedCSRTemplates', {}, { sessionToken: request.user.getSessionToken() });
  } catch (e) {
    results.csrTemplates = { success: false, error: e.message };
  }

  // Seed CSR permissions
  try {
    results.csrPermissions = await Parse.Cloud.run('seedCSRPermissions', {}, { sessionToken: request.user.getSessionToken() });
  } catch (e) {
    results.csrPermissions = { success: false, error: e.message };
  }

  return results;
});
