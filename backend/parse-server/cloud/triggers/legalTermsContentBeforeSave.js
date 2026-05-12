'use strict';

const {
  normalizeString,
  buildPlaceholderMap,
  resolvePlaceholdersInSections,
  computeDocumentHash,
} = require('./legalTermsContentHelpers');

Parse.Cloud.beforeSave('TermsContent', async (request) => {
  if (!request.master) {
    throw new Parse.Error(Parse.Error.OPERATION_FORBIDDEN, 'TermsContent is server-managed');
  }

  const obj = request.object;
  const original = request.original;

  obj.set('version', normalizeString(obj.get('version')));
  obj.set('language', normalizeString(obj.get('language')));
  obj.set('documentType', normalizeString(obj.get('documentType')));

  if (original) {
    const lockedFields = ['version', 'language', 'documentType', 'effectiveDate', 'sections'];
    for (const field of lockedFields) {
      const a = original.get(field);
      const b = obj.get(field);
      const same = JSON.stringify(a) === JSON.stringify(b);
      if (!same) {
        throw new Parse.Error(Parse.Error.OPERATION_FORBIDDEN, `TermsContent is immutable; create a new version instead (${field})`);
      }
    }
    return;
  }

  const documentType = obj.get('documentType') || 'terms';
  const allowedTypes = ['terms', 'privacy', 'imprint'];
  if (!allowedTypes.includes(documentType)) {
    throw new Parse.Error(Parse.Error.INVALID_VALUE, `Invalid documentType: ${documentType}`);
  }

  const language = obj.get('language') || 'en';
  const allowedLanguages = ['en', 'de'];
  if (!allowedLanguages.includes(language)) {
    throw new Parse.Error(Parse.Error.INVALID_VALUE, `Invalid language: ${language}`);
  }

  const effectiveDate = obj.get('effectiveDate');
  if (!(effectiveDate instanceof Date)) {
    throw new Parse.Error(Parse.Error.INVALID_VALUE, 'effectiveDate must be a Date');
  }

  const sections = obj.get('sections');
  if (!Array.isArray(sections) || sections.length === 0) {
    throw new Parse.Error(Parse.Error.INVALID_VALUE, 'sections must be a non-empty array');
  }

  const version = obj.get('version');
  if (!version || typeof version !== 'string' || version.trim().length === 0) {
    throw new Parse.Error(Parse.Error.INVALID_VALUE, 'version is required');
  }

  const placeholderMap = await buildPlaceholderMap();
  const resolvedSections = resolvePlaceholdersInSections(sections, placeholderMap);
  obj.set('sections', resolvedSections);

  const documentHash = computeDocumentHash({
    version,
    language,
    documentType,
    effectiveDateISO: effectiveDate.toISOString(),
    sections: resolvedSections,
  });
  obj.set('documentHash', documentHash);

  if (typeof obj.get('isActive') !== 'boolean') {
    obj.set('isActive', true);
  }
});
