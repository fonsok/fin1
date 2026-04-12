// ============================================================================
// Parse Cloud Code
// utils/permissions.js - Role-Based Access Control
// ============================================================================
//
// Differenzierte Berechtigungen pro Rolle nach Separation of Duties.
// Dokumentation: Documentation/FIN1_APP_DOCS/09_ADMIN_ROLES_SEPARATION.md
//
// ============================================================================

'use strict';

const { PERMISSIONS, STATUS_CHANGE_PERMISSIONS } = require('./permissions/constants');
const {
  requirePermission,
  requireAdminRole,
  requireStatusChangePermission,
} = require('./permissions/checks');
const {
  getPermissionsForRole,
  isValidRole,
  getAdminRoles,
  getApprovalRoles,
  getFinancialRoles,
  getSecurityRoles,
  isElevatedRole,
} = require('./permissions/roles');
const { logPermissionCheck } = require('./permissions/audit');

module.exports = {
  PERMISSIONS,
  STATUS_CHANGE_PERMISSIONS,
  requirePermission,
  requireAdminRole,
  requireStatusChangePermission,
  getPermissionsForRole,
  isValidRole,
  getAdminRoles,
  getApprovalRoles,
  getFinancialRoles,
  getSecurityRoles,
  isElevatedRole,
  logPermissionCheck,
};
