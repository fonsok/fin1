'use strict';

const { normalizeString, getRequestIP, getUserAgent } = require('./shared');
const {
  getCurrentActiveLegalVersion,
  syncParseUserLegalAcceptance,
} = require('./legalConsentUserSync');

const CONSENT_SPECS = {
  terms_of_service: {
    documentType: 'terms',
    acceptedFlag: 'acceptedTerms',
    requiresDataKey: 'acceptedTerms',
    versionDataKey: 'termsVersion',
  },
  privacy_policy: {
    documentType: 'privacy',
    acceptedFlag: 'acceptedPrivacyPolicy',
    requiresDataKey: 'acceptedPrivacyPolicy',
    versionDataKey: 'privacyVersion',
  },
};

async function findExistingLegalConsent({ userId, consentType, version }) {
  const uid = normalizeString(userId);
  const type = normalizeString(consentType);
  const versionStr = normalizeString(version);
  if (!uid || !type || !versionStr) return null;

  const q = new Parse.Query('LegalConsent');
  q.equalTo('userId', uid);
  q.equalTo('consentType', type);
  q.equalTo('version', versionStr);
  q.equalTo('accepted', true);
  q.descending('acceptedAt');
  q.limit(1);
  return q.first({ useMasterKey: true });
}

async function getActiveDocumentHash(documentType, language = 'de') {
  const q = new Parse.Query('TermsContent');
  q.equalTo('documentType', documentType);
  q.equalTo('language', language);
  q.equalTo('isActive', true);
  q.descending('effectiveDate');
  q.limit(1);
  const doc = await q.first({ useMasterKey: true });
  return doc ? normalizeString(doc.get('documentHash')) : '';
}

/**
 * Persist one LegalConsent audit row (+ optional _User sync).
 * Idempotent per user/consentType/version.
 */
async function recordLegalConsentEntry({
  request,
  user,
  consentType,
  version,
  deviceInstallId,
  platform = 'ios',
  appVersion = '',
  buildNumber = '',
  documentHash = null,
  documentUrl = null,
  acceptedAt = null,
  source = 'app',
  syncUser = true,
}) {
  const type = normalizeString(consentType);
  const versionStr = normalizeString(version);
  const installId = normalizeString(deviceInstallId);
  if (!type || !versionStr || !installId) {
    throw new Parse.Error(Parse.Error.INVALID_VALUE, 'consentType, version and deviceInstallId are required');
  }

  const at = acceptedAt instanceof Date && !Number.isNaN(acceptedAt.getTime())
    ? acceptedAt
    : new Date();

  const userId = user?.id || null;
  if (userId) {
    const existing = await findExistingLegalConsent({ userId, consentType: type, version: versionStr });
    if (existing) {
      if (syncUser && user) {
        await syncParseUserLegalAcceptance(user, { consentType: type, version: versionStr, acceptedAt: at });
      }
      return {
        objectId: existing.id,
        acceptedAt: existing.get('acceptedAt')?.toISOString?.() ?? at.toISOString(),
        skipped: true,
      };
    }
  }

  const Consent = Parse.Object.extend('LegalConsent');
  const entry = new Consent();
  entry.set('consentType', type);
  entry.set('version', versionStr);
  entry.set('accepted', true);
  entry.set('acceptedAt', at);
  entry.set('platform', normalizeString(platform) || 'ios');
  entry.set('appVersion', normalizeString(appVersion));
  entry.set('buildNumber', normalizeString(buildNumber));
  entry.set('deviceInstallId', installId);
  entry.set('source', normalizeString(source) || 'app');

  const hash = normalizeString(documentHash);
  if (hash) entry.set('documentHash', hash);
  const url = normalizeString(documentUrl);
  if (url) entry.set('documentUrl', url);

  if (userId) entry.set('userId', userId);
  if (request) {
    entry.set('ipAddress', getRequestIP(request));
    entry.set('userAgent', getUserAgent(request));
  }

  const saved = await entry.save(null, { useMasterKey: true });

  if (syncUser && user) {
    await syncParseUserLegalAcceptance(user, { consentType: type, version: versionStr, acceptedAt: at });
  }

  return {
    objectId: saved.id,
    acceptedAt: saved.get('acceptedAt')?.toISOString?.() ?? at.toISOString(),
    skipped: false,
  };
}

function resolveConsentLanguage(data) {
  const country = normalizeString(data?.country || '').toLowerCase();
  if (country.includes('united states') || country === 'us' || country === 'usa') return 'en';
  return 'de';
}

/**
 * Called from completeOnboardingStep(consents): writes LegalConsent rows for AGB + DSE.
 * Server-side document version/hash is SSOT; client-sent versions are fallback only.
 */
async function persistOnboardingLegalConsents(request, user, data) {
  if (!user?.id || !data) return { recorded: [] };

  if (data.acceptedTerms !== true || data.acceptedPrivacyPolicy !== true) {
    throw new Parse.Error(Parse.Error.INVALID_VALUE, 'acceptedTerms and acceptedPrivacyPolicy must be true');
  }

  const language = resolveConsentLanguage(data);
  const acceptedAt = new Date();
  const deviceInstallId = normalizeString(data.deviceInstallId) || `onboarding:${user.id}`;
  const platform = normalizeString(data.platform) || 'ios';
  const appVersion = normalizeString(data.appVersion) || '';
  const buildNumber = normalizeString(data.buildNumber) || '';

  user.set('acceptedTerms', true);
  user.set('acceptedPrivacyPolicy', true);
  user.set('acceptedMarketingConsent', data.acceptedMarketingConsent === true);

  const recorded = [];

  for (const [consentType, spec] of Object.entries(CONSENT_SPECS)) {
    const serverVersion = await getCurrentActiveLegalVersion(spec.documentType, language);
    const clientVersion = normalizeString(data[spec.versionDataKey]);
    const version = serverVersion || clientVersion;
    if (!version) {
      throw new Parse.Error(
        Parse.Error.OBJECT_NOT_FOUND,
        `No active ${spec.documentType} document for language ${language}`
      );
    }

    const documentHash = await getActiveDocumentHash(spec.documentType, language);
    const result = await recordLegalConsentEntry({
      request,
      user,
      consentType,
      version,
      deviceInstallId,
      platform,
      appVersion,
      buildNumber,
      documentHash: documentHash || null,
      acceptedAt,
      source: 'onboarding',
      syncUser: true,
    });

    recorded.push({
      consentType,
      version,
      objectId: result.objectId,
      skipped: result.skipped === true,
    });
  }

  return { recorded };
}

async function findDeviceLegalConsentAcknowledgements(userId, deviceInstallId) {
  const uid = normalizeString(userId);
  const installId = normalizeString(deviceInstallId);
  if (!uid || !installId) return [];

  const q = new Parse.Query('LegalConsent');
  q.equalTo('userId', uid);
  q.equalTo('deviceInstallId', installId);
  q.equalTo('accepted', true);
  q.descending('acceptedAt');
  q.limit(50);
  const rows = await q.find({ useMasterKey: true });

  const seen = new Set();
  const acknowledgements = [];
  for (const row of rows) {
    const consentType = normalizeString(row.get('consentType'));
    const version = normalizeString(row.get('version'));
    if (!consentType || !version) continue;
    const key = `${consentType}:${version}`;
    if (seen.has(key)) continue;
    seen.add(key);
    acknowledgements.push({ consentType, version });
  }
  return acknowledgements;
}

module.exports = {
  findExistingLegalConsent,
  getActiveDocumentHash,
  recordLegalConsentEntry,
  persistOnboardingLegalConsents,
  findDeviceLegalConsentAcknowledgements,
};
