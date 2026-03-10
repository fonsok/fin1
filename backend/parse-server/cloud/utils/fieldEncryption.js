// ============================================================================
// Field-Level Encryption for FIN1
// utils/fieldEncryption.js
// ============================================================================
//
// AES-256-GCM field-level encryption for PII / sensitive data at rest.
//
// Encrypted values use a tagged format so we can detect them and avoid
// double-encryption:
//
//   enc:v1:<iv_hex>:<ciphertext_hex>:<authTag_hex>
//
// Environment variable:
//   FIELD_ENCRYPTION_KEY  – 64-char hex string (32 bytes / 256 bits)
//
// ============================================================================

'use strict';

const crypto = require('crypto');

const ALGO = 'aes-256-gcm';
const IV_LENGTH = 12;
const PREFIX = 'enc:v1:';

let _keyBuffer = null;

function getKey() {
  if (_keyBuffer) return _keyBuffer;

  const hex = process.env.FIELD_ENCRYPTION_KEY;
  if (!hex || hex.length !== 64) {
    return null;
  }
  _keyBuffer = Buffer.from(hex, 'hex');
  return _keyBuffer;
}

function isEncrypted(value) {
  return typeof value === 'string' && value.startsWith(PREFIX);
}

/**
 * Encrypt a string value.
 * Returns the tagged ciphertext or the original value if encryption is unavailable.
 */
function encrypt(plaintext) {
  if (plaintext == null || plaintext === '') return plaintext;
  const str = String(plaintext);
  if (isEncrypted(str)) return str;

  const key = getKey();
  if (!key) return str;

  const iv = crypto.randomBytes(IV_LENGTH);
  const cipher = crypto.createCipheriv(ALGO, key, iv);
  const encrypted = Buffer.concat([cipher.update(str, 'utf8'), cipher.final()]);
  const tag = cipher.getAuthTag();

  return `${PREFIX}${iv.toString('hex')}:${encrypted.toString('hex')}:${tag.toString('hex')}`;
}

/**
 * Decrypt a tagged ciphertext back to plaintext.
 * Returns the original value unchanged if it is not encrypted or key is missing.
 */
function decrypt(ciphertext) {
  if (!isEncrypted(ciphertext)) return ciphertext;

  const key = getKey();
  if (!key) return ciphertext;

  try {
    const parts = ciphertext.slice(PREFIX.length).split(':');
    if (parts.length !== 3) return ciphertext;

    const iv = Buffer.from(parts[0], 'hex');
    const encrypted = Buffer.from(parts[1], 'hex');
    const tag = Buffer.from(parts[2], 'hex');

    const decipher = crypto.createDecipheriv(ALGO, key, iv);
    decipher.setAuthTag(tag);
    const decrypted = Buffer.concat([decipher.update(encrypted), decipher.final()]);
    return decrypted.toString('utf8');
  } catch (err) {
    console.error('[fieldEncryption] Decryption failed:', err.message);
    return ciphertext;
  }
}

/**
 * Encrypt a JSON-serialisable object (stored as a single encrypted blob).
 */
function encryptObject(obj) {
  if (obj == null) return obj;
  if (isEncrypted(obj)) return obj;
  return encrypt(JSON.stringify(obj));
}

/**
 * Decrypt an object that was encrypted with encryptObject.
 */
function decryptObject(value) {
  if (value == null) return value;
  if (typeof value === 'object') return value;
  if (!isEncrypted(value)) return value;
  try {
    return JSON.parse(decrypt(value));
  } catch {
    return value;
  }
}

/**
 * Encrypt specific string fields on a Parse object.
 * @param {Parse.Object} obj
 * @param {string[]} fields - field names to encrypt
 */
function encryptFields(obj, fields) {
  if (!getKey()) return;
  for (const field of fields) {
    const val = obj.get(field);
    if (val != null && val !== '' && !isEncrypted(val)) {
      obj.set(field, encrypt(String(val)));
    }
  }
}

/**
 * Decrypt specific string fields on a Parse object (mutates in place for afterFind).
 * @param {Parse.Object} obj
 * @param {string[]} fields - field names to decrypt
 */
function decryptFields(obj, fields) {
  if (!getKey()) return;
  for (const field of fields) {
    const val = obj.get(field);
    if (isEncrypted(val)) {
      obj.set(field, decrypt(val));
    }
  }
}

/**
 * Encrypt a JSON-blob field on a Parse object.
 */
function encryptBlobField(obj, field) {
  if (!getKey()) return;
  const val = obj.get(field);
  if (val != null && typeof val === 'object') {
    obj.set(field, encryptObject(val));
  }
}

/**
 * Decrypt a JSON-blob field on a Parse object.
 */
function decryptBlobField(obj, field) {
  if (!getKey()) return;
  const val = obj.get(field);
  if (isEncrypted(val)) {
    obj.set(field, decryptObject(val));
  }
}

function isKeyConfigured() {
  return !!getKey();
}

module.exports = {
  encrypt,
  decrypt,
  encryptObject,
  decryptObject,
  encryptFields,
  decryptFields,
  encryptBlobField,
  decryptBlobField,
  isEncrypted,
  isKeyConfigured,
};

console.log(`Field Encryption loaded (key ${getKey() ? 'configured' : 'NOT configured – fields stored in plaintext'})`);
