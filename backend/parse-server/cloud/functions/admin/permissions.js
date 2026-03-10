'use strict';

const { requirePermission, requireAdminRole, getPermissionsForRole, getAdminRoles, isElevatedRole } = require('../../utils/permissions');
const { getRoleDescription } = require('./helpers');

Parse.Cloud.define('getMyPermissions', async (request) => {
  requireAdminRole(request);

  const role = request.user.get('role');
  const permissions = getPermissionsForRole(role);

  return {
    role,
    permissions,
    isFullAdmin: permissions[0] === '*',
    isElevated: isElevatedRole(role),
    roleDescription: getRoleDescription(role),
  };
});

Parse.Cloud.define('getAdminRoles', async (request) => {
  requirePermission(request, '*');

  const roles = getAdminRoles();

  return {
    roles: roles.map(role => ({
      id: role,
      name: getRoleDescription(role),
      isElevated: isElevatedRole(role),
    })),
  };
});
