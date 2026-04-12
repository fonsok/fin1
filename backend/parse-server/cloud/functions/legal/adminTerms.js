'use strict';

const { requireAdminRole, requirePermission } = require('../../utils/permissions');
const {
  normalizeString,
  validateLanguage,
  validateDocumentType,
  serializeTermsContent,
  DEFAULT_LEGAL_SNIPPETS_DE,
  DEFAULT_LEGAL_SNIPPETS_EN,
} = require('./shared');

function registerLegalAdminTermsFunctions() {
  Parse.Cloud.define('listTermsContent', async (request) => {
    requireAdminRole(request);
    requirePermission(request, 'manageTemplates');

    const documentType = request.params.documentType ? validateDocumentType(request.params.documentType) : null;
    const language = request.params.language ? validateLanguage(request.params.language) : null;
    const includeArchived = !!request.params.includeArchived;

    const query = new Parse.Query('TermsContent');
    if (documentType) query.equalTo('documentType', documentType);
    if (language) query.equalTo('language', language);
    if (!includeArchived) query.notEqualTo('archived', true);
    query.descending('effectiveDate');
    query.limit(200);

    const results = await query.find({ useMasterKey: true });
    return results.map((doc) => {
      const base = serializeTermsContent(doc);
      return {
        objectId: base.objectId,
        version: base.version,
        language: base.language,
        documentType: base.documentType,
        effectiveDate: base.effectiveDate,
        isActive: base.isActive,
        archived: !!doc.get('archived'),
        documentHash: base.documentHash,
        sectionCount: (doc.get('sections') || []).length,
        createdAt: base.createdAt,
        updatedAt: base.updatedAt,
      };
    });
  });

  Parse.Cloud.define('getTermsContent', async (request) => {
    requireAdminRole(request);
    requirePermission(request, 'manageTemplates');

    const { objectId } = request.params;
    if (!objectId) {
      throw new Parse.Error(Parse.Error.INVALID_QUERY, 'objectId is required');
    }

    const query = new Parse.Query('TermsContent');
    const doc = await query.get(objectId, { useMasterKey: true });
    if (!doc) {
      throw new Parse.Error(Parse.Error.OBJECT_NOT_FOUND, 'TermsContent not found');
    }

    return serializeTermsContent(doc);
  });

  Parse.Cloud.define('createTermsContent', async (request) => {
    requireAdminRole(request);
    requirePermission(request, 'manageTemplates');

    const { version, language, documentType, effectiveDate, isActive, sections } = request.params;

    const versionStr = normalizeString(version);
    if (!versionStr) {
      throw new Parse.Error(Parse.Error.INVALID_VALUE, 'version is required');
    }

    const lang = validateLanguage(language);
    const docType = validateDocumentType(documentType);

    if (!Array.isArray(sections) || sections.length === 0) {
      throw new Parse.Error(Parse.Error.INVALID_VALUE, 'sections must be a non-empty array');
    }

    const effectiveDateObj = effectiveDate ? new Date(effectiveDate) : new Date();
    if (isNaN(effectiveDateObj.getTime())) {
      throw new Parse.Error(Parse.Error.INVALID_VALUE, 'effectiveDate must be a valid ISO date string');
    }

    const TermsContent = Parse.Object.extend('TermsContent');
    const doc = new TermsContent();
    doc.set('version', versionStr);
    doc.set('language', lang);
    doc.set('documentType', docType);
    doc.set('effectiveDate', effectiveDateObj);
    doc.set('sections', sections);
    doc.set('isActive', typeof isActive === 'boolean' ? isActive : true);

    await doc.save(null, { useMasterKey: true });
    const base = serializeTermsContent(doc);

    return {
      objectId: base.objectId,
      version: base.version,
      language: base.language,
      documentType: base.documentType,
      effectiveDate: base.effectiveDate,
      isActive: base.isActive,
      documentHash: base.documentHash,
      sectionCount: (doc.get('sections') || []).length,
      createdAt: base.createdAt,
    };
  });

  Parse.Cloud.define('setActiveTermsContent', async (request) => {
    requireAdminRole(request);
    requirePermission(request, 'manageTemplates');

    const { objectId } = request.params;
    if (!objectId) {
      throw new Parse.Error(Parse.Error.INVALID_QUERY, 'objectId is required');
    }

    const query = new Parse.Query('TermsContent');
    const doc = await query.get(objectId, { useMasterKey: true });
    if (!doc) {
      throw new Parse.Error(Parse.Error.OBJECT_NOT_FOUND, 'TermsContent not found');
    }

    const language = doc.get('language');
    const documentType = doc.get('documentType');

    const currentQuery = new Parse.Query('TermsContent');
    currentQuery.equalTo('language', language);
    currentQuery.equalTo('documentType', documentType);
    currentQuery.equalTo('isActive', true);
    const currentActive = await currentQuery.find({ useMasterKey: true });

    for (const d of currentActive) {
      if (d.id !== doc.id) {
        d.set('isActive', false);
        await d.save(null, { useMasterKey: true });
      }
    }

    doc.set('isActive', true);
    await doc.save(null, { useMasterKey: true });

    return {
      success: true,
      objectId: doc.id,
      version: doc.get('version'),
      language: doc.get('language'),
      documentType: doc.get('documentType'),
    };
  });

  Parse.Cloud.define('getDefaultLegalSnippetSections', async (request) => {
    requireAdminRole(request);
    requirePermission(request, 'manageTemplates');

    const language = validateLanguage(request.params.language || 'de');
    const sections = language === 'de' ? DEFAULT_LEGAL_SNIPPETS_DE : DEFAULT_LEGAL_SNIPPETS_EN;
    return { sections: [...sections] };
  });

  Parse.Cloud.define('getDefaultLegalSnippetSectionsPublic', async (request) => {
    const language = validateLanguage(request.params.language || 'de');
    const sections = language === 'de' ? DEFAULT_LEGAL_SNIPPETS_DE : DEFAULT_LEGAL_SNIPPETS_EN;
    return { sections: [...sections] };
  });
}

module.exports = { registerLegalAdminTermsFunctions };
