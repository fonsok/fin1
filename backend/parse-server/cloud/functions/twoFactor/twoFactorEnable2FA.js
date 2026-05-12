'use strict';

const { otplibModule } = require('./twoFactorDependencies');
const { generateBackupCodes, hashBackupCode } = require('./twoFactorHelpers');

async function handleEnable2FA(request) {
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

  const isValid = otplibModule.verify({ token: code, secret });

  if (!isValid) {
    throw new Parse.Error(Parse.Error.INVALID_VALUE, 'Invalid verification code');
  }

  const backupCodes = generateBackupCodes(8);

  user.set('twoFactorEnabled', true);
  user.set('twoFactorPending', false);
  user.set('twoFactorBackupCodes', backupCodes.map(c => hashBackupCode(c)));
  user.set('twoFactorEnabledAt', new Date());
  await user.save(null, { useMasterKey: true });

  const AuditLog = Parse.Object.extend('AuditLog');
  const log = new AuditLog();
  log.set('logType', 'security');
  log.set('action', '2fa_enabled');
  log.set('userId', user.id);
  log.set('userRole', user.get('role'));
  await log.save(null, { useMasterKey: true });

  return {
    success: true,
    backupCodes,
    message: 'Zwei-Faktor-Authentifizierung wurde aktiviert. Bitte speichern Sie die Backup-Codes sicher!',
  };
}

module.exports = {
  handleEnable2FA,
};
