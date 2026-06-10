'use strict';

const { PERMISSIONS, STATUS_CHANGE_PERMISSIONS } = require('./constants');
const {
  requirePermission,
  requireAdminRole,
  requireStatusChangePermission,
} = require('./checks');
const {
  getPermissionsForRole,
  getAdminRoles,
  isElevatedRole,
} = require('./roles');
const { logPermissionCheck } = require('./audit');

/** Tier 1 — Cloud Function guards (stable). */
const tier1Guards = {
  requirePermission,
  requireAdminRole,
  requireStatusChangePermission,
};

/** Tier 2 — permission constants SSOT. */
const tier2Constants = {
  PERMISSIONS,
  STATUS_CHANGE_PERMISSIONS,
};

/** Tier 3 — admin introspection (`getMyPermissions`, role listings). */
const tier3RoleIntrospection = {
  getPermissionsForRole,
  getAdminRoles,
  isElevatedRole,
};

/** Tier 4 — audit logging helper. */
const tier4Audit = {
  logPermissionCheck,
};

/**
 * Package-internal (roles.js only, not on facade):
 *   isValidRole, getApprovalRoles, getFinancialRoles, getSecurityRoles.
 */

const publicSurface = {
  ...tier1Guards,
  ...tier2Constants,
  ...tier3RoleIntrospection,
  ...tier4Audit,
};

const API_TIERS = {
  guards: Object.keys(tier1Guards),
  constants: Object.keys(tier2Constants),
  roleIntrospection: Object.keys(tier3RoleIntrospection),
  audit: Object.keys(tier4Audit),
  packageInternal: ['isValidRole', 'getApprovalRoles', 'getFinancialRoles', 'getSecurityRoles'],
};

module.exports = { publicSurface, API_TIERS };
