'use strict';

const { PERMISSIONS, STATUS_CHANGE_PERMISSIONS } = require('./constants');
const { getAdminRoles } = require('./roles');

function requirePermission(request, permission) {
  if (!request.user) {
    throw new Parse.Error(Parse.Error.INVALID_SESSION_TOKEN, 'Login required');
  }

  const role = request.user.get('role');
  if (!role) {
    throw new Parse.Error(Parse.Error.OPERATION_FORBIDDEN, 'User has no role assigned');
  }

  const allowedPermissions = PERMISSIONS[role];
  if (!allowedPermissions) {
    throw new Parse.Error(Parse.Error.OPERATION_FORBIDDEN, `Unknown role: ${role}`);
  }

  if (allowedPermissions[0] === '*') {
    return true;
  }

  if (!allowedPermissions.includes(permission)) {
    throw new Parse.Error(
      Parse.Error.OPERATION_FORBIDDEN,
      `Permission '${permission}' not allowed for role '${role}'`
    );
  }

  return true;
}

function requireAdminRole(request) {
  if (!request.user) {
    throw new Parse.Error(Parse.Error.INVALID_SESSION_TOKEN, 'Login required');
  }

  const role = request.user.get('role');
  const adminRoles = getAdminRoles();
  if (!adminRoles.includes(role)) {
    throw new Parse.Error(Parse.Error.OPERATION_FORBIDDEN, 'Admin access required');
  }

  return true;
}

function requireStatusChangePermission(request, targetStatus) {
  requireAdminRole(request);

  const role = request.user.get('role');
  const allowedStatuses = STATUS_CHANGE_PERMISSIONS[role] || [];
  if (role !== 'admin' && !allowedStatuses.includes(targetStatus)) {
    throw new Parse.Error(
      Parse.Error.OPERATION_FORBIDDEN,
      `Role '${role}' cannot change status to '${targetStatus}'`
    );
  }

  return true;
}

module.exports = {
  requirePermission,
  requireAdminRole,
  requireStatusChangePermission,
};
