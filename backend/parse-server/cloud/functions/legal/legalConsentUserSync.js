'use strict';

const { normalizeString } = require('./shared');

const CONSENT_TYPE_TO_USER_FIELDS = {
  terms_of_service: {
    acceptedFlag: 'acceptedTerms',
    versionField: 'acceptedTermsVersion',
    dateField: 'acceptedTermsDate',
  },
  privacy_policy: {
    acceptedFlag: 'acceptedPrivacyPolicy',
    versionField: 'acceptedPrivacyPolicyVersion',
    dateField: 'acceptedPrivacyPolicyDate',
  },
};

async function getCurrentActiveLegalVersion(documentType, language = 'de') {
  const q = new Parse.Query('TermsContent');
  q.equalTo('documentType', documentType);
  q.equalTo('language', language);
  q.equalTo('isActive', true);
  q.descending('effectiveDate');
  q.limit(1);
  const doc = await q.first({ useMasterKey: true });
  return doc ? normalizeString(doc.get('version')) : '';
}

async function findLatestLegalConsentVersion(userId, consentType) {
  const uid = normalizeString(userId);
  const type = normalizeString(consentType);
  if (!uid || !type) return '';

  const q = new Parse.Query('LegalConsent');
  q.equalTo('userId', uid);
  q.equalTo('consentType', type);
  q.equalTo('accepted', true);
  q.descending('acceptedAt');
  q.limit(1);
  const row = await q.first({ useMasterKey: true });
  return row ? normalizeString(row.get('version')) : '';
}

function readUserLegalField(user, field) {
  if (!user?.get) return null;
  const value = user.get(field);
  if (value instanceof Date) return value.toISOString();
  return value ?? null;
}

/**
 * Resolve effective legal acceptance for app session (getUserMe / login overlay).
 * Legacy users with acceptedTerms=true but no version inherit latest LegalConsent
 * or current active TermsContent version.
 */
async function resolveUserLegalAcceptanceState(user, options = {}) {
  const language = normalizeString(options.language || 'de') || 'de';
  if (!user?.id) {
    return {
      acceptedTerms: false,
      acceptedPrivacyPolicy: false,
      acceptedTermsVersion: null,
      acceptedPrivacyPolicyVersion: null,
      acceptedTermsDate: null,
      acceptedPrivacyPolicyDate: null,
    };
  }

  const acceptedTerms = user.get('acceptedTerms') === true;
  const acceptedPrivacyPolicy = user.get('acceptedPrivacyPolicy') === true;

  let acceptedTermsVersion = normalizeString(user.get('acceptedTermsVersion'));
  let acceptedPrivacyPolicyVersion = normalizeString(user.get('acceptedPrivacyPolicyVersion'));

  if (!acceptedTermsVersion && acceptedTerms) {
    acceptedTermsVersion = await findLatestLegalConsentVersion(user.id, 'terms_of_service')
      || await getCurrentActiveLegalVersion('terms', language);
  }
  if (!acceptedPrivacyPolicyVersion && acceptedPrivacyPolicy) {
    acceptedPrivacyPolicyVersion = await findLatestLegalConsentVersion(user.id, 'privacy_policy')
      || await getCurrentActiveLegalVersion('privacy', language);
  }

  return {
    acceptedTerms,
    acceptedPrivacyPolicy,
    acceptedTermsVersion: acceptedTermsVersion || null,
    acceptedPrivacyPolicyVersion: acceptedPrivacyPolicyVersion || null,
    acceptedTermsDate: readUserLegalField(user, 'acceptedTermsDate'),
    acceptedPrivacyPolicyDate: readUserLegalField(user, 'acceptedPrivacyPolicyDate'),
  };
}

/**
 * Persist resolved versions when legacy row had flags but no version columns.
 */
async function persistResolvedLegalAcceptanceIfNeeded(user, resolved) {
  if (!user?.id || !resolved) return false;

  let dirty = false;
  const storedTermsVersion = normalizeString(user.get('acceptedTermsVersion'));
  const storedPrivacyVersion = normalizeString(user.get('acceptedPrivacyPolicyVersion'));

  if (
    resolved.acceptedTerms
    && resolved.acceptedTermsVersion
    && storedTermsVersion !== resolved.acceptedTermsVersion
  ) {
    user.set('acceptedTerms', true);
    user.set('acceptedTermsVersion', resolved.acceptedTermsVersion);
    if (!user.get('acceptedTermsDate')) {
      user.set('acceptedTermsDate', new Date());
    }
    dirty = true;
  }

  if (
    resolved.acceptedPrivacyPolicy
    && resolved.acceptedPrivacyPolicyVersion
    && storedPrivacyVersion !== resolved.acceptedPrivacyPolicyVersion
  ) {
    user.set('acceptedPrivacyPolicy', true);
    user.set('acceptedPrivacyPolicyVersion', resolved.acceptedPrivacyPolicyVersion);
    if (!user.get('acceptedPrivacyPolicyDate')) {
      user.set('acceptedPrivacyPolicyDate', new Date());
    }
    dirty = true;
  }

  if (dirty) {
    await user.save(null, { useMasterKey: true });
  }
  return dirty;
}

async function syncParseUserLegalAcceptance(user, { consentType, version, acceptedAt }) {
  if (!user?.id) return null;

  const mapping = CONSENT_TYPE_TO_USER_FIELDS[consentType];
  const versionStr = normalizeString(version);
  if (!mapping || !versionStr) return null;

  const at = acceptedAt instanceof Date && !Number.isNaN(acceptedAt.getTime())
    ? acceptedAt
    : new Date();

  user.set(mapping.acceptedFlag, true);
  user.set(mapping.versionField, versionStr);
  user.set(mapping.dateField, at);
  await user.save(null, { useMasterKey: true });

  return {
    consentType,
    version: versionStr,
    acceptedAt: at.toISOString(),
  };
}

module.exports = {
  getCurrentActiveLegalVersion,
  findLatestLegalConsentVersion,
  resolveUserLegalAcceptanceState,
  persistResolvedLegalAcceptanceIfNeeded,
  syncParseUserLegalAcceptance,
};
