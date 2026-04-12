'use strict';

const {
  normalizeString,
  getRequestIP,
  getUserAgent,
  validateLanguage,
  validateDocumentType,
  serializeTermsContent,
} = require('./shared');

function registerLegalPublicAuditFunctions() {
  Parse.Cloud.define('getCurrentTerms', async (request) => {
    const language = validateLanguage(request.params.language);
    const documentType = validateDocumentType(request.params.documentType);

    const query = new Parse.Query('TermsContent');
    query.equalTo('language', language);
    query.equalTo('documentType', documentType);
    query.equalTo('isActive', true);
    query.descending('effectiveDate');
    query.limit(1);

    const doc = await query.first({ useMasterKey: true });
    if (!doc) {
      throw new Parse.Error(Parse.Error.OBJECT_NOT_FOUND, 'No active legal document found');
    }

    return serializeTermsContent(doc);
  });

  Parse.Cloud.define('getCurrentLegalDocument', async (request) => {
    return Parse.Cloud.run('getCurrentTerms', request.params, { useMasterKey: false });
  });

  Parse.Cloud.define('logLegalDocumentDelivery', async (request) => {
    const documentType = validateDocumentType(request.params.documentType);
    const language = validateLanguage(request.params.language);

    const servedVersion = normalizeString(request.params.servedVersion);
    if (!servedVersion) {
      throw new Parse.Error(Parse.Error.INVALID_VALUE, 'servedVersion is required');
    }

    const source = normalizeString(request.params.source || 'server');
    const allowedSources = ['server', 'cache', 'bundled'];
    if (!allowedSources.includes(source)) {
      throw new Parse.Error(Parse.Error.INVALID_VALUE, `Invalid source: ${source}`);
    }

    const deviceInstallId = normalizeString(request.params.deviceInstallId);
    if (!deviceInstallId) {
      throw new Parse.Error(Parse.Error.INVALID_VALUE, 'deviceInstallId is required');
    }

    const platform = normalizeString(request.params.platform || 'ios');
    const appVersion = normalizeString(request.params.appVersion || '');
    const buildNumber = normalizeString(request.params.buildNumber || '');
    const servedHash = normalizeString(request.params.servedHash || null);

    const dedupeWindowSecondsRaw = request.params.dedupeWindowSeconds;
    const dedupeWindowSeconds =
      typeof dedupeWindowSecondsRaw === 'number' && dedupeWindowSecondsRaw > 0
        ? dedupeWindowSecondsRaw
        : 86400;

    const since = new Date(Date.now() - dedupeWindowSeconds * 1000);
    const dedupeQuery = new Parse.Query('LegalDocumentDeliveryLog');
    dedupeQuery.equalTo('documentType', documentType);
    dedupeQuery.equalTo('language', language);
    dedupeQuery.equalTo('servedVersion', servedVersion);
    dedupeQuery.equalTo('deviceInstallId', deviceInstallId);
    dedupeQuery.equalTo('appVersion', appVersion);
    dedupeQuery.greaterThan('createdAt', since);
    dedupeQuery.limit(1);

    const existing = await dedupeQuery.first({ useMasterKey: true });
    if (existing) {
      return { skipped: true, objectId: existing.id };
    }

    const Delivery = Parse.Object.extend('LegalDocumentDeliveryLog');
    const entry = new Delivery();

    entry.set('documentType', documentType);
    entry.set('language', language);
    entry.set('servedVersion', servedVersion);
    if (servedHash) entry.set('servedHash', servedHash);
    entry.set('source', source);

    entry.set('platform', platform);
    entry.set('appVersion', appVersion);
    entry.set('buildNumber', buildNumber);
    entry.set('deviceInstallId', deviceInstallId);

    if (request.user) {
      entry.set('userId', request.user.id);
    }

    entry.set('ipAddress', getRequestIP(request));
    entry.set('userAgent', getUserAgent(request));

    const servedAt = request.params.servedAt ? new Date(request.params.servedAt) : null;
    if (servedAt instanceof Date && !isNaN(servedAt.valueOf())) {
      entry.set('servedAt', servedAt);
    }

    const saved = await entry.save(null, { useMasterKey: true });
    return { skipped: false, objectId: saved.id, createdAt: saved.createdAt?.toISOString?.() ?? null };
  });

  Parse.Cloud.define('recordLegalConsent', async (request) => {
    const consentType = normalizeString(request.params.consentType);
    const allowedConsentTypes = ['terms_of_service', 'privacy_policy', 'imprint'];
    if (!allowedConsentTypes.includes(consentType)) {
      throw new Parse.Error(Parse.Error.INVALID_VALUE, `Invalid consentType: ${consentType}`);
    }

    const version = normalizeString(request.params.version);
    if (!version) {
      throw new Parse.Error(Parse.Error.INVALID_VALUE, 'version is required');
    }

    const deviceInstallId = normalizeString(request.params.deviceInstallId);
    if (!deviceInstallId) {
      throw new Parse.Error(Parse.Error.INVALID_VALUE, 'deviceInstallId is required');
    }

    const Consent = Parse.Object.extend('LegalConsent');
    const entry = new Consent();

    entry.set('consentType', consentType);
    entry.set('version', version);

    const documentHash = normalizeString(request.params.documentHash || null);
    if (documentHash) entry.set('documentHash', documentHash);

    const documentUrl = normalizeString(request.params.documentUrl || null);
    if (documentUrl) entry.set('documentUrl', documentUrl);

    entry.set('accepted', true);

    const acceptedAt = request.params.acceptedAt ? new Date(request.params.acceptedAt) : new Date();
    entry.set('acceptedAt', acceptedAt);

    entry.set('platform', normalizeString(request.params.platform || 'ios'));
    entry.set('appVersion', normalizeString(request.params.appVersion || ''));
    entry.set('buildNumber', normalizeString(request.params.buildNumber || ''));
    entry.set('deviceInstallId', deviceInstallId);

    if (request.user) {
      entry.set('userId', request.user.id);
    }

    entry.set('ipAddress', getRequestIP(request));
    entry.set('userAgent', getUserAgent(request));

    const saved = await entry.save(null, { useMasterKey: true });
    return { objectId: saved.id, acceptedAt: saved.get('acceptedAt')?.toISOString?.() ?? null };
  });
}

module.exports = { registerLegalPublicAuditFunctions };
