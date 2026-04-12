// ============================================================================
// Parse Cloud Code
// functions/legal.js - Legal Document Functions (Terms/Privacy/Imprint)
// ============================================================================
//
// Goals:
// - Server-driven legal documents with versioning + effective dates
// - Audit trail: which app version/device/user received which legal text version
// - Optional consent recording (acceptance)
//
// Parse Classes:
// - TermsContent              (source of truth for legal docs)
// - LegalDocumentDeliveryLog  (append-only delivery audit)
// - LegalConsent              (append-only acceptance audit)
//
// ============================================================================

'use strict';

const { registerLegalPublicAuditFunctions } = require('./legal/publicAudit');
const { registerLegalAdminTermsFunctions } = require('./legal/adminTerms');
const { registerLegalImportExportFunctions } = require('./legal/importExport');
const { registerLegalBrandingFunctions } = require('./legal/branding');
const { registerLegalDevMaintenanceFunctions } = require('./legal/devMaintenance');

registerLegalPublicAuditFunctions();
registerLegalAdminTermsFunctions();
registerLegalImportExportFunctions();
registerLegalBrandingFunctions();
registerLegalDevMaintenanceFunctions();

console.log('Legal cloud functions loaded');

