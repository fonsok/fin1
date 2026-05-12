'use strict';

const crypto = require('crypto');
const { loadConfig } = require('../utils/configHelper/index.js');

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

async function buildPlaceholderMap() {
  const commissionRatePercent = getEnvString('FIN1_LEGAL_COMMISSION_RATE_PERCENT', '10');

  const cfg = await loadConfig(false);
  const platformName = (cfg?.legal?.platformName && String(cfg.legal.platformName).trim()) || getEnvString('FIN1_LEGAL_PLATFORM_NAME', 'App');
  const appName = (cfg?.legal?.appName && String(cfg.legal.appName).trim()) || getEnvString('FIN1_LEGAL_APP_NAME', platformName);
  const companyLegalName = getEnvString('FIN1_LEGAL_COMPANY_LEGAL_NAME', 'Company Investing GmbH');

  const companyAddress = getEnvString('FIN1_LEGAL_COMPANY_ADDRESS', 'Hauptstraße 100');
  const companyCity = getEnvString('FIN1_LEGAL_COMPANY_CITY', '60311 Frankfurt am Main');
  const companyAddressLine = getEnvString(
    'FIN1_LEGAL_COMPANY_ADDRESS_LINE',
    `${companyAddress}, ${companyCity}`,
  );

  const companyRegisterNumber = getEnvString('FIN1_LEGAL_COMPANY_REGISTER_NUMBER', 'HRB 123456');
  const companyVatId = getEnvString('FIN1_LEGAL_COMPANY_VAT_ID', 'DE123456789');
  const companyManagement = getEnvString('FIN1_LEGAL_COMPANY_MANAGEMENT', 'Max Mustermann');

  const bankName = getEnvString('FIN1_LEGAL_BANK_NAME', `${platformName} Bank AG`);
  const bankIBAN = getEnvString('FIN1_LEGAL_BANK_IBAN', 'DE89 3704 0044 0532 0130 00');
  const bankBIC = getEnvString('FIN1_LEGAL_BANK_BIC', 'COBADEFFXXX');

  const companyEmail = getEnvString('FIN1_LEGAL_COMPANY_EMAIL', 'support@example.com');
  const companyPhone = getEnvString('FIN1_LEGAL_COMPANY_PHONE', '+49 (0) 69 12345678');
  const companyWebsite = getEnvString('FIN1_LEGAL_COMPANY_WEBSITE', 'www.example.com');

  return {
    '{{COMMISSION_RATE}}': commissionRatePercent,

    '{{LEGAL_PLATFORM_NAME}}': platformName,
    '{{APP_NAME}}': appName,
    '{{PLATFORM_NAME}}': platformName,
    '{{PRODUCT_NAME}}': appName,
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
    icon: normalizeString(s?.icon ?? ''),
  }));
}

function computeDocumentHash({ version, language, documentType, effectiveDateISO, sections }) {
  const payload = {
    version: normalizeString(version ?? ''),
    language: normalizeString(language ?? ''),
    documentType: normalizeString(documentType ?? ''),
    effectiveDate: normalizeString(effectiveDateISO ?? ''),
    sections: canonicalizeSections(sections),
  };
  const json = JSON.stringify(payload);
  return crypto.createHash('sha256').update(json, 'utf8').digest('hex');
}

module.exports = {
  normalizeString,
  buildPlaceholderMap,
  resolvePlaceholdersInSections,
  canonicalizeSections,
  computeDocumentHash,
};
