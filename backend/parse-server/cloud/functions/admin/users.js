'use strict';

const { requirePermission, requireStatusChangePermission } = require('../../utils/permissions');
const { handleSearchUsers } = require('./usersSearchUsers');
const { handleGetUserDetails } = require('./usersGetUserDetails');
const { handleUpdateUserStatus } = require('./usersUpdateStatus');
const { handleRequestUserWalletActionModeChange } = require('./usersRequestWalletMode');

Parse.Cloud.define('searchUsers', async (request) => {
  requirePermission(request, 'searchUsers');
  return handleSearchUsers(request);
});

Parse.Cloud.define('getUserDetails', async (request) => {
  requirePermission(request, 'getUserDetails');
  return handleGetUserDetails(request);
});

Parse.Cloud.define('updateUserStatus', async (request) => {
  const { userId, status } = request.params || {};
  if (!userId || !status) {
    throw new Parse.Error(Parse.Error.INVALID_VALUE, 'userId and status required');
  }
  requireStatusChangePermission(request, status);
  return handleUpdateUserStatus(request);
});

Parse.Cloud.define('requestUserWalletActionModeChange', async (request) => {
  requirePermission(request, 'createCorrectionRequest');
  return handleRequestUserWalletActionModeChange(request);
});
