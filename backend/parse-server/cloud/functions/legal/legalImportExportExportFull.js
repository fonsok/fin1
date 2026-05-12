'use strict';

const { requireAdminRole, requirePermission } = require('../../utils/permissions');
const { serializeTermsContentBackup } = require('./shared');
const { TERMS_EXPORT_FULL_LIMIT } = require('./legalImportExportConstants');

async function handleExportLegalDocumentsBackup(request) {
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
      `Export erreichte das Server-Limit von ${TERMS_EXPORT_FULL_LIMIT} TermsContent-Zeilen; ältere/weitere Versionen fehlen im JSON. Limit in legalImportExportConstants erhöhen oder gezielt exportieren.`
    );
  }

  return {
    exportedAt: new Date().toISOString(),
    version: '1.0',
    note: 'Backup AGB & Rechtstexte (TermsContent). Quelle: Admin-Portal AGB und Rechtstexte.',
    documents,
    warnings,
  };
}

module.exports = {
  handleExportLegalDocumentsBackup,
};
