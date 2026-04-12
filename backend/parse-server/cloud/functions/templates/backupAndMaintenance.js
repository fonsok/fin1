'use strict';

const { requirePermission, requireAdminRole } = require('../../utils/permissions');

function registerBackupAndMaintenanceFunctions() {
  Parse.Cloud.define('exportCSRTemplatesBackup', async (request) => {
    requireAdminRole(request);
    requirePermission(request, 'manageTemplates');

    const [categories, responseTemplates, emailTemplates] = await Promise.all([
      new Parse.Query('CSRTemplateCategory').limit(500).find({ useMasterKey: true }),
      new Parse.Query('CSRResponseTemplate').limit(500).find({ useMasterKey: true }),
      new Parse.Query('CSREmailTemplate').limit(500).find({ useMasterKey: true }),
    ]);

    return {
      exportedAt: new Date().toISOString(),
      version: '1.0',
      note: 'Backup CSR Templates. Quelle: Admin-Portal CSR Templates.',
      categories: categories.map((c) => c.toJSON()),
      responseTemplates: responseTemplates.map((t) => t.toJSON()),
      emailTemplates: emailTemplates.map((t) => t.toJSON()),
    };
  });

  Parse.Cloud.define('backfillCSRTemplateShortcuts', async (request) => {
    requireAdminRole(request);
    requirePermission(request, 'manageTemplates');

    const { dryRun = true } = request.params || {};
    const mapping = {
      refund_initiated: 'refund',
      password_reset_guide: 'reset',
      account_unlocked: 'unlock',
      kyc_documents_required: 'kyc',
    };

    const q = new Parse.Query('CSRResponseTemplate');
    q.equalTo('isActive', true);
    q.limit(500);
    const docs = await q.find({ useMasterKey: true });

    const candidates = docs.filter((d) => {
      const hasShortcut = !!String(d.get('shortcut') || '').trim();
      return !hasShortcut && !!mapping[d.get('templateKey')];
    });

    if (dryRun) {
      return {
        dryRun: true,
        activeTemplatesScanned: docs.length,
        candidates: candidates.map((d) => ({
          objectId: d.id,
          templateKey: d.get('templateKey'),
          title: d.get('title'),
          suggestedShortcut: mapping[d.get('templateKey')],
        })),
        candidateCount: candidates.length,
      };
    }

    for (const d of candidates) {
      d.set('shortcut', mapping[d.get('templateKey')]);
      d.increment('version');
      d.set('updatedBy', request.user?.id || 'system');
    }
    if (candidates.length) {
      await Parse.Object.saveAll(candidates, { useMasterKey: true });
    }

    return {
      dryRun: false,
      updatedCount: candidates.length,
      updated: candidates.map((d) => ({
        objectId: d.id,
        templateKey: d.get('templateKey'),
        shortcut: d.get('shortcut'),
      })),
    };
  });
}

module.exports = { registerBackupAndMaintenanceFunctions };
