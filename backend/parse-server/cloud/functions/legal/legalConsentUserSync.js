'use strict';

const { normalizeString } = require('./shared');
const { isLegalVersionOutdated } = require('../../utils/legalVersionCompare');

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
  trader_agreement: {
    acceptedFlag: 'acceptedTraderAgreement',
    versionField: 'acceptedTraderAgreementVersion',
    dateField: 'acceptedTraderAgreementDate',
  },
  investor_agreement: {
    acceptedFlag: 'acceptedInvestorAgreement',
    versionField: 'acceptedInvestorAgreementVersion',
    dateField: 'acceptedInvestorAgreementDate',
  },
};

const ROLE_TO_CONSENT_TYPE = {
  trader: 'trader_agreement',
  investor: 'investor_agreement',
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

async function syncParseUserRoleAgreementAcceptance(user, { role, version, acceptedAt }) {
  const roleKey = normalizeString(role)?.toLowerCase();
  const consentType = ROLE_TO_CONSENT_TYPE[roleKey];
  if (!consentType) return null;
  return syncParseUserLegalAcceptance(user, { consentType, version, acceptedAt });
}

async function resolveUserRoleAgreementState(user, options = {}) {
  const language = normalizeString(options.language || 'de') || 'de';
  const role = normalizeString(user?.get?.('role') || user?.role)?.toLowerCase();
  if (role !== 'trader' && role !== 'investor') {
    return { required: false, accepted: true, version: null, acceptedAt: null };
  }

  const consentType = ROLE_TO_CONSENT_TYPE[role];
  const mapping = CONSENT_TYPE_TO_USER_FIELDS[consentType];
  let accepted = user.get(mapping.acceptedFlag) === true;
  let version = normalizeString(user.get(mapping.versionField));

  if (!accepted) {
    const consentVersion = await findLatestLegalConsentVersion(user.id, consentType);
    if (consentVersion) {
      accepted = true;
      version = consentVersion;
    }
  }

  if (!version && accepted) {
    version = await findLatestLegalConsentVersion(user.id, consentType)
      || await getCurrentActiveLegalVersion(
        role === 'trader' ? 'trader_agreement' : 'investor_agreement',
        language,
      );
  }

  return {
    required: true,
    role,
    consentType,
    accepted,
    version: version || null,
    acceptedAt: readUserLegalField(user, mapping.dateField),
  };
}

async function persistResolvedRoleAgreementIfNeeded(user, resolved) {
  if (!user?.id || !resolved?.required || !resolved.accepted) return false;

  const mapping = CONSENT_TYPE_TO_USER_FIELDS[resolved.consentType];
  if (!mapping) return false;

  const storedVersion = normalizeString(user.get(mapping.versionField));
  const resolvedVersion = normalizeString(resolved.version);
  const flagAlreadySet = user.get(mapping.acceptedFlag) === true;

  if (flagAlreadySet && storedVersion === resolvedVersion) {
    return false;
  }

  user.set(mapping.acceptedFlag, true);
  if (resolvedVersion) {
    user.set(mapping.versionField, resolvedVersion);
  }
  if (!user.get(mapping.dateField)) {
    user.set(mapping.dateField, new Date());
  }
  await user.save(null, { useMasterKey: true });
  return true;
}

const RE_CONSENT_LEGAL_SPECS = [
  {
    consentType: 'terms_of_service',
    documentType: 'terms',
    acceptedFlag: 'acceptedTerms',
    versionField: 'acceptedTermsVersion',
    blocking: true,
    requiresScrollToAccept: false,
  },
  {
    consentType: 'privacy_policy',
    documentType: 'privacy',
    acceptedFlag: 'acceptedPrivacyPolicy',
    versionField: 'acceptedPrivacyPolicyVersion',
    blocking: true,
    requiresScrollToAccept: false,
  },
];

/**
 * Lists consents where stored user version is set and older than active TermsContent.
 * Legacy users without version columns are not forced into re-consent (grandfather).
 */
async function resolveRequiredReConsents(user, options = {}) {
  const language = normalizeString(options.language || 'de') || 'de';
  if (!user?.id) {
    return { required: [] };
  }

  const required = [];

  for (const spec of RE_CONSENT_LEGAL_SPECS) {
    if (user.get(spec.acceptedFlag) !== true) {
      continue;
    }

    const userVersion = normalizeString(user.get(spec.versionField));
    if (!userVersion) {
      continue;
    }

    const activeVersion = await getCurrentActiveLegalVersion(spec.documentType, language);
    if (!activeVersion || !isLegalVersionOutdated(userVersion, activeVersion)) {
      continue;
    }

    required.push({
      consentType: spec.consentType,
      documentType: spec.documentType,
      activeVersion,
      userVersion,
      blocking: spec.blocking,
      requiresScrollToAccept: spec.requiresScrollToAccept,
    });
  }

  const role = normalizeString(user.get('role'))?.toLowerCase();
  if (role === 'trader' || role === 'investor') {
    const consentType = ROLE_TO_CONSENT_TYPE[role];
    const mapping = CONSENT_TYPE_TO_USER_FIELDS[consentType];
    const documentType = role === 'trader' ? 'trader_agreement' : 'investor_agreement';

    if (user.get(mapping.acceptedFlag) === true) {
      const userVersion = normalizeString(user.get(mapping.versionField));
      if (userVersion) {
        const activeVersion = await getCurrentActiveLegalVersion(documentType, language);
        if (activeVersion && isLegalVersionOutdated(userVersion, activeVersion)) {
          required.push({
            consentType,
            documentType,
            activeVersion,
            userVersion,
            blocking: true,
            requiresScrollToAccept: true,
          });
        }
      }
    }
  }

  return { required };
}

module.exports = {
  getCurrentActiveLegalVersion,
  findLatestLegalConsentVersion,
  resolveUserLegalAcceptanceState,
  resolveUserRoleAgreementState,
  resolveRequiredReConsents,
  persistResolvedLegalAcceptanceIfNeeded,
  persistResolvedRoleAgreementIfNeeded,
  syncParseUserLegalAcceptance,
  syncParseUserRoleAgreementAcceptance,
};
