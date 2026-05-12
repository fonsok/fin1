// ============================================================================
// Parse Cloud Code
// triggers/encryption.js — Transparent field-level encryption at rest
// ============================================================================
//
// Hooks into beforeSave / afterFind for classes that hold PII so that
// sensitive data is always encrypted in MongoDB and decrypted only when
// read back through Parse Server.
//
// Encrypted classes & fields:
//   UserProfile       : firstName, lastName, dateOfBirth, mobilePhone
//   OnboardingProgress: data   (entire JSON blob)
//   OnboardingAudit   : answers (entire JSON blob)
//   _User             : phone_number
//
// ============================================================================

'use strict';

const {
  encryptFields,
  decryptFields,
  encryptBlobField,
  decryptBlobField,
  isKeyConfigured,
} = require('../utils/fieldEncryption');

// ============================================================================
// UserProfile
// ============================================================================

const PROFILE_PII_FIELDS = ['firstName', 'lastName', 'dateOfBirth', 'mobilePhone'];

Parse.Cloud.beforeSave('UserProfile', (request) => {
  if (request.context && request.context.skipEncryptionTrigger) return;
  encryptFields(request.object, PROFILE_PII_FIELDS);
});

Parse.Cloud.afterFind('UserProfile', (request) => {
  for (const obj of request.objects) {
    decryptFields(obj, PROFILE_PII_FIELDS);
  }
  return request.objects;
});

// ============================================================================
// OnboardingProgress — data blob
// ============================================================================

Parse.Cloud.beforeSave('OnboardingProgress', (request) => {
  if (request.context && request.context.skipEncryptionTrigger) return;
  encryptBlobField(request.object, 'data');
});

Parse.Cloud.afterFind('OnboardingProgress', (request) => {
  for (const obj of request.objects) {
    decryptBlobField(obj, 'data');
  }
  return request.objects;
});

// ============================================================================
// OnboardingAudit — answers blob
// ============================================================================

Parse.Cloud.beforeSave('OnboardingAudit', (request) => {
  if (request.context && request.context.skipEncryptionTrigger) return;
  encryptBlobField(request.object, 'answers');
});

Parse.Cloud.afterFind('OnboardingAudit', (request) => {
  for (const obj of request.objects) {
    decryptBlobField(obj, 'answers');
  }
  return request.objects;
});

// ============================================================================
// _User — phone_number
//
// IMPORTANT: _User already has a beforeSave in triggers/user/ (userTriggerBeforeSave).
// Parse Server allows only one beforeSave per class, so User PII
// encryption is handled there instead.
// The afterFind is safe to register here (Parse allows multiple afterFind).
// ============================================================================

const USER_PII_FIELDS = ['phone_number'];

Parse.Cloud.afterFind(Parse.User, (request) => {
  for (const obj of request.objects) {
    decryptFields(obj, USER_PII_FIELDS);
  }
  return request.objects;
});

if (isKeyConfigured()) {
  console.log('Encryption triggers registered for: UserProfile, OnboardingProgress, OnboardingAudit, _User(afterFind)');
} else {
  console.warn('FIELD_ENCRYPTION_KEY not set — encryption triggers registered but inactive (passthrough mode)');
}
