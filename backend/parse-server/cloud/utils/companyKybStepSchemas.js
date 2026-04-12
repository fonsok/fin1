'use strict';

/**
 * Per-step Joi schemas for Company KYB payloads (ADR-003).
 * Complete-step schemas enforce required fields; partial schemas validate
 * types/enums only when keys are present (save for later).
 */

const Joi = require('joi');

function formatJoiError(error) {
  return error.details.map((d) => d.message.replace(/"/g, '')).join('; ');
}

function createCustom(validators) {
  const { isValidBirthDate, isValidGermanPostalCode } = validators;

  return {
    birthDateOptional: () =>
      Joi.any().custom((value, helpers) => {
        if (value === undefined || value === null || value === '') return value;
        if (typeof value !== 'string') return helpers.error('any.invalid');
        if (!isValidBirthDate(value)) return helpers.error('any.invalid');
        return value;
      }, 'valid birth date (18+)'),

    birthDateRequired: () =>
      Joi.any().custom((value, helpers) => {
        if (value === undefined || value === null || value === '') {
          return helpers.error('any.required');
        }
        if (typeof value !== 'string') return helpers.error('any.invalid');
        if (!isValidBirthDate(value)) return helpers.error('any.invalid');
        return value;
      }, 'valid birth date (18+) required'),

    postalOptional: () =>
      Joi.any().custom((value, helpers) => {
        if (value === undefined || value === null || value === '') return value;
        if (typeof value !== 'string') return helpers.error('any.invalid');
        if (!isValidGermanPostalCode(value)) return helpers.error('any.invalid');
        return value;
      }, 'postal code (5 digits when DE-style)'),
  };
}

function buildCompleteSchemas(custom) {
  const legalEntity = Joi.object({
    legalName: Joi.string().min(1).max(200).required(),
    legalForm: Joi.string().min(1).max(80).required(),
    registerType: Joi.string().min(1).max(80).required(),
    registerNumber: Joi.string().min(1).max(80).required(),
    registerCourt: Joi.string().min(1).max(120).required(),
    incorporationCountry: Joi.string().min(2).max(2).required(),
    notRegisteredReason: Joi.string().max(500).allow('', null).optional(),
  }).unknown(true);

  const registeredAddress = Joi.object({
    streetAndNumber: Joi.string().min(3).max(200).required(),
    postalCode: Joi.string().min(2).max(20).required(),
    city: Joi.string().min(1).max(100).required(),
    country: Joi.string().min(2).max(60).required(),
    businessStreetAndNumber: Joi.string().max(200).allow('', null).optional(),
    businessPostalCode: Joi.string().max(20).allow('', null).optional(),
    businessCity: Joi.string().max(100).allow('', null).optional(),
    businessCountry: Joi.string().max(60).allow('', null).optional(),
  }).unknown(true);

  const taxCompliance = Joi.object({
    vatId: Joi.string().max(32).allow('', null).optional(),
    nationalTaxNumber: Joi.string().max(32).allow('', null).optional(),
    economicIdentificationNumber: Joi.string().max(32).allow('', null).optional(),
    noVatIdDeclared: Joi.boolean().optional(),
  })
    .unknown(true)
    .custom((value, helpers) => {
      const hasVat = value.vatId && String(value.vatId).trim().length > 0;
      const hasNational = value.nationalTaxNumber && String(value.nationalTaxNumber).trim().length > 0;
      const noVat = value.noVatIdDeclared === true;
      if (hasVat || hasNational || noVat) return value;
      return helpers.error('any.custom', { message: 'Provide vatId, nationalTaxNumber, or noVatIdDeclared' });
    });

  const uboItem = Joi.object({
    fullName: Joi.string().min(1).max(200).required(),
    dateOfBirth: custom.birthDateRequired(),
    nationality: Joi.string().min(2).max(60).required(),
    ownershipPercent: Joi.number().min(0).max(100).allow(null).optional(),
    directOrIndirect: Joi.string().valid('direct', 'indirect', 'unknown').optional(),
  }).unknown(true);

  const beneficialOwners = Joi.object({
    ubos: Joi.array().items(uboItem).min(1).optional(),
    noUboOver25Percent: Joi.boolean().strict().valid(true).optional(),
  })
    .unknown(true)
    .custom((value, helpers) => {
      const hasUbos = Array.isArray(value.ubos) && value.ubos.length > 0;
      const noUbo = value.noUboOver25Percent === true;
      if (hasUbos || noUbo) return value;
      return helpers.error('any.custom', { message: 'Provide ubos or noUboOver25Percent' });
    });

  const repItem = Joi.object({
    fullName: Joi.string().min(1).max(200).required(),
    roleTitle: Joi.string().min(1).max(120).required(),
    signingAuthority: Joi.boolean().required(),
  }).unknown(true);

  const authorizedRepresentatives = Joi.object({
    representatives: Joi.array().items(repItem).min(1).required(),
    appAccountHolderIsRepresentative: Joi.boolean().optional(),
  }).unknown(true);

  const documents = Joi.object({
    tradeRegisterExtractReference: Joi.string().max(200).allow('', null).optional(),
    documentManifest: Joi.array()
      .items(
        Joi.object({
          documentType: Joi.string().max(80).required(),
          referenceId: Joi.string().max(200).required(),
        }).unknown(true)
      )
      .optional(),
    documentsAcknowledged: Joi.boolean().strict().valid(true).required(),
  }).unknown(true);

  const declarations = Joi.object({
    isPoliticallyExposed: Joi.boolean().required(),
    pepDetails: Joi.string().max(2000).allow('', null).optional(),
    sanctionsSelfDeclarationAccepted: Joi.boolean().strict().valid(true).required(),
    accuracyDeclarationAccepted: Joi.boolean().strict().valid(true).required(),
    noTrustThirdPartyDeclarationAccepted: Joi.boolean().strict().valid(true).required(),
  }).unknown(true);

  const submission = Joi.object({
    confirmedSummary: Joi.boolean().strict().valid(true).required(),
    companyFourEyesRequestId: Joi.string().max(120).allow('', null).optional(),
  }).unknown(true);

  return {
    legal_entity: legalEntity,
    registered_address: registeredAddress,
    tax_compliance: taxCompliance,
    beneficial_owners: beneficialOwners,
    authorized_representatives: authorizedRepresentatives,
    documents,
    declarations,
    submission,
  };
}

function buildPartialSchemas(custom) {
  const legalEntity = Joi.object({
    legalName: Joi.string().min(1).max(200).optional(),
    legalForm: Joi.string().min(1).max(80).optional(),
    registerType: Joi.string().min(1).max(80).optional(),
    registerNumber: Joi.string().min(1).max(80).optional(),
    registerCourt: Joi.string().min(1).max(120).optional(),
    incorporationCountry: Joi.string().min(2).max(2).optional(),
    notRegisteredReason: Joi.string().max(500).allow('', null).optional(),
  }).unknown(true);

  const registeredAddress = Joi.object({
    streetAndNumber: Joi.string().min(3).max(200).optional(),
    postalCode: Joi.string().min(2).max(20).optional(),
    city: Joi.string().min(1).max(100).optional(),
    country: Joi.string().min(2).max(60).optional(),
    businessStreetAndNumber: Joi.string().max(200).allow('', null).optional(),
    businessPostalCode: Joi.string().max(20).allow('', null).optional(),
    businessCity: Joi.string().max(100).allow('', null).optional(),
    businessCountry: Joi.string().max(60).allow('', null).optional(),
  }).unknown(true);

  const taxCompliance = Joi.object({
    vatId: Joi.string().max(32).allow('', null).optional(),
    nationalTaxNumber: Joi.string().max(32).allow('', null).optional(),
    economicIdentificationNumber: Joi.string().max(32).allow('', null).optional(),
    noVatIdDeclared: Joi.boolean().optional(),
  }).unknown(true);

  const uboItem = Joi.object({
    fullName: Joi.string().min(1).max(200).optional(),
    dateOfBirth: custom.birthDateOptional().optional(),
    nationality: Joi.string().min(2).max(60).optional(),
    ownershipPercent: Joi.number().min(0).max(100).allow(null).optional(),
    directOrIndirect: Joi.string().valid('direct', 'indirect', 'unknown').optional(),
  }).unknown(true);

  const beneficialOwners = Joi.object({
    ubos: Joi.array().items(uboItem).optional(),
    noUboOver25Percent: Joi.boolean().strict().optional(),
  }).unknown(true);

  const repItem = Joi.object({
    fullName: Joi.string().min(1).max(200).optional(),
    roleTitle: Joi.string().min(1).max(120).optional(),
    signingAuthority: Joi.boolean().optional(),
  }).unknown(true);

  const authorizedRepresentatives = Joi.object({
    representatives: Joi.array().items(repItem).optional(),
    appAccountHolderIsRepresentative: Joi.boolean().optional(),
  }).unknown(true);

  const documents = Joi.object({
    tradeRegisterExtractReference: Joi.string().max(200).allow('', null).optional(),
    documentManifest: Joi.array()
      .items(
        Joi.object({
          documentType: Joi.string().max(80).optional(),
          referenceId: Joi.string().max(200).optional(),
        }).unknown(true)
      )
      .optional(),
    documentsAcknowledged: Joi.boolean().strict().optional(),
  }).unknown(true);

  const declarations = Joi.object({
    isPoliticallyExposed: Joi.boolean().optional(),
    pepDetails: Joi.string().max(2000).allow('', null).optional(),
    sanctionsSelfDeclarationAccepted: Joi.boolean().strict().optional(),
    accuracyDeclarationAccepted: Joi.boolean().strict().optional(),
    noTrustThirdPartyDeclarationAccepted: Joi.boolean().strict().optional(),
  }).unknown(true);

  const submission = Joi.object({
    confirmedSummary: Joi.boolean().strict().optional(),
    companyFourEyesRequestId: Joi.string().max(120).allow('', null).optional(),
  }).unknown(true);

  return {
    legal_entity: legalEntity,
    registered_address: registeredAddress,
    tax_compliance: taxCompliance,
    beneficial_owners: beneficialOwners,
    authorized_representatives: authorizedRepresentatives,
    documents,
    declarations,
    submission,
  };
}

/**
 * @param {{ isValidBirthDate: Function, isValidGermanPostalCode: Function }} validators
 */
function createValidateCompanyKybStepData(validators) {
  const custom = createCustom(validators);
  const completeSchemas = buildCompleteSchemas(custom);

  return function validateCompanyKybStepData(step, data) {
    if (!data) return { valid: true };
    const schema = completeSchemas[step];
    if (!schema) return { valid: true };

    const { error } = schema.validate(data, { abortEarly: false, stripUnknown: false });
    if (error) {
      return { valid: false, message: formatJoiError(error) };
    }
    return { valid: true };
  };
}

function createValidatePartialCompanyKybData(validators) {
  const custom = createCustom(validators);
  const partialSchemas = buildPartialSchemas(custom);

  return function validatePartialCompanyKybData(step, data) {
    if (!data) return { valid: true };
    const schema = partialSchemas[step];
    if (!schema) {
      return { valid: true };
    }

    const { error } = schema.validate(data, { abortEarly: false, stripUnknown: false });
    if (error) {
      return { valid: false, message: formatJoiError(error) };
    }
    return { valid: true };
  };
}

module.exports = {
  createValidateCompanyKybStepData,
  createValidatePartialCompanyKybData,
};
