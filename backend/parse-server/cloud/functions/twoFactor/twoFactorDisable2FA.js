'use strict';

const { otplibModule } = require('./twoFactorDependencies');

async function handleDisable2FA(request) {
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

  try {
    await Parse.User.logIn(user.get('username'), password);
  } catch (e) {
    throw new Parse.Error(Parse.Error.INVALID_VALUE, 'Invalid password');
  }

  const secret = user.get('twoFactorSecret');
  const isValid = otplibModule.verify({ token: code, secret });

  if (!isValid) {
    throw new Parse.Error(Parse.Error.INVALID_VALUE, 'Invalid 2FA code');
  }

  user.unset('twoFactorEnabled');
  user.unset('twoFactorSecret');
  user.unset('twoFactorPending');
  user.unset('twoFactorBackupCodes');
  user.unset('twoFactorEnabledAt');
  await user.save(null, { useMasterKey: true });

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
}

module.exports = {
  handleDisable2FA,
};
