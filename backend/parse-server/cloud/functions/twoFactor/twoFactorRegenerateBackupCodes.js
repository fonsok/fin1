'use strict';

const { otplibModule } = require('./twoFactorDependencies');
const { generateBackupCodes, hashBackupCode } = require('./twoFactorHelpers');

async function handleRegenerateBackupCodes(request) {
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

  const secret = user.get('twoFactorSecret');
  const isValid = otplibModule.verify({ token: code, secret });

  if (!isValid) {
    throw new Parse.Error(Parse.Error.INVALID_VALUE, 'Invalid 2FA code');
  }

  const backupCodes = generateBackupCodes(8);

  user.set('twoFactorBackupCodes', backupCodes.map(c => hashBackupCode(c)));
  await user.save(null, { useMasterKey: true });

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
}

module.exports = {
  handleRegenerateBackupCodes,
};
