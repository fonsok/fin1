// ============================================================================
// Parse Cloud Code — Two-Factor Authentication (TOTP, Admin-Rollen)
// Einstieg: index.js — Handler unter ./twoFactor*.js
// ============================================================================

'use strict';

const { handleSetup2FA } = require('./twoFactorSetup2FA');
const { handleEnable2FA } = require('./twoFactorEnable2FA');
const { handleVerify2FACode } = require('./twoFactorVerify2FACode');
const { handleDisable2FA } = require('./twoFactorDisable2FA');
const { handleRegenerateBackupCodes } = require('./twoFactorRegenerateBackupCodes');

Parse.Cloud.define('setup2FA', handleSetup2FA);
Parse.Cloud.define('enable2FA', handleEnable2FA);
Parse.Cloud.define('verify2FACode', handleVerify2FACode);
Parse.Cloud.define('disable2FA', handleDisable2FA);
Parse.Cloud.define('regenerateBackupCodes', handleRegenerateBackupCodes);

console.log('2FA Cloud Functions loaded');
