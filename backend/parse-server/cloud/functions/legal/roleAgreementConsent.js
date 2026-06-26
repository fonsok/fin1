'use strict';

const { normalizeString, getRequestIP, getUserAgent } = require('./shared');
const {
  getCurrentActiveLegalVersion,
  syncParseUserRoleAgreementAcceptance,
} = require('./legalConsentUserSync');
const { getActiveDocumentHash, recordLegalConsentEntry } = require('./legalConsentRecording');
const { sendRoleAgreementConfirmationEmail } = require('./roleAgreementEmail');
const { loadConfig } = require('../../utils/configHelper/index.js');

const ROLE_CONSENT_SPECS = {
  trader: {
    consentType: 'trader_agreement',
    documentType: 'trader_agreement',
    acceptedFlag: 'acceptedTraderAgreement',
    versionField: 'acceptedTraderAgreementVersion',
    dateField: 'acceptedTraderAgreementDate',
    versionDataKey: 'traderAgreementVersion',
    requiresDataKey: 'acceptedTraderAgreement',
  },
  investor: {
    consentType: 'investor_agreement',
    documentType: 'investor_agreement',
    acceptedFlag: 'acceptedInvestorAgreement',
    versionField: 'acceptedInvestorAgreementVersion',
    dateField: 'acceptedInvestorAgreementDate',
    versionDataKey: 'investorAgreementVersion',
    requiresDataKey: 'acceptedInvestorAgreement',
  },
};

function resolveConsentLanguage(data) {
  const country = normalizeString(data?.country || '').toLowerCase();
  if (country.includes('united states') || country === 'us' || country === 'usa') return 'en';
  return 'de';
}

function resolveRetailRole(user, data) {
  const fromUser = normalizeString(user?.get?.('role') || user?.role);
  const userRole = typeof fromUser === 'string' ? fromUser.toLowerCase() : '';
  if (userRole === 'trader' || userRole === 'investor') return userRole;

  const fromData = normalizeString(data?.userRole);
  const dataRole = typeof fromData === 'string' ? fromData.toLowerCase() : '';
  if (dataRole === 'trader' || dataRole === 'investor') return dataRole;

  return null;
}

function formatPercentDE(value) {
  const num = Number(value);
  if (!Number.isFinite(num)) return '0 %';
  return `${new Intl.NumberFormat('de-DE', { maximumFractionDigits: 2 }).format(num * 100)} %`;
}

async function buildRoleAgreementReplacements() {
  const liveConfig = await loadConfig();
  const fin = liveConfig?.financial || {};
  const legal = liveConfig?.legal || {};

  const traderPerformanceFee = Number.isFinite(fin.traderCommissionRate)
    ? fin.traderCommissionRate
    : 0.05;
  const investorPerformanceFee = Number.isFinite(fin.investorCommissionRateTotal)
    ? fin.investorCommissionRateTotal
    : 0.1;
  const investorVolumeFee = Number.isFinite(fin.appServiceChargeRate)
    ? fin.appServiceChargeRate
    : 0.01;

  return {
    APP_NAME: legal.appName || 'FIN1',
    LEGAL_PLATFORM_NAME: legal.platformName || 'FIN1',
    LEGAL_COMPANY_LEGAL_NAME: legal.companyLegalName || legal.platformName || 'FIN1',
    TRADER_PERFORMANCE_FEE_RATE: formatPercentDE(traderPerformanceFee),
    INVESTOR_PERFORMANCE_FEE_RATE: formatPercentDE(investorPerformanceFee),
    INVESTOR_VOLUME_FEE_RATE: formatPercentDE(investorVolumeFee),
  };
}

/**
 * Records role-specific agreement consent (trader / investor) with audit trail.
 * Idempotent per user/consentType/version/source/deviceInstallId.
 */
async function recordRoleAgreementConsentEntry({
  request,
  user,
  role,
  version,
  deviceInstallId,
  platform = 'ios',
  appVersion = '',
  buildNumber = '',
  documentHash = null,
  acceptedAt = null,
  source = 'onboarding',
  sendConfirmationEmail = true,
}) {
  const roleKey = normalizeString(role)?.toLowerCase();
  const spec = ROLE_CONSENT_SPECS[roleKey];
  if (!spec) {
    throw new Parse.Error(Parse.Error.INVALID_VALUE, `Invalid role for role agreement: ${role}`);
  }

  const versionStr = normalizeString(version);
  const installId = normalizeString(deviceInstallId);
  if (!versionStr || !installId) {
    throw new Parse.Error(Parse.Error.INVALID_VALUE, 'version and deviceInstallId are required');
  }

  const at = acceptedAt instanceof Date && !Number.isNaN(acceptedAt.getTime())
    ? acceptedAt
    : new Date();

  const result = await recordLegalConsentEntry({
    request,
    user,
    consentType: spec.consentType,
    version: versionStr,
    deviceInstallId: installId,
    platform,
    appVersion,
    buildNumber,
    documentHash: documentHash || null,
    acceptedAt: at,
    source,
    syncUser: false,
  });

  if (user?.id) {
    await syncParseUserRoleAgreementAcceptance(user, {
      role: roleKey,
      version: versionStr,
      acceptedAt: at,
    });
  }

  if (sendConfirmationEmail && user?.id && result.skipped !== true) {
    sendRoleAgreementConfirmationEmail({
      user,
      role: roleKey,
      version: versionStr,
      acceptedAt: at,
      documentHash: documentHash || null,
      ipAddress: request ? getRequestIP(request) : null,
      userAgent: request ? getUserAgent(request) : null,
    }).catch((err) => {
      console.error(`[RoleAgreement] confirmation email failed for ${user.id}:`, err.message);
    });
  }

  return {
    role: roleKey,
    consentType: spec.consentType,
    version: versionStr,
    objectId: result.objectId,
    acceptedAt: result.acceptedAt,
    skipped: result.skipped === true,
  };
}

/**
 * Called during onboarding finalize or dedicated cloud function.
 */
async function persistOnboardingRoleAgreementConsent(request, user, data) {
  if (!user?.id || !data) return { recorded: null };

  const role = resolveRetailRole(user, data);
  const spec = role ? ROLE_CONSENT_SPECS[role] : null;
  if (!spec) return { recorded: null };

  if (data[spec.requiresDataKey] !== true) {
    throw new Parse.Error(
      Parse.Error.INVALID_VALUE,
      `${spec.requiresDataKey} must be true for role ${role}`,
    );
  }

  const language = resolveConsentLanguage(data);
  const acceptedAt = new Date();
  const deviceInstallId = normalizeString(data.deviceInstallId) || `onboarding:${user.id}`;
  const platform = normalizeString(data.platform) || 'ios';
  const appVersion = normalizeString(data.appVersion) || '';
  const buildNumber = normalizeString(data.buildNumber) || '';

  const serverVersion = await getCurrentActiveLegalVersion(spec.documentType, language);
  const clientVersion = normalizeString(data[spec.versionDataKey]);
  const version = serverVersion || clientVersion;
  if (!version) {
    throw new Parse.Error(
      Parse.Error.OBJECT_NOT_FOUND,
      `No active ${spec.documentType} document for language ${language}`,
    );
  }

  const documentHash = await getActiveDocumentHash(spec.documentType, language);
  const recorded = await recordRoleAgreementConsentEntry({
    request,
    user,
    role,
    version,
    deviceInstallId,
    platform,
    appVersion,
    buildNumber,
    documentHash: documentHash || null,
    acceptedAt,
    source: 'onboarding',
    sendConfirmationEmail: true,
  });

  return { recorded };
}

function registerRoleAgreementConsentFunctions() {
  Parse.Cloud.define('recordRoleAgreementConsent', async (request) => {
    const user = request.user;
    if (!user) {
      throw new Parse.Error(Parse.Error.INVALID_SESSION_TOKEN, 'Login required');
    }

    const role = resolveRetailRole(user, request.params);
    if (!role) {
      throw new Parse.Error(Parse.Error.INVALID_VALUE, 'User role must be trader or investor');
    }

    const version = normalizeString(request.params.version);
    if (!version) {
      throw new Parse.Error(Parse.Error.INVALID_VALUE, 'version is required');
    }

    const deviceInstallId = normalizeString(request.params.deviceInstallId);
    if (!deviceInstallId) {
      throw new Parse.Error(Parse.Error.INVALID_VALUE, 'deviceInstallId is required');
    }

    const documentHash = normalizeString(request.params.documentHash || null);
    const acceptedAt = request.params.acceptedAt ? new Date(request.params.acceptedAt) : new Date();

    const result = await recordRoleAgreementConsentEntry({
      request,
      user,
      role,
      version,
      deviceInstallId,
      platform: normalizeString(request.params.platform || 'ios'),
      appVersion: normalizeString(request.params.appVersion || ''),
      buildNumber: normalizeString(request.params.buildNumber || ''),
      documentHash: documentHash || null,
      acceptedAt,
      source: normalizeString(request.params.source) || 'onboarding',
      sendConfirmationEmail: request.params.sendConfirmationEmail !== false,
    });

    return {
      objectId: result.objectId,
      acceptedAt: result.acceptedAt,
      consentType: result.consentType,
      version: result.version,
      skipped: result.skipped === true,
    };
  });
}

module.exports = {
  ROLE_CONSENT_SPECS,
  buildRoleAgreementReplacements,
  recordRoleAgreementConsentEntry,
  persistOnboardingRoleAgreementConsent,
  registerRoleAgreementConsentFunctions,
  resolveRetailRole,
};
