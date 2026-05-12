'use strict';

const { otplibModule, toDataURL } = require('./twoFactorDependencies');
const { generateTOTPUri } = require('./twoFactorHelpers');

async function handleSetup2FA(request) {
  if (!request.user) {
    throw new Parse.Error(Parse.Error.INVALID_SESSION_TOKEN, 'Not authenticated');
  }

  if (!otplibModule) {
    throw new Parse.Error(Parse.Error.SCRIPT_FAILED, '2FA not available - otplib not installed');
  }

  const user = request.user;

  if (user.get('twoFactorEnabled')) {
    throw new Parse.Error(Parse.Error.OPERATION_FORBIDDEN, '2FA is already enabled');
  }

  const secret = otplibModule.generateSecret();

  user.set('twoFactorSecret', secret);
  user.set('twoFactorPending', true);
  await user.save(null, { useMasterKey: true });

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
}

module.exports = {
  handleSetup2FA,
};
