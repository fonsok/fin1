'use strict';

const { TERMINAL_STATUSES } = require('./userCompanyKybConstants');

/**
 * Atomically increments companyKybRevision on the user.
 * Returns the new revision value. Uses Parse increment() which maps
 * to MongoDB $inc – safe against concurrent writers.
 */
function bumpRevision(user) {
  user.increment('companyKybRevision', 1);
}

function assertCompanyKybEligible(user) {
  const accountType = user.get('accountType');
  const role = user.get('role');
  if (accountType !== 'company') {
    throw new Parse.Error(
      Parse.Error.OPERATION_FORBIDDEN,
      'Company KYB is only available for company accounts'
    );
  }
  if (role !== 'investor') {
    throw new Parse.Error(
      Parse.Error.OPERATION_FORBIDDEN,
      'Company KYB is only available for investor accounts'
    );
  }
}

function assertNotTerminal(user) {
  const status = user.get('companyKybStatus');
  if (TERMINAL_STATUSES.includes(status)) {
    throw new Parse.Error(
      Parse.Error.OPERATION_FORBIDDEN,
      `KYB is in terminal status: ${status}`
    );
  }
}

async function getCompletedStepKeys(userId) {
  const query = new Parse.Query('CompanyKybAudit');
  query.equalTo('userId', userId);
  query.select('step');
  const entries = await query.find({ useMasterKey: true });
  return new Set(entries.map((e) => e.get('step')));
}

function buildAuditAnswers(step, data) {
  if (!data) return null;

  switch (step) {
    case 'legal_entity':
      return {
        legalName: data.legalName,
        legalForm: data.legalForm,
        registerType: data.registerType,
        registerNumber: data.registerNumber,
        registerCourt: data.registerCourt,
        incorporationCountry: data.incorporationCountry,
      };
    case 'registered_address':
      return {
        streetAndNumber: data.streetAndNumber,
        postalCode: data.postalCode,
        city: data.city,
        country: data.country,
      };
    case 'tax_compliance':
      return {
        hasVatId: Boolean(data.vatId && String(data.vatId).trim()),
        hasNationalTaxNumber: Boolean(data.nationalTaxNumber && String(data.nationalTaxNumber).trim()),
        noVatIdDeclared: data.noVatIdDeclared,
      };
    case 'beneficial_owners':
      return {
        uboCount: Array.isArray(data.ubos) ? data.ubos.length : 0,
        noUboOver25Percent: data.noUboOver25Percent,
      };
    case 'authorized_representatives':
      return {
        representativeCount: Array.isArray(data.representatives) ? data.representatives.length : 0,
        appAccountHolderIsRepresentative: data.appAccountHolderIsRepresentative,
      };
    case 'documents':
      return {
        documentsAcknowledged: data.documentsAcknowledged,
        manifestCount: Array.isArray(data.documentManifest) ? data.documentManifest.length : 0,
      };
    case 'declarations':
      return {
        isPoliticallyExposed: data.isPoliticallyExposed,
        sanctionsSelfDeclarationAccepted: data.sanctionsSelfDeclarationAccepted,
        accuracyDeclarationAccepted: data.accuracyDeclarationAccepted,
        noTrustThirdPartyDeclarationAccepted: data.noTrustThirdPartyDeclarationAccepted,
      };
    case 'submission':
      return {
        confirmedSummary: data.confirmedSummary,
        companyFourEyesRequestId: data.companyFourEyesRequestId,
      };
    default:
      return null;
  }
}

module.exports = {
  bumpRevision,
  assertCompanyKybEligible,
  assertNotTerminal,
  getCompletedStepKeys,
  buildAuditAnswers,
};
