'use strict';

const { generateCustomerNumber, isValidEmail } = require('../../utils/helpers');
const { readCustomerNumber, normalizeUserCustomerNumber } = require('../../utils/userIdentity');
const { encryptFields } = require('../../utils/fieldEncryption');

const { USER_PII_FIELDS, VALID_USER_ROLES, VALID_USER_STATUSES } = require('./userTriggerConstants');
const { inferCsrSubRoleFromEmail } = require('./userTriggerCsrSubRole');
const {
  looksLikeParseObjectId,
  isLegacyStableUserId,
} = require('../../utils/canonicalUserId');

async function userBeforeSave(request) {
  const user = request.object;
  const isNew = !user.existed();

  if (!(request.context && request.context.skipEncryptionTrigger)) {
    encryptFields(user, USER_PII_FIELDS);
  }

  if (isNew) {
    if (!readCustomerNumber(user)) {
      const role = user.get('role') || 'investor';
      user.set('customerNumber', await generateCustomerNumber(role));
    }

    user.set('status', user.get('status') || 'pending');
    user.set('kycStatus', user.get('kycStatus') || 'pending');
    if (user.get('emailVerified') === undefined) user.set('emailVerified', false);
    if (user.get('onboardingCompleted') === undefined) user.set('onboardingCompleted', false);
    user.set('loginCount', user.get('loginCount') || 0);
    user.set('failedLoginCount', user.get('failedLoginCount') || 0);
  }

  const email = user.get('email');
  if (email) {
    if (!isValidEmail(email)) {
      throw new Parse.Error(Parse.Error.INVALID_EMAIL_ADDRESS, 'Invalid email format');
    }
    user.set('email', email.toLowerCase().trim());
  }

  const role = user.get('role');
  if (role && !VALID_USER_ROLES.includes(role)) {
    throw new Parse.Error(Parse.Error.INVALID_VALUE, `Invalid role: ${role}`);
  }

  if (role === 'customer_service' && !user.get('csrSubRole')) {
    const emailLower = email ? email.toLowerCase() : '';
    const csrSubRole = inferCsrSubRoleFromEmail(emailLower);
    if (csrSubRole) {
      user.set('csrSubRole', csrSubRole);
    }
  }

  const status = user.get('status');
  if (status && !VALID_USER_STATUSES.includes(status)) {
    throw new Parse.Error(Parse.Error.INVALID_VALUE, `Invalid status: ${status}`);
  }

  normalizeUserCustomerNumber(user);

  // SSOT: stableId mirrors Parse objectId (never persist legacy `user:email` keys).
  if (user.id && looksLikeParseObjectId(user.id)) {
    const stable = String(user.get('stableId') || '').trim();
    if (!stable || isLegacyStableUserId(stable) || stable !== user.id) {
      user.set('stableId', user.id);
    }
  }
}

module.exports = {
  userBeforeSave,
};
