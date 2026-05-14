'use strict';

const { requireAdminRole } = require('../../utils/permissions');

// ============================================================================
// CSR PERMISSIONS & ROLES (RBAC)
// Mirrors iOS: CustomerSupportPermission.swift, CustomerSupportPermissionSet.swift
// ============================================================================

/** Canonical CSRRole.key values (Parse seed / iOS CSRRole). */
const CANONICAL_CSR_ROLE_KEYS = new Set(['level1', 'level2', 'fraud', 'compliance', 'techSupport', 'teamlead']);

/**
 * Maps User.csrSubRole and admin-portal aliases → CSRRole.key used in Parse seed.
 * createCSRUser / beforeSave infer use snake_case (level_1, tech_support, …).
 */
const CSR_SUBROLE_ALIAS_TO_KEY = {
  level_1: 'level1',
  level1: 'level1',
  l1: 'level1',
  level_2: 'level2',
  level2: 'level2',
  l2: 'level2',
  fraud_analyst: 'fraud',
  fraudanalyst: 'fraud',
  fraud: 'fraud',
  compliance_officer: 'compliance',
  complianceofficer: 'compliance',
  compliance: 'compliance',
  tech_support: 'techSupport',
  techsupport: 'techSupport',
  teamlead: 'teamlead',
};

/** Legacy Mongo init (00_init_admin.js) used CSRRole.name instead of key. */
const CANONICAL_KEY_TO_LEGACY_NAME = {
  level1: 'level_1',
  level2: 'level_2',
  fraud: 'fraud_analyst',
  compliance: 'compliance_officer',
  techSupport: 'tech_support',
  teamlead: 'teamlead',
};

function normalizeCSRRoleLookupKey(raw) {
  if (raw == null) return 'level1';
  const s = String(raw).trim();
  if (!s) return 'level1';
  if (CANONICAL_CSR_ROLE_KEYS.has(s)) return s;
  const lowered = s.toLowerCase();
  if (CSR_SUBROLE_ALIAS_TO_KEY[lowered]) return CSR_SUBROLE_ALIAS_TO_KEY[lowered];
  return s;
}

/**
 * Resolve CSRRole by Parse `key`, or legacy `name` (snake_case), or raw key string.
 */
async function fetchCSRRoleByKeyFlexible(roleKeyParam) {
  const canonical = normalizeCSRRoleLookupKey(roleKeyParam);

  const byKey = new Parse.Query('CSRRole');
  byKey.equalTo('key', canonical);
  let role = await byKey.first({ useMasterKey: true });
  if (role) return role;

  const legacyName = CANONICAL_KEY_TO_LEGACY_NAME[canonical];
  if (legacyName) {
    const byName = new Parse.Query('CSRRole');
    byName.equalTo('name', legacyName);
    role = await byName.first({ useMasterKey: true });
    if (role) return role;
  }

  const raw = String(roleKeyParam || '').trim();
  if (raw && raw !== canonical) {
    const byRaw = new Parse.Query('CSRRole');
    byRaw.equalTo('key', raw);
    role = await byRaw.first({ useMasterKey: true });
    if (role) return role;
  }

  return null;
}

/**
 * Get all CSR permissions
 * Used for displaying permission options in admin UI
 */
Parse.Cloud.define('getCSRPermissions', async (request) => {
  if (!request.master) {
    requireAdminRole(request);
  }

  const query = new Parse.Query('CSRPermission');
  query.equalTo('isActive', true);
  query.ascending('category');

  const permissions = await query.find({ useMasterKey: true });

  // Group by category for easier UI consumption
  const grouped = {};
  const categoryOrder = ['viewing', 'modification', 'support', 'compliance', 'fraud', 'administration'];

  for (const perm of permissions) {
    const category = perm.get('category');
    if (!grouped[category]) {
      grouped[category] = {
        category,
        displayName: getCategoryDisplayName(category),
        icon: getCategoryIcon(category),
        permissions: []
      };
    }
    grouped[category].permissions.push({
      key: perm.get('key'),
      displayName: perm.get('displayName'),
      isReadOnly: perm.get('isReadOnly'),
      requiresApproval: perm.get('requiresApproval'),
      triggersComplianceCheck: perm.get('triggersComplianceCheck'),
      requiresAMLDocumentation: perm.get('requiresAMLDocumentation')
    });
  }

  // Sort by category order
  const result = categoryOrder
    .filter(cat => grouped[cat])
    .map(cat => grouped[cat]);

  return {
    permissions: permissions.map(p => p.toJSON()),
    grouped: result
  };
});

/**
 * Get all CSR roles with their permissions
 */
Parse.Cloud.define('getCSRRoles', async (request) => {
  if (!request.master) {
    requireAdminRole(request);
  }

  const query = new Parse.Query('CSRRole');
  query.equalTo('isActive', true);
  query.ascending('sortOrder');

  const roles = await query.find({ useMasterKey: true });

  return {
    roles: roles.map(role => ({
      key: role.get('key'),
      displayName: role.get('displayName'),
      shortName: role.get('shortName'),
      icon: role.get('icon'),
      color: role.get('color'),
      permissions: role.get('permissions'),
      canApprove: role.get('canApprove'),
      description: role.get('description'),
      sortOrder: role.get('sortOrder')
    }))
  };
});

/**
 * Get permissions for a specific CSR role
 */
Parse.Cloud.define('getCSRRolePermissions', async (request) => {
  if (!request.master) {
    requireAdminRole(request);
  }

  const { roleKey } = request.params;
  if (!roleKey) {
    throw new Parse.Error(Parse.Error.INVALID_QUERY, 'roleKey required');
  }

  const role = await fetchCSRRoleByKeyFlexible(roleKey);

  if (!role) {
    const tried = normalizeCSRRoleLookupKey(roleKey);
    throw new Parse.Error(
      Parse.Error.OBJECT_NOT_FOUND,
      `Role '${roleKey}' not found (CSRRole.key/name; normalized: '${tried}'). Seed CSR roles if the collection is empty.`,
    );
  }

  const permissionKeys = role.get('permissions') || [];

  // Get full permission details
  const permQuery = new Parse.Query('CSRPermission');
  permQuery.containedIn('key', permissionKeys);
  permQuery.equalTo('isActive', true);
  const permissions = await permQuery.find({ useMasterKey: true });

  // Group by category
  const grouped = {};
  const categoryOrder = ['viewing', 'modification', 'support', 'compliance', 'fraud', 'administration'];

  for (const perm of permissions) {
    const category = perm.get('category');
    if (!grouped[category]) {
      grouped[category] = {
        category,
        displayName: getCategoryDisplayName(category),
        icon: getCategoryIcon(category),
        permissions: []
      };
    }
    grouped[category].permissions.push({
      key: perm.get('key'),
      displayName: perm.get('displayName'),
      isReadOnly: perm.get('isReadOnly'),
      requiresApproval: perm.get('requiresApproval')
    });
  }

  const result = categoryOrder
    .filter(cat => grouped[cat])
    .map(cat => grouped[cat]);

  return {
    role: {
      key: role.get('key'),
      displayName: role.get('displayName'),
      shortName: role.get('shortName'),
      icon: role.get('icon'),
      color: role.get('color'),
      canApprove: role.get('canApprove'),
      description: role.get('description')
    },
    permissionCount: permissionKeys.length,
    permissions: result
  };
});

/**
 * Check if a user has a specific CSR permission
 */
Parse.Cloud.define('checkCSRPermission', async (request) => {
  requireAdminRole(request);

  const { userId, permissionKey } = request.params;
  if (!userId || !permissionKey) {
    throw new Parse.Error(Parse.Error.INVALID_QUERY, 'userId and permissionKey required');
  }

  // Get user
  const userQuery = new Parse.Query(Parse.User);
  const user = await userQuery.get(userId, { useMasterKey: true });

  const csrSubRole = user.get('csrSubRole') || 'level1';

  const role = await fetchCSRRoleByKeyFlexible(csrSubRole);

  if (!role) {
    return { hasPermission: false, reason: 'Role not found' };
  }

  const permissions = role.get('permissions') || [];
  const hasPermission = permissions.includes(permissionKey);

  // Get permission details for approval info
  let requiresApproval = false;
  if (hasPermission) {
    const permQuery = new Parse.Query('CSRPermission');
    permQuery.equalTo('key', permissionKey);
    const perm = await permQuery.first({ useMasterKey: true });
    if (perm) {
      requiresApproval = perm.get('requiresApproval');
    }
  }

  return {
    hasPermission,
    requiresApproval,
    userRole: csrSubRole,
    canApprove: role.get('canApprove')
  };
});

/**
 * Get CSR agents with their roles and permissions
 */
Parse.Cloud.define('getCSRAgentsWithRoles', async (request) => {
  requireAdminRole(request);

  // Get all CSR users
  const userQuery = new Parse.Query(Parse.User);
  userQuery.equalTo('role', 'customer_service');
  userQuery.ascending('lastName');
  const users = await userQuery.find({ useMasterKey: true });

  // Get all roles for lookup
  const roleQuery = new Parse.Query('CSRRole');
  const roles = await roleQuery.find({ useMasterKey: true });
  const roleMap = {};
  for (const role of roles) {
    const json = role.toJSON();
    const k = role.get('key');
    if (k) roleMap[k] = json;
    const legacyName = role.get('name');
    if (legacyName) roleMap[legacyName] = json;
  }

  const agents = users.map(user => {
    const csrSubRole = user.get('csrSubRole') || 'level1';
    const canonical = normalizeCSRRoleLookupKey(csrSubRole);
    const roleInfo = roleMap[csrSubRole] || roleMap[canonical] || {};

    return {
      objectId: user.id,
      email: user.get('email'),
      firstName: user.get('firstName'),
      lastName: user.get('lastName'),
      status: user.get('status') || 'active',
      csrSubRole,
      roleDisplayName: roleInfo.displayName || csrSubRole,
      roleIcon: roleInfo.icon,
      roleColor: roleInfo.color,
      canApprove: roleInfo.canApprove || false,
      permissionCount: (roleInfo.permissions || []).length
    };
  });

  return { agents };
});

/**
 * Update a user's CSR sub-role
 * Requires teamlead or admin
 */
Parse.Cloud.define('updateCSRUserRole', async (request) => {
  requireAdminRole(request);

  const { userId, newRole } = request.params;
  if (!userId || !newRole) {
    throw new Parse.Error(Parse.Error.INVALID_QUERY, 'userId and newRole required');
  }

  // Check if caller has permission
  const callerRole = request.user.get('role');
  const callerCsrSubRole = request.user.get('csrSubRole');

  if (callerRole !== 'admin' && callerCsrSubRole !== 'teamlead') {
    throw new Parse.Error(
      Parse.Error.OPERATION_FORBIDDEN,
      'Only admin or teamlead can change CSR roles'
    );
  }

  const role = await fetchCSRRoleByKeyFlexible(newRole);

  if (!role) {
    throw new Parse.Error(Parse.Error.INVALID_QUERY, `Invalid role: ${newRole}`);
  }

  // Update user
  const userQuery = new Parse.Query(Parse.User);
  const user = await userQuery.get(userId, { useMasterKey: true });

  const oldRole = user.get('csrSubRole');
  user.set('csrSubRole', newRole);
  await user.save(null, { useMasterKey: true });

  // Log the change
  const AuditLog = Parse.Object.extend('AuditLog');
  const log = new AuditLog();
  log.set('logType', 'admin');
  log.set('action', 'csr_role_changed');
  log.set('userId', request.user.id);
  log.set('resourceType', 'User');
  log.set('resourceId', userId);
  log.set('metadata', {
    oldRole,
    newRole,
    changedBy: request.user.id,
    changedByEmail: request.user.get('email')
  });
  await log.save(null, { useMasterKey: true });

  return {
    success: true,
    userId,
    oldRole,
    newRole,
    roleDisplayName: role.get('displayName')
  };
});

// Helper functions for category display
function getCategoryDisplayName(category) {
  const names = {
    viewing: 'Ansicht',
    modification: 'Bearbeitung',
    support: 'Support',
    compliance: 'Compliance',
    fraud: 'Betrugsbekämpfung',
    administration: 'Administration'
  };
  return names[category] || category;
}

function getCategoryIcon(category) {
  const icons = {
    viewing: '👁️',
    modification: '✏️',
    support: '💬',
    compliance: '📋',
    fraud: '🔍',
    administration: '⚙️'
  };
  return icons[category] || '📄';
}

console.log('Support & Tickets Cloud Functions loaded');
