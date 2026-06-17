'use strict';

const {
  createValidateStepData,
  createValidatePartialOnboardingData,
} = require('../onboardingStepSchemas');

const validators = {
  isValidBirthDate: (v) => {
    if (!v) return false;
    const d = new Date(v);
    if (Number.isNaN(d.getTime())) return false;
    if (d > new Date()) return false;
    const age = (Date.now() - d.getTime()) / (365.25 * 24 * 60 * 60 * 1000);
    return age >= 18 && age <= 120;
  },
  isValidGermanPostalCode: (v) => typeof v === 'string' && /^\d{5}$/.test(v.trim()),
  isValidGermanTaxId: (v) => typeof v === 'string' && /^\d{11}$/.test(v.replace(/[\s\-/]/g, '')),
};

const validateStepData = createValidateStepData(validators);
const validatePartialOnboardingData = createValidatePartialOnboardingData(validators);

describe('onboardingStepSchemas', () => {
  test('complete personal accepts minimal valid payload', () => {
    expect(validateStepData('personal', { firstName: 'A', lastName: 'B' })).toEqual({ valid: true });
  });

  test('complete personal rejects empty firstName', () => {
    const r = validateStepData('personal', { firstName: '', lastName: 'B' });
    expect(r.valid).toBe(false);
    expect(r.message).toBeDefined();
  });

  test('partial personal allows missing names when other fields valid', () => {
    expect(validatePartialOnboardingData('personal', { nationality: 'DE' })).toEqual({ valid: true });
  });

  test('complete consents rejects explicit false', () => {
    const r = validateStepData('consents', { acceptedTerms: false });
    expect(r.valid).toBe(false);
  });

  test('unknown step returns valid for complete', () => {
    expect(validateStepData('unknownStep', { foo: 1 })).toEqual({ valid: true });
  });

  test('complete risk requires knowledge test answers but allows incorrect answers', () => {
    const payload = {
      leveragedProductsTotalLossRiskAcknowledged: true,
      leveragedProductsKnowledgeTestAnswers: { put_dow_jones_falling: 'C' },
      leveragedProductsKnowledgeTestPassed: false,
    };
    expect(validateStepData('risk', payload)).toEqual({ valid: true });
  });

  test('complete risk rejects missing knowledge test answers', () => {
    const r = validateStepData('risk', {
      leveragedProductsTotalLossRiskAcknowledged: true,
      leveragedProductsKnowledgeTestAnswers: {},
    });
    expect(r.valid).toBe(false);
    expect(r.message).toMatch(/put_dow_jones_falling/i);
  });

  test('complete risk accepts answer D as a valid option id', () => {
    const payload = {
      leveragedProductsTotalLossRiskAcknowledged: true,
      leveragedProductsKnowledgeTestAnswers: { put_dow_jones_falling: 'D' },
      leveragedProductsKnowledgeTestPassed: false,
    };
    expect(validateStepData('risk', payload)).toEqual({ valid: true });
  });
});
