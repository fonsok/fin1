'use strict';

const { handleUnlockParseAccountLockout } = require('./usersAdminAccountLockout');
const { handleResetPortalUserCredentialsMaster } = require('./usersAdminPortalCredentialsMaster');
const { handleGetTestUserDetails } = require('./usersAdminGetTestUserDetails');
const { handleResetDevUserPassword } = require('./usersAdminResetDevUserPassword');
const { handleCreateTestUsers } = require('./usersAdminCreateTestUsers');
const { handleCreateAdminUser } = require('./usersAdminCreateAdminUser');
const { handleCreateCsrUser } = require('./usersAdminCreateCsrUser');

Parse.Cloud.define('unlockParseAccountLockout', handleUnlockParseAccountLockout);
Parse.Cloud.define('resetPortalUserCredentialsMaster', handleResetPortalUserCredentialsMaster);
Parse.Cloud.define('getTestUserDetails', handleGetTestUserDetails);
Parse.Cloud.define('resetDevUserPassword', handleResetDevUserPassword);
Parse.Cloud.define('createTestUsers', handleCreateTestUsers);
Parse.Cloud.define('createAdminUser', handleCreateAdminUser);
Parse.Cloud.define('createCSRUser', handleCreateCsrUser);
