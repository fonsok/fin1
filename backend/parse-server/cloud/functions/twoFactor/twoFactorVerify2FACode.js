'use strict';

const { otplibModule } = require('./twoFactorDependencies');
const { hashBackupCode, logVerification } = require('./twoFactorHelpers');

async function handleVerify2FACode(request) {
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

  if (code.length === 6) {
    const isValid = otplibModule.verify({ token: code, secret });

    if (isValid) {
      await logVerification(user, 'totp_success');
      return { verified: true };
    }
  }

  if (code.length === 8) {
    const backupCodes = user.get('twoFactorBackupCodes') || [];
    const hashedCode = hashBackupCode(code.toUpperCase());
    const codeIndex = backupCodes.indexOf(hashedCode);

    if (codeIndex !== -1) {
      backupCodes.splice(codeIndex, 1);
      user.set('twoFactorBackupCodes', backupCodes);
      await user.save(null, { useMasterKey: true });

      await logVerification(user, 'backup_code_used');

      return {
        verified: true,
        warning: `Backup-Code verwendet. Noch ${backupCodes.length} Codes übrig.`,
      };
    }
  }

  await logVerification(user, 'verification_failed');
  throw new Parse.Error(Parse.Error.INVALID_VALUE, 'Ungültiger Code');
}

module.exports = {
  handleVerify2FACode,
};
