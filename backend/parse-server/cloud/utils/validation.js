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
// Per-step validation for completeOnboardingStep
// Returns { valid: true } or { valid: false, message: '...' }
// ---------------------------------------------------------------------------

function validateStepData(step, data) {
  if (!data) return { valid: true };

  switch (step) {
    case 'personal': {
      const errors = [];
      if (!isNonEmpty(data.firstName)) errors.push('firstName is required');
      if (!isNonEmpty(data.lastName)) errors.push('lastName is required');
      if (data.firstName && !isStringInRange(data.firstName, 1, 100)) errors.push('firstName too long');
      if (data.lastName && !isStringInRange(data.lastName, 1, 100)) errors.push('lastName too long');
      if (data.dateOfBirth && !isValidBirthDate(data.dateOfBirth)) errors.push('Invalid date of birth or age < 18');
      if (data.salutation && !isInEnum(data.salutation, ['Herr', 'Frau', 'Divers', 'mr', 'mrs', 'diverse'])) {
        errors.push('Invalid salutation');
      }
      if (data.accountType && !isInEnum(data.accountType, ['individual', 'joint', 'business'])) {
        errors.push('Invalid account type');
      }
      if (data.userRole && !isInEnum(data.userRole, ['investor', 'trader'])) {
        errors.push('Invalid user role');
      }
      if (data.nationality && !isStringInRange(data.nationality, 2, 60)) errors.push('Invalid nationality');
      return errors.length ? { valid: false, message: errors.join('; ') } : { valid: true };
    }

    case 'address':
    case 'tax': {
      const errors = [];
      if (!isNonEmpty(data.streetAndNumber)) errors.push('streetAndNumber is required');
      if (!isNonEmpty(data.city)) errors.push('city is required');
      if (!isNonEmpty(data.country)) errors.push('country is required');
      if (data.postalCode && !isValidGermanPostalCode(data.postalCode)) errors.push('Invalid German postal code (5 digits)');
      if (data.taxNumber && !isValidGermanTaxId(data.taxNumber)) errors.push('Invalid German tax ID (11 digits)');
      if (data.streetAndNumber && !isStringInRange(data.streetAndNumber, 3, 200)) errors.push('streetAndNumber out of range');
      if (data.city && !isStringInRange(data.city, 1, 100)) errors.push('city too long');
      return errors.length ? { valid: false, message: errors.join('; ') } : { valid: true };
    }

    case 'verification': {
      if (data.identificationType && !isInEnum(data.identificationType, ['passport', 'idCard', 'driversLicense'])) {
        return { valid: false, message: 'Invalid identification type' };
      }
      return { valid: true };
    }

    case 'experience': {
      const errors = [];
      if (data.employmentStatus && !isInEnum(data.employmentStatus, [
        'employed', 'selfEmployed', 'civilServant', 'student',
        'retired', 'unemployed', 'other'
      ])) errors.push('Invalid employment status');
      const numericFields = [
        'stocksTransactionsCount', 'stocksInvestmentAmount',
        'etfsTransactionsCount', 'etfsInvestmentAmount',
        'derivativesTransactionsCount', 'derivativesInvestmentAmount'
      ];
      for (const f of numericFields) {
        if (data[f] !== undefined && data[f] !== null && typeof data[f] !== 'number' && typeof data[f] !== 'string') {
          errors.push(`${f} must be a number or string`);
        }
      }
      return errors.length ? { valid: false, message: errors.join('; ') } : { valid: true };
    }

    case 'risk': {
      const errors = [];
      if (data.calculatedRiskClass !== undefined && !isPositiveInt(data.calculatedRiskClass)) {
        errors.push('calculatedRiskClass must be a positive integer');
      }
      if (data.finalRiskClass !== undefined && !isPositiveInt(data.finalRiskClass)) {
        errors.push('finalRiskClass must be a positive integer');
      }
      if (data.assetType && !isInEnum(data.assetType, ['privateAssets', 'businessAssets'])) {
        errors.push('Invalid asset type');
      }
      return errors.length ? { valid: false, message: errors.join('; ') } : { valid: true };
    }

    case 'consents': {
      const errors = [];
      if (data.acceptedTerms !== undefined && !isBoolean(data.acceptedTerms)) errors.push('acceptedTerms must be boolean');
      if (data.acceptedPrivacyPolicy !== undefined && !isBoolean(data.acceptedPrivacyPolicy)) errors.push('acceptedPrivacyPolicy must be boolean');
      if (data.acceptedTerms === false) errors.push('Terms must be accepted');
      if (data.acceptedPrivacyPolicy === false) errors.push('Privacy policy must be accepted');
      if (data.termsVersion && !isStringInRange(data.termsVersion, 1, 20)) errors.push('Invalid terms version');
      if (data.privacyVersion && !isStringInRange(data.privacyVersion, 1, 20)) errors.push('Invalid privacy version');
      return errors.length ? { valid: false, message: errors.join('; ') } : { valid: true };
    }

    default:
      return { valid: true };
  }
}

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
    if (!isInEnum(params.salutation, ['Herr', 'Frau', 'Divers', 'mr', 'mrs', 'diverse'])) {
      errors.push('Invalid salutation');
    }
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
  validateProfileUpdate,
};

console.log('Validation utilities loaded');
