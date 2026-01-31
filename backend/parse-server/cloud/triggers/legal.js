// ============================================================================
// FIN1 Parse Cloud Code
// triggers/legal.js - Legal Document Triggers
// ============================================================================
//
// Purpose:
// - Ensure legal documents have a stable content hash for auditability
// - Normalize basic fields (trim, defaults)
//
// Parse Classes:
// - TermsContent (documentType: "terms" | "privacy" | "imprint")
//
// ============================================================================

'use strict';

const crypto = require('crypto');

function normalizeString(value) {
  if (typeof value !== 'string') return value;
  return value.trim();
}

function getEnvString(key, fallback) {
  const v = process.env[key];
  if (typeof v !== 'string') return fallback;
  const t = v.trim();
  if (!t) return fallback;
  return t;
}

function replaceAll(source, search, replacement) {
  if (typeof source !== 'string') return source;
  if (!search) return source;
  return source.split(search).join(replacement);
}

function buildPlaceholderMap() {
  // IMPORTANT (audit clean):
  // These values represent what will be *stored* and therefore hashed and served.
  // If they change, you MUST create a new TermsContent version (do not edit old ones).
  const commissionRatePercent = getEnvString('FIN1_LEGAL_COMMISSION_RATE_PERCENT', '10');

  const platformName = getEnvString('FIN1_LEGAL_PLATFORM_NAME', 'FIN1');
  const companyLegalName = getEnvString('FIN1_LEGAL_COMPANY_LEGAL_NAME', 'FIN1 Investing GmbH');

  const companyAddress = getEnvString('FIN1_LEGAL_COMPANY_ADDRESS', 'Hauptstraße 100');
  const companyCity = getEnvString('FIN1_LEGAL_COMPANY_CITY', '60311 Frankfurt am Main');
  const companyAddressLine = getEnvString(
    'FIN1_LEGAL_COMPANY_ADDRESS_LINE',
    `${companyAddress}, ${companyCity}`
  );

  const companyRegisterNumber = getEnvString('FIN1_LEGAL_COMPANY_REGISTER_NUMBER', 'HRB 123456');
  const companyVatId = getEnvString('FIN1_LEGAL_COMPANY_VAT_ID', 'DE123456789');
  const companyManagement = getEnvString('FIN1_LEGAL_COMPANY_MANAGEMENT', 'Max Mustermann');

  const bankName = getEnvString('FIN1_LEGAL_BANK_NAME', `${platformName} Bank AG`);
  const bankIBAN = getEnvString('FIN1_LEGAL_BANK_IBAN', 'DE89 3704 0044 0532 0130 00');
  const bankBIC = getEnvString('FIN1_LEGAL_BANK_BIC', 'COBADEFFXXX');

  const companyEmail = getEnvString('FIN1_LEGAL_COMPANY_EMAIL', 'info@fin1-investing.de');
  const companyPhone = getEnvString('FIN1_LEGAL_COMPANY_PHONE', '+49 (0) 69 12345678');
  const companyWebsite = getEnvString('FIN1_LEGAL_COMPANY_WEBSITE', 'www.fin1-investing.de');

  return {
    '{{COMMISSION_RATE}}': commissionRatePercent,

    '{{LEGAL_PLATFORM_NAME}}': platformName,
    '{{LEGAL_COMPANY_LEGAL_NAME}}': companyLegalName,
    '{{LEGAL_COMPANY_ADDRESS}}': companyAddress,
    '{{LEGAL_COMPANY_CITY}}': companyCity,
    '{{LEGAL_COMPANY_ADDRESS_LINE}}': companyAddressLine,
    '{{LEGAL_COMPANY_REGISTER_NUMBER}}': companyRegisterNumber,
    '{{LEGAL_COMPANY_VAT_ID}}': companyVatId,
    '{{LEGAL_COMPANY_MANAGEMENT}}': companyManagement,

    '{{LEGAL_BANK_NAME}}': bankName,
    '{{LEGAL_BANK_IBAN}}': bankIBAN,
    '{{LEGAL_BANK_BIC}}': bankBIC,

    '{{LEGAL_COMPANY_EMAIL}}': companyEmail,
    '{{LEGAL_COMPANY_PHONE}}': companyPhone,
    '{{LEGAL_COMPANY_WEBSITE}}': companyWebsite,
  };
}

function resolvePlaceholdersInSections(sections, placeholderMap) {
  if (!Array.isArray(sections)) return [];
  return sections.map((s) => {
    const originalTitle = normalizeString(s?.title ?? '');
    const originalContent = normalizeString(s?.content ?? '');

    let title = originalTitle;
    let content = originalContent;

    for (const [placeholder, value] of Object.entries(placeholderMap)) {
      title = replaceAll(title, placeholder, value);
      content = replaceAll(content, placeholder, value);
    }

    // One-time remediation for legacy naming ("Trading GmbH" -> "Investing GmbH")
    title = replaceAll(title, 'Trading GmbH', 'Investing GmbH');
    content = replaceAll(content, 'Trading GmbH', 'Investing GmbH');

    return {
      id: normalizeString(s?.id ?? ''),
      title,
      content,
      icon: normalizeString(s?.icon ?? ''),
    };
  });
}

function canonicalizeSections(sections) {
  if (!Array.isArray(sections)) return [];
  return sections.map((s) => ({
    id: normalizeString(s?.id ?? ''),
    title: normalizeString(s?.title ?? ''),
    content: normalizeString(s?.content ?? ''),
    icon: normalizeString(s?.icon ?? '')
  }));
}

function computeDocumentHash({ version, language, documentType, effectiveDateISO, sections }) {
  const payload = {
    version: normalizeString(version ?? ''),
    language: normalizeString(language ?? ''),
    documentType: normalizeString(documentType ?? ''),
    effectiveDate: normalizeString(effectiveDateISO ?? ''),
    sections: canonicalizeSections(sections)
  };
  const json = JSON.stringify(payload);
  return crypto.createHash('sha256').update(json, 'utf8').digest('hex');
}

Parse.Cloud.beforeSave('TermsContent', async (request) => {
  // Best practice: legal documents must be immutable from clients.
  // Only allow writes via Dashboard / server-side master operations.
  if (!request.master) {
    throw new Parse.Error(Parse.Error.OPERATION_FORBIDDEN, 'TermsContent is server-managed');
  }

  const obj = request.object;
  const original = request.original;

  // Basic normalization
  obj.set('version', normalizeString(obj.get('version')));
  obj.set('language', normalizeString(obj.get('language')));
  obj.set('documentType', normalizeString(obj.get('documentType')));

  // Audit-safe immutability:
  // - legal texts are append-only; do NOT edit historical content
  // - allow updates ONLY to isActive (to switch which version is current)
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
    // Do not recompute/overwrite sections; keep historical hash stable.
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

  // Ensure effectiveDate exists (required for ordering and audit)
  const effectiveDate = obj.get('effectiveDate');
  if (!(effectiveDate instanceof Date)) {
    throw new Parse.Error(Parse.Error.INVALID_VALUE, 'effectiveDate must be a Date');
  }

  // Ensure sections shape is valid
  const sections = obj.get('sections');
  if (!Array.isArray(sections) || sections.length === 0) {
    throw new Parse.Error(Parse.Error.INVALID_VALUE, 'sections must be a non-empty array');
  }

  const version = obj.get('version');
  if (!version || typeof version !== 'string' || version.trim().length === 0) {
    throw new Parse.Error(Parse.Error.INVALID_VALUE, 'version is required');
  }

  // Resolve placeholders on the server so that:
  // - the stored TermsContent reflects what users see (iOS guidelines)
  // - documentHash is a stable hash of the served content (audit trail)
  const placeholderMap = buildPlaceholderMap();
  const resolvedSections = resolvePlaceholdersInSections(sections, placeholderMap);
  obj.set('sections', resolvedSections);

  // Compute stable hash (store in documentHash)
  const documentHash = computeDocumentHash({
    version,
    language,
    documentType,
    effectiveDateISO: effectiveDate.toISOString(),
    sections: resolvedSections
  });
  obj.set('documentHash', documentHash);

  // Defaults
  if (typeof obj.get('isActive') !== 'boolean') {
    obj.set('isActive', true);
  }
});

Parse.Cloud.beforeSave('LegalDocumentDeliveryLog', async (request) => {
  // Append-only audit log, written via Cloud Functions using master key.
  if (!request.master) {
    throw new Parse.Error(Parse.Error.OPERATION_FORBIDDEN, 'Delivery logs are server-managed');
  }
});

Parse.Cloud.beforeSave('LegalConsent', async (request) => {
  // Append-only consent audit, written via Cloud Functions using master key.
  if (!request.master) {
    throw new Parse.Error(Parse.Error.OPERATION_FORBIDDEN, 'Consent logs are server-managed');
  }
});

