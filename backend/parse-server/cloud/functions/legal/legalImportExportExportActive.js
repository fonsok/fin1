'use strict';

const { requireAdminRole, requirePermission } = require('../../utils/permissions');
const {
  validateLanguage,
  validateDocumentType,
  serializeTermsContentBackup,
} = require('./shared');
const { TERMS_EXPORT_ACTIVE_LIMIT } = require('./legalImportExportConstants');

async function handleExportActiveLegalDocumentsBackup(request) {
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
}

module.exports = {
  handleExportActiveLegalDocumentsBackup,
};
