'use strict';

const crypto = require('crypto');

const APP_NAME = 'FIN1 Admin';

function generateTOTPUri(email, secret) {
  return `otpauth://totp/${encodeURIComponent(APP_NAME)}:${encodeURIComponent(email)}?secret=${secret}&issuer=${encodeURIComponent(APP_NAME)}&algorithm=SHA1&digits=6&period=30`;
}

function generateBackupCodes(count) {
  const codes = [];
  const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';

  for (let i = 0; i < count; i++) {
    let code = '';
    for (let j = 0; j < 8; j++) {
      code += chars.charAt(Math.floor(Math.random() * chars.length));
    }
    codes.push(code);
  }

  return codes;
}

function hashBackupCode(code) {
  return crypto.createHash('sha256').update(code.toUpperCase()).digest('hex');
}

async function logVerification(user, result) {
  try {
    const AuditLog = Parse.Object.extend('AuditLog');
    const log = new AuditLog();
    log.set('logType', 'security');
    log.set('action', `2fa_${result}`);
    log.set('userId', user.id);
    log.set('userRole', user.get('role'));
    log.set('metadata', {
      timestamp: new Date().toISOString(),
    });
    await log.save(null, { useMasterKey: true });
  } catch (e) {
    console.error('Failed to log 2FA verification:', e);
  }
}

module.exports = {
  generateTOTPUri,
  generateBackupCodes,
  hashBackupCode,
  logVerification,
};
