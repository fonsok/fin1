'use strict';

const { requireAdminRole, requirePermission } = require('../../utils/permissions');
const {
  normalizeString,
  validateLanguage,
  validateDocumentType,
} = require('./shared');
const { resolveBackupFromRequest } = require('./legalImportExportBackupInput');

function normalizeDocumentsForActiveImport(documents) {
  const warnings = [];
  const normalizedDocs = documents.map((d, idx) => {
    const version = normalizeString(d?.version);
    const language = validateLanguage(d?.language);
    const documentType = validateDocumentType(d?.documentType);
    const effectiveDate = d?.effectiveDate ? new Date(d.effectiveDate) : new Date();
    if (!(effectiveDate instanceof Date) || isNaN(effectiveDate.getTime())) {
      throw new Parse.Error(Parse.Error.INVALID_VALUE, `Invalid effectiveDate at documents[${idx}]`);
    }
    const sections = Array.isArray(d?.sections) ? d.sections : null;
    if (!sections || sections.length === 0) {
      throw new Parse.Error(Parse.Error.INVALID_VALUE, `sections must be a non-empty array at documents[${idx}]`);
    }
    if (!version) {
      throw new Parse.Error(Parse.Error.INVALID_VALUE, `version is required at documents[${idx}]`);
    }
    return {
      version,
      language,
      documentType,
      effectiveDate,
      sections,
      _sourceObjectId: normalizeString(d?.objectId ?? null),
    };
  });

  const groupCounts = new Map();
  for (const d of normalizedDocs) {
    const k = `${d.documentType}:${d.language}`;
    groupCounts.set(k, (groupCounts.get(k) ?? 0) + 1);
  }
  for (const [k, n] of groupCounts.entries()) {
    if (n > 1) {
      warnings.push(`Backup contains ${n} documents for ${k}; all will be imported and newest effectiveDate will be activated.`);
    }
  }

  return { normalizedDocs, warnings, groupCounts };
}

async function handleImportActiveLegalDocumentsBackup(request) {
  requireAdminRole(request);
  requirePermission(request, 'manageTemplates');

  const dryRun = !!request.params.dryRun;

  const { backup, documents } = resolveBackupFromRequest(request);
  const { normalizedDocs, warnings, groupCounts } = normalizeDocumentsForActiveImport(documents);

  if (dryRun) {
    return { dryRun: true, createdCount: normalizedDocs.length, activatedCount: groupCounts.size, warnings };
  }

  const TermsContent = Parse.Object.extend('TermsContent');
  const created = [];
  for (const d of normalizedDocs) {
    const obj = new TermsContent();
    obj.set('version', d.version);
    obj.set('language', d.language);
    obj.set('documentType', d.documentType);
    obj.set('effectiveDate', d.effectiveDate);
    obj.set('sections', d.sections);
    obj.set('isActive', false);
    obj.set('restoredFromBackupAt', new Date());
    obj.set('restoredFromBackupId', normalizeString(backup.exportedAt ?? backup.id ?? null));
    obj.set('restoredFromSourceObjectId', d._sourceObjectId);
    created.push(obj);
  }

  await Parse.Object.saveAll(created, { useMasterKey: true });

  const groups = new Map();
  for (const obj of created) {
    const k = `${obj.get('documentType')}:${obj.get('language')}`;
    if (!groups.has(k)) groups.set(k, []);
    groups.get(k).push(obj);
  }

  let activatedCount = 0;
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
      if (d.id !== newest.id) {
        d.set('isActive', false);
      }
    }

    newest.set('isActive', true);

    const toSave = [...currentActive, newest];
    if (toSave.length > 0) {
      await Parse.Object.saveAll(toSave, { useMasterKey: true });
    }

    activatedCount += 1;
  }

  return { dryRun: false, createdCount: created.length, activatedCount, warnings };
}

module.exports = {
  handleImportActiveLegalDocumentsBackup,
};
