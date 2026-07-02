'use strict';

const { requirePermission, requireStatusChangePermission } = require('../../utils/permissions');
const { handleSearchUsers } = require('./usersSearchUsers');
const { handleGetUserDetails } = require('./usersGetUserDetails');
const { handleUpdateUserStatus } = require('./usersUpdateStatus');
const { handleRequestUserWalletActionModeChange } = require('./usersRequestWalletMode');
const { handleRequestUserCommissionRateBundleChange } = require('./usersRequestCommissionRateBundle');
const { handleRequestUserAppServiceChargeChange } = require('./usersRequestAppServiceCharge');
const { handleRequestUserOpenDepotLimitChange } = require('./usersRequestOpenDepotLimit');

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

Parse.Cloud.define('requestUserCommissionRateBundleChange', async (request) => {
  requirePermission(request, 'createCorrectionRequest');
  return handleRequestUserCommissionRateBundleChange(request);
});

Parse.Cloud.define('requestUserAppServiceChargeChange', async (request) => {
  requirePermission(request, 'createCorrectionRequest');
  return handleRequestUserAppServiceChargeChange(request);
});

Parse.Cloud.define('requestUserOpenDepotLimitChange', async (request) => {
  requirePermission(request, 'createCorrectionRequest');
  return handleRequestUserOpenDepotLimitChange(request);
});
