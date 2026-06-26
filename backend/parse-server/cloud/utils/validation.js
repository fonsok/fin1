// ============================================================================
// Validation & Sanitization Utilities
// utils/validation.js
// ============================================================================
//
// Server-side input validation for onboarding and profile data.
// All user-supplied strings are trimmed and stripped of control characters
// before any format check runs.
//
// ============================================================================

'use strict';

// ---------------------------------------------------------------------------
// Primitives
// ---------------------------------------------------------------------------

function sanitize(val) {
  if (typeof val !== 'string') return val;
  // eslint-disable-next-line no-control-regex
  return val.replace(/[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]/g, '').trim();
}

function isNonEmpty(val) {
  return typeof val === 'string' && val.trim().length > 0;
}

function isStringInRange(val, min, max) {
  if (typeof val !== 'string') return false;
  const len = val.trim().length;
  return len >= min && len <= max;
}

function isInEnum(val, allowed) {
  return allowed.includes(val);
}

// ---------------------------------------------------------------------------
// Domain validators
// ---------------------------------------------------------------------------

const EMAIL_RE = /^[A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}$/;
function isValidEmail(val) {
  return typeof val === 'string' && EMAIL_RE.test(val.trim());
}

// International phone: optional +, then 7-15 digits (spaces/dashes stripped)
function isValidPhone(val) {
  if (typeof val !== 'string') return false;
  const digits = val.replace(/[\s\-().]/g, '');
  return /^\+?\d{7,15}$/.test(digits);
}

// German Steuer-ID: exactly 11 digits
function isValidGermanTaxId(val) {
  if (typeof val !== 'string') return false;
  return /^\d{11}$/.test(val.replace(/[\s\-/]/g, ''));
}

// German postal code: exactly 5 digits
function isValidGermanPostalCode(val) {
  if (typeof val !== 'string') return false;
  return /^\d{5}$/.test(val.trim());
}

// ISO date string, person must be >= 18 years old
function isValidBirthDate(val) {
  if (!val) return false;
  const d = new Date(val);
  if (isNaN(d.getTime())) return false;
  if (d > new Date()) return false;
  const age = (Date.now() - d.getTime()) / (365.25 * 24 * 60 * 60 * 1000);
  return age >= 18 && age <= 120;
}

function isBoolean(val) {
  return typeof val === 'boolean';
}

function isPositiveInt(val) {
  return Number.isInteger(val) && val >= 0;
}

// ---------------------------------------------------------------------------
// Sanitize an entire data object (recursive string trimming)
// ---------------------------------------------------------------------------

function sanitizeObject(obj) {
  if (!obj || typeof obj !== 'object') return obj;
  if (Array.isArray(obj)) return obj.map(sanitizeObject);
  const out = {};
  for (const [k, v] of Object.entries(obj)) {
    if (typeof v === 'string') {
      out[k] = sanitize(v);
    } else if (v && typeof v === 'object') {
      out[k] = sanitizeObject(v);
    } else {
      out[k] = v;
    }
  }
  return out;
}

// ---------------------------------------------------------------------------
// Per-step validation for completeOnboardingStep (Joi schemas — onboardingStepSchemas.js)
// Returns { valid: true } or { valid: false, message: '...' }
// ---------------------------------------------------------------------------

const {
  createValidateStepData,
  createValidatePartialOnboardingData,
} = require('./onboardingStepSchemas');

const validateStepData = createValidateStepData({
  isValidBirthDate,
  isValidGermanPostalCode,
  isValidGermanTaxId,
});

const validatePartialOnboardingData = createValidatePartialOnboardingData({
  isValidBirthDate,
  isValidGermanPostalCode,
  isValidGermanTaxId,
});

const {
  createValidateCompanyKybStepData,
  createValidatePartialCompanyKybData,
} = require('./companyKybStepSchemas');

const validateCompanyKybStepData = createValidateCompanyKybStepData({
  isValidBirthDate,
  isValidGermanPostalCode,
});

const validatePartialCompanyKybData = createValidatePartialCompanyKybData({
  isValidBirthDate,
  isValidGermanPostalCode,
});

// ---------------------------------------------------------------------------
// Profile update validation
// ---------------------------------------------------------------------------

function validateProfileUpdate(params) {
  const errors = [];
  if (params.firstName !== undefined) {
    if (!isStringInRange(params.firstName, 1, 100)) errors.push('firstName must be 1-100 characters');
  }
  if (params.lastName !== undefined) {
    if (!isStringInRange(params.lastName, 1, 100)) errors.push('lastName must be 1-100 characters');
  }
  if (params.phoneNumber !== undefined && params.phoneNumber !== '') {
    if (!isValidPhone(params.phoneNumber)) errors.push('Invalid phone number format');
  }
  if (params.dateOfBirth !== undefined) {
    if (!isValidBirthDate(params.dateOfBirth)) errors.push('Invalid date of birth or age < 18');
  }
  if (params.salutation !== undefined) {
    if (!isInEnum(params.salutation, ['Herr', 'Frau', 'Divers', 'mr', 'mrs', 'ms', 'dr', 'prof', 'diverse'])) {
      errors.push('Invalid salutation');
    }
  }
  if (params.username !== undefined && params.username !== '') {
    if (!isStringInRange(params.username, 4, 10)) errors.push('username must be 4-10 characters');
  }
  if (params.email !== undefined && params.email !== '') {
    if (!isValidEmail(params.email)) errors.push('Invalid email format');
  }
  if (params.streetAndNumber !== undefined && params.streetAndNumber !== '') {
    if (!isStringInRange(params.streetAndNumber, 1, 200)) errors.push('streetAndNumber must be 1-200 characters');
  }
  if (params.postalCode !== undefined && params.postalCode !== '') {
    const country = String(params.country || '').trim().toLowerCase();
    const isGermany = country === 'de' || country === 'deutschland' || country === 'germany';
    if (isGermany) {
      if (!isValidGermanPostalCode(params.postalCode)) errors.push('Invalid postal code format');
    } else if (!isStringInRange(params.postalCode, 2, 20)) {
      errors.push('postalCode must be 2-20 characters');
    }
  }
  if (params.city !== undefined && params.city !== '') {
    if (!isStringInRange(params.city, 1, 100)) errors.push('city must be 1-100 characters');
  }
  if (params.country !== undefined && params.country !== '') {
    if (!isStringInRange(params.country, 2, 100)) errors.push('country must be 2-100 characters');
  }
  if (params.state !== undefined && params.state !== '') {
    if (!isStringInRange(params.state, 1, 100)) errors.push('state must be 1-100 characters');
  }
  return errors.length ? { valid: false, message: errors.join('; ') } : { valid: true };
}

// ---------------------------------------------------------------------------
// Exports
// ---------------------------------------------------------------------------

module.exports = {
  sanitize,
  sanitizeObject,
  isNonEmpty,
  isStringInRange,
  isInEnum,
  isValidEmail,
  isValidPhone,
  isValidGermanTaxId,
  isValidGermanPostalCode,
  isValidBirthDate,
  isBoolean,
  isPositiveInt,
  validateStepData,
  validatePartialOnboardingData,
  validateCompanyKybStepData,
  validatePartialCompanyKybData,
  validateProfileUpdate,
};

console.log('Validation utilities loaded');
