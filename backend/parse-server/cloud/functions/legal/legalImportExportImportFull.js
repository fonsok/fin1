'use strict';

const { requireAdminRole, requirePermission } = require('../../utils/permissions');
const {
  normalizeString,
  validateLanguage,
  validateDocumentType,
} = require('./shared');
const { resolveBackupFromRequest } = require('./legalImportExportBackupInput');
const {
  TERMS_IMPORT_ARCHIVE_SCAN_LIMIT,
  TERMS_IMPORT_POST_RESTORE_PAGE,
} = require('./legalImportExportConstants');

function normalizeDocumentsForFullImport(documents) {
  const warnings = [];
  const normalizedDocs = documents.map((d, idx) => {
    const version = normalizeString(d?.version);
    const language = validateLanguage(d?.language);
    const documentType = validateDocumentType(d?.documentType);
    const effectiveDate = d?.effectiveDate ? new Date(d.effectiveDate) : new Date();
    if (!(effectiveDate instanceof Date) || isNaN(effectiveDate.getTime())) {
      throw new Parse.Error(Parse.Error.INVALID_VALUE, `Invalid effectiveDate at documents[${idx}]`);
    }
    const isActive = typeof d?.isActive === 'boolean' ? d.isActive : false;
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
      isActive,
      sections,
      _sourceObjectId: normalizeString(d?.objectId ?? null),
    };
  });

  const seenKeys = new Set();
  for (const d of normalizedDocs) {
    const key = `${d.documentType}:${d.language}:${d.version}:${d.effectiveDate.toISOString()}`;
    if (seenKeys.has(key)) {
      warnings.push(`Duplicate entry in backup: ${key}`);
    }
    seenKeys.add(key);
  }

  return { normalizedDocs, warnings };
}

async function handleImportLegalDocumentsBackup(request) {
  requireAdminRole(request);
  requirePermission(request, 'manageTemplates');

  const dryRun = !!request.params.dryRun;
  const archiveExisting = request.params.archiveExisting !== false;

  const { backup, documents } = resolveBackupFromRequest(request);
  const { normalizedDocs, warnings } = normalizeDocumentsForFullImport(documents);

  const termsQuery = new Parse.Query('TermsContent');
  termsQuery.limit(TERMS_IMPORT_ARCHIVE_SCAN_LIMIT);
  const existing = await termsQuery.find({ useMasterKey: true });
  if (existing.length >= TERMS_IMPORT_ARCHIVE_SCAN_LIMIT) {
    warnings.push(
      `Restore lädt maximal ${TERMS_IMPORT_ARCHIVE_SCAN_LIMIT} bestehende TermsContent-Zeilen; darüber hinausgehende Einträge würden nicht archiviert. Limit erhöhen oder Datenbestand vorab bereinigen.`
    );
  }

  let archivedCount = 0;
  if (archiveExisting && existing.length > 0) {
    for (const doc of existing) {
      const alreadyArchived = !!doc.get('archived');
      const wasActive = !!doc.get('isActive');
      if (!alreadyArchived || wasActive) {
        archivedCount += 1;
        if (!dryRun) {
          doc.set('archived', true);
          doc.set('archivedAt', new Date());
          doc.set('archivedBy', request.user?.id ?? null);
          doc.set('isActive', false);
        }
      }
    }
    if (!dryRun) {
      await Parse.Object.saveAll(existing, { useMasterKey: true });
    }
  }

  const TermsContent = Parse.Object.extend('TermsContent');
  const toCreate = normalizedDocs.map((d) => {
    const obj = new TermsContent();
    obj.set('version', d.version);
    obj.set('language', d.language);
    obj.set('documentType', d.documentType);
    obj.set('effectiveDate', d.effectiveDate);
    obj.set('sections', d.sections);
    obj.set('isActive', !!d.isActive);
    obj.set('restoredFromBackupAt', new Date());
    obj.set('restoredFromBackupId', normalizeString(backup.exportedAt ?? backup.id ?? null));
    obj.set('restoredFromSourceObjectId', d._sourceObjectId);
    return obj;
  });

  if (!dryRun) {
    await Parse.Object.saveAll(toCreate, { useMasterKey: true });
  }

  let fixedActiveConflicts = 0;
  if (!dryRun) {
    const restoredAt = toCreate[0]?.get('restoredFromBackupAt');
    const imported = [];
    if (restoredAt instanceof Date) {
      let skip = 0;
      // eslint-disable-next-line no-constant-condition
      while (true) {
        const importedQuery = new Parse.Query('TermsContent');
        importedQuery.equalTo('restoredFromBackupAt', restoredAt);
        importedQuery.limit(TERMS_IMPORT_POST_RESTORE_PAGE);
        importedQuery.skip(skip);
        const batch = await importedQuery.find({ useMasterKey: true });
        if (!batch || batch.length === 0) break;
        imported.push(...batch);
        if (batch.length < TERMS_IMPORT_POST_RESTORE_PAGE) break;
        skip += batch.length;
      }
    }

    const groups = new Map();
    for (const doc of imported) {
      const k = `${doc.get('documentType')}:${doc.get('language')}`;
      if (!groups.has(k)) groups.set(k, []);
      groups.get(k).push(doc);
    }

    const updates = [];
    for (const [, docs] of groups.entries()) {
      const activeDocs = docs.filter((d) => !!d.get('isActive'));
      if (activeDocs.length <= 1) continue;
      activeDocs.sort((a, b) => {
        const ad = a.get('effectiveDate') instanceof Date ? a.get('effectiveDate').getTime() : 0;
        const bd = b.get('effectiveDate') instanceof Date ? b.get('effectiveDate').getTime() : 0;
        return bd - ad;
      });
      for (const extra of activeDocs.slice(1)) {
        extra.set('isActive', false);
        updates.push(extra);
        fixedActiveConflicts += 1;
      }
    }
    if (updates.length > 0) {
      await Parse.Object.saveAll(updates, { useMasterKey: true });
    }
  }

  return {
    dryRun,
    archivedCount,
    importedCount: normalizedDocs.length,
    fixedActiveConflicts,
    warnings,
  };
}

module.exports = {
  handleImportLegalDocumentsBackup,
};
