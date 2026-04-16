'use strict';

const { requireAdminRole, requirePermission } = require('../../utils/permissions');
const {
  normalizeString,
  validateLanguage,
  validateDocumentType,
  serializeTermsContentBackup,
} = require('./shared');

const TERMS_EXPORT_FULL_LIMIT = 500;
const TERMS_EXPORT_ACTIVE_LIMIT = 50;
const TERMS_IMPORT_ARCHIVE_SCAN_LIMIT = 1000;
/** Page size when loading freshly imported rows for active-flag dedupe (must paginate; no hard cap on total). */
const TERMS_IMPORT_POST_RESTORE_PAGE = 1000;

function registerLegalImportExportFunctions() {
  Parse.Cloud.define('exportLegalDocumentsBackup', async (request) => {
    requireAdminRole(request);
    requirePermission(request, 'manageTemplates');

    const query = new Parse.Query('TermsContent');
    query.descending('effectiveDate');
    query.limit(TERMS_EXPORT_FULL_LIMIT);
    const docs = await query.find({ useMasterKey: true });

    const documents = docs.map((doc) => serializeTermsContentBackup(doc));
    const warnings = [];
    if (docs.length >= TERMS_EXPORT_FULL_LIMIT) {
      warnings.push(
        `Export erreichte das Server-Limit von ${TERMS_EXPORT_FULL_LIMIT} TermsContent-Zeilen; ältere/weitere Versionen fehlen im JSON. Limit in importExport.js erhöhen oder gezielt exportieren.`
      );
    }

    return {
      exportedAt: new Date().toISOString(),
      version: '1.0',
      note: 'Backup AGB & Rechtstexte (TermsContent). Quelle: Admin-Portal AGB und Rechtstexte.',
      documents,
      warnings,
    };
  });

  Parse.Cloud.define('exportActiveLegalDocumentsBackup', async (request) => {
    requireAdminRole(request);
    requirePermission(request, 'manageTemplates');

    const documentType = request.params.documentType ? validateDocumentType(request.params.documentType) : null;
    const language = request.params.language ? validateLanguage(request.params.language) : null;

    const query = new Parse.Query('TermsContent');
    query.equalTo('isActive', true);
    query.notEqualTo('archived', true);
    if (documentType) query.equalTo('documentType', documentType);
    if (language) query.equalTo('language', language);
    query.descending('effectiveDate');
    query.limit(TERMS_EXPORT_ACTIVE_LIMIT);

    const docs = await query.find({ useMasterKey: true });
    const documents = docs.map((doc) => serializeTermsContentBackup(doc));
    const warnings = [];
    if (docs.length >= TERMS_EXPORT_ACTIVE_LIMIT) {
      warnings.push(
        `Active-Export erreichte das Server-Limit von ${TERMS_EXPORT_ACTIVE_LIMIT} Zeilen; bei Filter „alle“ können nicht alle aktiven Dokumente enthalten sein. Filter setzen oder Limit erhöhen.`
      );
    }

    return {
      exportedAt: new Date().toISOString(),
      version: '1.0',
      note: 'Active-only backup AGB & Rechtstexte (TermsContent). Quelle: Admin-Portal AGB und Rechtstexte.',
      filter: {
        documentType: documentType ?? 'all',
        language: language ?? 'all',
        activeOnly: true,
      },
      documents,
      warnings,
    };
  });

  Parse.Cloud.define('importLegalDocumentsBackup', async (request) => {
    requireAdminRole(request);
    requirePermission(request, 'manageTemplates');

    const dryRun = !!request.params.dryRun;
    const archiveExisting = request.params.archiveExisting !== false;

    let backup = request.params.backup;
    if (!backup && typeof request.params.backupJson === 'string') {
      try {
        backup = JSON.parse(request.params.backupJson);
      } catch (e) {
        throw new Parse.Error(Parse.Error.INVALID_JSON, 'backupJson is not valid JSON');
      }
    }

    if (!backup || typeof backup !== 'object') {
      throw new Parse.Error(Parse.Error.INVALID_VALUE, 'backup (object) or backupJson (string) is required');
    }

    const documents = Array.isArray(backup.documents) ? backup.documents : null;
    if (!documents || documents.length === 0) {
      throw new Parse.Error(Parse.Error.INVALID_VALUE, 'backup.documents must be a non-empty array');
    }

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
  });

  Parse.Cloud.define('importActiveLegalDocumentsBackup', async (request) => {
    requireAdminRole(request);
    requirePermission(request, 'manageTemplates');

    const dryRun = !!request.params.dryRun;

    let backup = request.params.backup;
    if (!backup && typeof request.params.backupJson === 'string') {
      try {
        backup = JSON.parse(request.params.backupJson);
      } catch {
        throw new Parse.Error(Parse.Error.INVALID_JSON, 'backupJson is not valid JSON');
      }
    }

    if (!backup || typeof backup !== 'object') {
      throw new Parse.Error(Parse.Error.INVALID_VALUE, 'backup (object) or backupJson (string) is required');
    }

    const documents = Array.isArray(backup.documents) ? backup.documents : null;
    if (!documents || documents.length === 0) {
      throw new Parse.Error(Parse.Error.INVALID_VALUE, 'backup.documents must be a non-empty array');
    }

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
      if (n > 1) warnings.push(`Backup contains ${n} documents for ${k}; all will be imported and newest effectiveDate will be activated.`);
    }

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
  });
}

module.exports = { registerLegalImportExportFunctions };
