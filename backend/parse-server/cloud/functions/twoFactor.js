// ============================================================================
// Parse Cloud Code
// functions/twoFactor.js - Two-Factor Authentication
// ============================================================================
//
// TOTP-basierte 2FA für Admin-Rollen.
// Nutzt otplib v13+ für TOTP-Generierung und -Verifikation.
//
// ============================================================================

'use strict';

// Note: otplib and qrcode must be installed on the server
// npm install otplib qrcode

let otplibModule;
let toDataURL;

try {
  otplibModule = require('otplib');
  console.log('otplib loaded successfully');
} catch (e) {
  console.warn('otplib not installed - 2FA functions will not work');
}

try {
  const qrcode = require('qrcode');
  toDataURL = qrcode.toDataURL;
  console.log('qrcode loaded successfully');
} catch (e) {
  console.warn('qrcode not installed - QR code generation will not work');
}

const APP_NAME = 'FIN1 Admin';

// ============================================================================
// Helper: Generate TOTP URI for QR codes
// ============================================================================
function generateTOTPUri(email, secret) {
  return `otpauth://totp/${encodeURIComponent(APP_NAME)}:${encodeURIComponent(email)}?secret=${secret}&issuer=${encodeURIComponent(APP_NAME)}&algorithm=SHA1&digits=6&period=30`;
}

// ============================================================================
// Setup 2FA
// ============================================================================

/**
 * Setup 2FA for current user.
 * Returns secret and QR code URL for authenticator app.
 */
Parse.Cloud.define('setup2FA', async (request) => {
  if (!request.user) {
    throw new Parse.Error(Parse.Error.INVALID_SESSION_TOKEN, 'Not authenticated');
  }

  if (!otplibModule) {
    throw new Parse.Error(Parse.Error.SCRIPT_FAILED, '2FA not available - otplib not installed');
  }

  const user = request.user;

  // Check if already enabled
  if (user.get('twoFactorEnabled')) {
    throw new Parse.Error(Parse.Error.OPERATION_FORBIDDEN, '2FA is already enabled');
  }

  // Generate secret using otplib v13+ API
  const secret = otplibModule.generateSecret();

  // Store temporarily (not yet enabled)
  user.set('twoFactorSecret', secret);
  user.set('twoFactorPending', true);
  await user.save(null, { useMasterKey: true });

  // Generate QR code URI
  const otpauth = generateTOTPUri(user.get('email'), secret);

  let qrCodeUrl = null;
  if (toDataURL) {
    qrCodeUrl = await toDataURL(otpauth);
  }

  return {
    secret,
    qrCodeUrl,
    otpauth,
    instructions: 'Scannen Sie den QR-Code mit einer beliebigen Authenticator-App (z.B. Authy, 1Password, Bitwarden, FreeOTP, oder dem integrierten iOS/macOS Passwort-Manager).',
  };
});

// ============================================================================
// Enable 2FA
// ============================================================================

/**
 * Enable 2FA after verifying the first code.
 * Returns backup codes.
 */
Parse.Cloud.define('enable2FA', async (request) => {
  if (!request.user) {
    throw new Parse.Error(Parse.Error.INVALID_SESSION_TOKEN, 'Not authenticated');
  }

  if (!otplibModule) {
    throw new Parse.Error(Parse.Error.SCRIPT_FAILED, '2FA not available');
  }

  const { code } = request.params;

  if (!code || code.length !== 6) {
    throw new Parse.Error(Parse.Error.INVALID_VALUE, 'Invalid code format');
  }

  const user = request.user;
  const secret = user.get('twoFactorSecret');

  if (!secret || !user.get('twoFactorPending')) {
    throw new Parse.Error(Parse.Error.OPERATION_FORBIDDEN, 'No pending 2FA setup');
  }

  // Verify the code using otplib v13+ API
  const isValid = otplibModule.verify({ token: code, secret });

  if (!isValid) {
    throw new Parse.Error(Parse.Error.INVALID_VALUE, 'Invalid verification code');
  }

  // Generate backup codes
  const backupCodes = generateBackupCodes(8);

  // Enable 2FA
  user.set('twoFactorEnabled', true);
  user.set('twoFactorPending', false);
  user.set('twoFactorBackupCodes', backupCodes.map(c => hashBackupCode(c)));
  user.set('twoFactorEnabledAt', new Date());
  await user.save(null, { useMasterKey: true });

  // Audit log
  const AuditLog = Parse.Object.extend('AuditLog');
  const log = new AuditLog();
  log.set('logType', 'security');
  log.set('action', '2fa_enabled');
  log.set('userId', user.id);
  log.set('userRole', user.get('role'));
  await log.save(null, { useMasterKey: true });

  return {
    success: true,
    backupCodes, // Return plain codes once - user must save them
    message: 'Zwei-Faktor-Authentifizierung wurde aktiviert. Bitte speichern Sie die Backup-Codes sicher!',
  };
});

// ============================================================================
// Verify 2FA Code
// ============================================================================

/**
 * Verify a 2FA code during login.
 */
Parse.Cloud.define('verify2FACode', async (request) => {
  if (!request.user) {
    throw new Parse.Error(Parse.Error.INVALID_SESSION_TOKEN, 'Not authenticated');
  }

  if (!otplibModule) {
    throw new Parse.Error(Parse.Error.SCRIPT_FAILED, '2FA not available');
  }

  const { code } = request.params;

  if (!code || (code.length !== 6 && code.length !== 8)) {
    throw new Parse.Error(Parse.Error.INVALID_VALUE, 'Invalid code format');
  }

  const user = request.user;

  if (!user.get('twoFactorEnabled')) {
    throw new Parse.Error(Parse.Error.OPERATION_FORBIDDEN, '2FA not enabled');
  }

  const secret = user.get('twoFactorSecret');

  // Try TOTP code first
  if (code.length === 6) {
    const isValid = otplibModule.verify({ token: code, secret });

    if (isValid) {
      // Audit log
      await logVerification(user, 'totp_success');
      return { verified: true };
    }
  }

  // Try backup code
  if (code.length === 8) {
    const backupCodes = user.get('twoFactorBackupCodes') || [];
    const hashedCode = hashBackupCode(code.toUpperCase());
    const codeIndex = backupCodes.indexOf(hashedCode);

    if (codeIndex !== -1) {
      // Remove used backup code
      backupCodes.splice(codeIndex, 1);
      user.set('twoFactorBackupCodes', backupCodes);
      await user.save(null, { useMasterKey: true });

      // Audit log
      await logVerification(user, 'backup_code_used');

      return {
        verified: true,
        warning: `Backup-Code verwendet. Noch ${backupCodes.length} Codes übrig.`,
      };
    }
  }

  // Failed verification
  await logVerification(user, 'verification_failed');
  throw new Parse.Error(Parse.Error.INVALID_VALUE, 'Ungültiger Code');
});

// ============================================================================
// Disable 2FA
// ============================================================================

/**
 * Disable 2FA (requires current 2FA code).
 */
Parse.Cloud.define('disable2FA', async (request) => {
  if (!request.user) {
    throw new Parse.Error(Parse.Error.INVALID_SESSION_TOKEN, 'Not authenticated');
  }

  if (!otplibModule) {
    throw new Parse.Error(Parse.Error.SCRIPT_FAILED, '2FA not available');
  }

  const { code, password } = request.params;

  if (!code || !password) {
    throw new Parse.Error(Parse.Error.INVALID_VALUE, 'Code and password required');
  }

  const user = request.user;

  if (!user.get('twoFactorEnabled')) {
    throw new Parse.Error(Parse.Error.OPERATION_FORBIDDEN, '2FA not enabled');
  }

  // Verify password by attempting login
  try {
    await Parse.User.logIn(user.get('username'), password);
  } catch (e) {
    throw new Parse.Error(Parse.Error.INVALID_VALUE, 'Invalid password');
  }

  // Verify 2FA code
  const secret = user.get('twoFactorSecret');
  const isValid = otplibModule.verify({ token: code, secret });

  if (!isValid) {
    throw new Parse.Error(Parse.Error.INVALID_VALUE, 'Invalid 2FA code');
  }

  // Disable 2FA
  user.unset('twoFactorEnabled');
  user.unset('twoFactorSecret');
  user.unset('twoFactorPending');
  user.unset('twoFactorBackupCodes');
  user.unset('twoFactorEnabledAt');
  await user.save(null, { useMasterKey: true });

  // Audit log
  const AuditLog = Parse.Object.extend('AuditLog');
  const log = new AuditLog();
  log.set('logType', 'security');
  log.set('action', '2fa_disabled');
  log.set('userId', user.id);
  log.set('userRole', user.get('role'));
  await log.save(null, { useMasterKey: true });

  return {
    success: true,
    message: 'Zwei-Faktor-Authentifizierung wurde deaktiviert.',
  };
});

// ============================================================================
// Regenerate Backup Codes
// ============================================================================

/**
 * Generate new backup codes (invalidates old ones).
 */
Parse.Cloud.define('regenerateBackupCodes', async (request) => {
  if (!request.user) {
    throw new Parse.Error(Parse.Error.INVALID_SESSION_TOKEN, 'Not authenticated');
  }

  if (!otplibModule) {
    throw new Parse.Error(Parse.Error.SCRIPT_FAILED, '2FA not available');
  }

  const { code } = request.params;

  if (!code) {
    throw new Parse.Error(Parse.Error.INVALID_VALUE, 'Current 2FA code required');
  }

  const user = request.user;

  if (!user.get('twoFactorEnabled')) {
    throw new Parse.Error(Parse.Error.OPERATION_FORBIDDEN, '2FA not enabled');
  }

  // Verify current code
  const secret = user.get('twoFactorSecret');
  const isValid = otplibModule.verify({ token: code, secret });

  if (!isValid) {
    throw new Parse.Error(Parse.Error.INVALID_VALUE, 'Invalid 2FA code');
  }

  // Generate new backup codes
  const backupCodes = generateBackupCodes(8);

  user.set('twoFactorBackupCodes', backupCodes.map(c => hashBackupCode(c)));
  await user.save(null, { useMasterKey: true });

  // Audit log
  const AuditLog = Parse.Object.extend('AuditLog');
  const log = new AuditLog();
  log.set('logType', 'security');
  log.set('action', 'backup_codes_regenerated');
  log.set('userId', user.id);
  log.set('userRole', user.get('role'));
  await log.save(null, { useMasterKey: true });

  return {
    success: true,
    backupCodes,
    message: 'Neue Backup-Codes wurden generiert. Alte Codes sind ungültig.',
  };
});

// ============================================================================
// Helper Functions
// ============================================================================

/**
 * Generate random backup codes.
 */
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

/**
 * Hash a backup code for storage.
 */
function hashBackupCode(code) {
  const crypto = require('crypto');
  return crypto.createHash('sha256').update(code.toUpperCase()).digest('hex');
}

/**
 * Log 2FA verification attempt.
 */
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

console.log('2FA Cloud Functions loaded');
