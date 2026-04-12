'use strict';

const { requireAdminRole, requirePermission } = require('../../utils/permissions');
const { normalizeString, serializeTermsContentBackup } = require('./shared');

function registerLegalDevMaintenanceFunctions() {
  Parse.Cloud.define('devResetLegalDocumentsBaseline', async (request) => {
    requireAdminRole(request);
    requirePermission(request, 'manageTemplates');

    const allowHardDelete = String(process.env.ALLOW_LEGAL_HARD_DELETE || '').toLowerCase() === 'true';
    if (!allowHardDelete) {
      throw new Parse.Error(Parse.Error.OPERATION_FORBIDDEN, 'Hard delete is disabled. Set ALLOW_LEGAL_HARD_DELETE=true on server.');
    }

    const dryRun = !!request.params.dryRun;
    const targetVersion = normalizeString(request.params.targetVersion || '1.0.0');
    if (!targetVersion) {
      throw new Parse.Error(Parse.Error.INVALID_VALUE, 'targetVersion is required');
    }

    const effectiveDate = request.params.effectiveDate ? new Date(request.params.effectiveDate) : new Date();
    if (!(effectiveDate instanceof Date) || isNaN(effectiveDate.getTime())) {
      throw new Parse.Error(Parse.Error.INVALID_VALUE, 'effectiveDate must be a valid ISO date string');
    }

    const safetyQuery = new Parse.Query('TermsContent');
    safetyQuery.descending('effectiveDate');
    safetyQuery.limit(500);
    const safetyDocs = await safetyQuery.find({ useMasterKey: true });
    const safetyBackup = {
      exportedAt: new Date().toISOString(),
      version: '1.0',
      note: 'Safety backup before devResetLegalDocumentsBaseline (TermsContent).',
      documents: safetyDocs.map((doc) => serializeTermsContentBackup(doc)),
    };

    const activeQuery = new Parse.Query('TermsContent');
    activeQuery.equalTo('isActive', true);
    activeQuery.notEqualTo('archived', true);
    activeQuery.limit(200);
    const activeDocs = await activeQuery.find({ useMasterKey: true });

    if (activeDocs.length === 0) {
      throw new Parse.Error(Parse.Error.OBJECT_NOT_FOUND, 'No active TermsContent found');
    }

    const TermsContent = Parse.Object.extend('TermsContent');
    const clones = [];
    for (const doc of activeDocs) {
      const obj = new TermsContent();
      obj.set('version', targetVersion);
      obj.set('language', doc.get('language'));
      obj.set('documentType', doc.get('documentType'));
      obj.set('effectiveDate', effectiveDate);
      obj.set('sections', doc.get('sections') || []);
      obj.set('isActive', false);
      obj.set('restoredFromBackupAt', new Date());
      obj.set('restoredFromBackupId', normalizeString(safetyBackup.exportedAt ?? 'devReset'));
      obj.set('restoredFromSourceObjectId', doc.id);
      clones.push(obj);
    }

    if (!dryRun) {
      await Parse.Object.saveAll(clones, { useMasterKey: true });
    }

    const groups = new Map();
    for (const obj of clones) {
      const k = `${obj.get('documentType')}:${obj.get('language')}`;
      if (!groups.has(k)) groups.set(k, []);
      groups.get(k).push(obj);
    }

    const activatedIds = [];
    if (!dryRun) {
      for (const [, docs] of groups.entries()) {
        docs.sort((a, b) => {
          const ad = a.get('effectiveDate') instanceof Date ? a.get('effectiveDate').getTime() : 0;
          const bd = b.get('effectiveDate') instanceof Date ? b.get('effectiveDate').getTime() : 0;
          return bd - ad;
        });
        const newest = docs[0];

        const language = newest.get('language');
        const documentType = newest.get('documentType');
        const currentQuery = new Parse.Query('TermsContent');
        currentQuery.equalTo('language', language);
        currentQuery.equalTo('documentType', documentType);
        currentQuery.equalTo('isActive', true);
        const currentActive = await currentQuery.find({ useMasterKey: true });
        for (const d of currentActive) {
          if (d.id !== newest.id) d.set('isActive', false);
        }
        newest.set('isActive', true);
        await Parse.Object.saveAll([...currentActive, newest], { useMasterKey: true });
        activatedIds.push(newest.id);
      }
    }

    let deletedCount = 0;
    if (!dryRun) {
      const deleteQuery = new Parse.Query('TermsContent');
      deleteQuery.notEqualTo('isActive', true);
      deleteQuery.limit(1000);
      // eslint-disable-next-line no-constant-condition
      while (true) {
        const batch = await deleteQuery.find({ useMasterKey: true });
        if (!batch || batch.length === 0) break;
        for (const obj of batch) {
          await obj.destroy({ useMasterKey: true, context: { allowLegalHardDelete: true } });
          deletedCount += 1;
        }
      }
    }

    return {
      dryRun,
      targetVersion,
      effectiveDate: effectiveDate.toISOString(),
      activeFound: activeDocs.length,
      clonesPlanned: clones.length,
      activatedCount: activatedIds.length,
      deletedCount,
      safetyBackup,
    };
  });
}

module.exports = { registerLegalDevMaintenanceFunctions };
