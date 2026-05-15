'use strict';

const { requireAdminRole } = require('../../utils/permissions');
const {
  CANONICAL_CSR_ROLE_KEYS,
  CSR_ROLE_DEFINITIONS,
  getCSRPermissionDefinitionMap,
  resolveCsrRoleDefinitionByKey,
} = require('./csrRoleStaticSets');

// ============================================================================
// CSR PERMISSIONS & ROLES (RBAC)
// Mirrors iOS: CustomerSupportPermission.swift, CustomerSupportPermissionSet.swift
// Static role/permission sets: ./csrRoleStaticSets.js (single source with seed)
// ============================================================================

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
  tech: 'techSupport',
  teamlead: 'teamlead',
  team_lead: 'teamlead',
  lead: 'teamlead',
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
 * Group CSR permission keys for API response. Uses Parse CSRPermission rows when present,
 * otherwise static catalog (csrRoleStaticSets.js) so UI stays accurate if DB roles are missing.
 */
function groupCSRPermissionKeysForResponse(permissionKeys, permissionsFromQuery) {
  const defMap = getCSRPermissionDefinitionMap();
  const categoryOrder = ['viewing', 'modification', 'support', 'compliance', 'fraud', 'administration'];
  const byKey = new Map();
  for (const perm of permissionsFromQuery) {
    byKey.set(perm.get('key'), perm);
  }

  const grouped = {};
  for (const key of permissionKeys) {
    const parseRow = byKey.get(key);
    const def = defMap.get(key);
    let category;
    let displayName;
    let isReadOnly;
    let requiresApproval;
    if (parseRow) {
      category = parseRow.get('category');
      displayName = parseRow.get('displayName');
      isReadOnly = parseRow.get('isReadOnly');
      requiresApproval = parseRow.get('requiresApproval');
    } else if (def) {
      category = def.category;
      displayName = def.displayName;
      isReadOnly = def.isReadOnly;
      requiresApproval = def.requiresApproval;
    } else {
      category = 'administration';
      displayName = key;
      isReadOnly = false;
      requiresApproval = false;
    }
    if (!grouped[category]) {
      grouped[category] = {
        category,
        displayName: getCategoryDisplayName(category),
        icon: getCategoryIcon(category),
        permissions: [],
      };
    }
    grouped[category].permissions.push({
      key,
      displayName,
      isReadOnly,
      requiresApproval,
    });
  }

  return categoryOrder.filter((cat) => grouped[cat]).map((cat) => grouped[cat]);
}

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

  const tried = normalizeCSRRoleLookupKey(roleKey);
  const role = await fetchCSRRoleByKeyFlexible(roleKey);
  const staticForRole = resolveCsrRoleDefinitionByKey(tried);

  let permissionKeys;
  let rolePayload;
  /** @type {{ source: 'parse_role' | 'static_definition_fallback', detail?: string }} */
  let resolution = { source: 'parse_role' };

  if (role) {
    permissionKeys = role.get('permissions') || [];
    rolePayload = {
      key: role.get('key'),
      displayName: role.get('displayName'),
      shortName: role.get('shortName'),
      icon: role.get('icon'),
      color: role.get('color'),
      canApprove: role.get('canApprove'),
      description: role.get('description'),
    };
    // CSRRole-Datensatz ohne permissions[] (z. B. alte Mongo-Init): kanonische Liste aus App-Definition
    if (!permissionKeys.length && staticForRole && staticForRole.permissions.length) {
      permissionKeys = staticForRole.permissions;
      const parseRoleLabel =
        role.get('key') || role.get('name') || tried || 'unbekannt';
      resolution = {
        source: 'static_definition_fallback',
        detail:
          `CSRRole '${parseRoleLabel}' in Parse hat keine oder leere permissions[] (key fehlt ggf. — Legacy-Mongo-Init). ` +
          'Die angezeigte Berechtigungsliste entspricht der kanonischen App-Definition (iOS/Seed). ' +
          'Bitte syncCSRRolesFromCanonical ausführen (empfohlen), oder CSRRole.permissions in Parse setzen, ' +
          'oder seedCSRPermissions / forceReseedCSRPermissions.',
      };
    }
  } else {
    if (!staticForRole) {
      const valid = CSR_ROLE_DEFINITIONS.map((r) => `${r.key} (${r.shortName}: ${r.displayName})`).join('; ');
      throw new Parse.Error(
        Parse.Error.OBJECT_NOT_FOUND,
        `Unbekannte CSR-Rolle: Eingabe='${roleKey}', normalisiert='${tried}'. ` +
          `Erwartete CSRRole.key / csrSubRole-Alias → key: ${valid}.`,
      );
    }
    permissionKeys = staticForRole.permissions;
    rolePayload = {
      key: staticForRole.key,
      displayName: staticForRole.displayName,
      shortName: staticForRole.shortName,
      icon: staticForRole.icon,
      color: staticForRole.color,
      canApprove: staticForRole.canApprove,
      description: staticForRole.description,
    };
    resolution = {
      source: 'static_definition_fallback',
      detail:
        `Kein passender CSRRole-Datensatz in Parse für key/name='${tried}' (Anfrage: '${roleKey}'). ` +
        'Berechtigungen werden aus der kanonischen App-Definition angezeigt. ' +
        'Bitte syncCSRRolesFromCanonical oder seedCSRPermissions ausführen, damit Parse mit der App synchron bleibt.',
    };
  }

  const permQuery = new Parse.Query('CSRPermission');
  permQuery.containedIn('key', permissionKeys);
  permQuery.equalTo('isActive', true);
  const permissions = await permQuery.find({ useMasterKey: true });

  const result = groupCSRPermissionKeysForResponse(permissionKeys, permissions);

  return {
    role: rolePayload,
    permissionCount: permissionKeys.length,
    permissions: result,
    resolution,
  };
});

/**
 * Upsert CSRRole rows from csrRoleStaticSets (key, permissions[], UI fields).
 * Fixes legacy Mongo init rows (name only, empty permissions) without deleting CSRPermission.
 * Idempotent; safe to run repeatedly. Master key or admin session.
 */
async function upsertCSRRolesFromCanonicalCore(request) {
  if (!request.master) {
    requireAdminRole(request);
  }

  const Role = Parse.Object.extend('CSRRole');
  let updated = 0;
  let created = 0;

  for (const roleData of CSR_ROLE_DEFINITIONS) {
    const legacyName = CANONICAL_KEY_TO_LEGACY_NAME[roleData.key] || roleData.key;
    let role = await fetchCSRRoleByKeyFlexible(roleData.key);
    if (role) {
      role.set('key', roleData.key);
      role.set('name', legacyName);
      role.set('displayName', roleData.displayName);
      role.set('shortName', roleData.shortName);
      role.set('icon', roleData.icon);
      role.set('color', roleData.color);
      role.set('permissions', roleData.permissions);
      role.set('canApprove', roleData.canApprove);
      role.set('description', roleData.description);
      role.set('sortOrder', roleData.sortOrder);
      role.set('isActive', true);
      await role.save(null, { useMasterKey: true });
      updated += 1;
    } else {
      const r = new Role();
      r.set('key', roleData.key);
      r.set('name', legacyName);
      r.set('displayName', roleData.displayName);
      r.set('shortName', roleData.shortName);
      r.set('icon', roleData.icon);
      r.set('color', roleData.color);
      r.set('permissions', roleData.permissions);
      r.set('canApprove', roleData.canApprove);
      r.set('description', roleData.description);
      r.set('sortOrder', roleData.sortOrder);
      r.set('isActive', true);
      await r.save(null, { useMasterKey: true });
      created += 1;
    }
  }

  return {
    success: true,
    message: `CSRRole upsert: ${updated} updated, ${created} created (canonical keys + permissions[])`,
    updated,
    created,
  };
}

Parse.Cloud.define('upsertCSRRolesFromCanonical', upsertCSRRolesFromCanonicalCore);
/** @deprecated Use upsertCSRRolesFromCanonical. Legacy alias for scripts/docs. */
Parse.Cloud.define('syncCSRRolesFromCanonical', upsertCSRRolesFromCanonicalCore);

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
  const canonical = normalizeCSRRoleLookupKey(csrSubRole);
  const staticDef = resolveCsrRoleDefinitionByKey(canonical);

  if (!role && !staticDef) {
    return { hasPermission: false, reason: 'Role not found' };
  }

  let permissions = role ? role.get('permissions') || [] : staticDef.permissions;
  if (role && (!permissions || !permissions.length) && staticDef && staticDef.permissions.length) {
    permissions = staticDef.permissions;
  }
  const hasPermission = permissions.includes(permissionKey);

  // Get permission details for approval info
  let requiresApproval = false;
  if (hasPermission) {
    const permQuery = new Parse.Query('CSRPermission');
    permQuery.equalTo('key', permissionKey);
    const perm = await permQuery.first({ useMasterKey: true });
    if (perm) {
      requiresApproval = perm.get('requiresApproval');
    } else {
      const def = getCSRPermissionDefinitionMap().get(permissionKey);
      if (def) requiresApproval = def.requiresApproval;
    }
  }

  return {
    hasPermission,
    requiresApproval,
    userRole: csrSubRole,
    canApprove: role ? role.get('canApprove') : staticDef.canApprove,
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
    const staticDef = resolveCsrRoleDefinitionByKey(canonical);
    const permList = (roleInfo.permissions && roleInfo.permissions.length)
      ? roleInfo.permissions
      : (staticDef ? staticDef.permissions : []);

    return {
      objectId: user.id,
      email: user.get('email'),
      firstName: user.get('firstName'),
      lastName: user.get('lastName'),
      status: user.get('status') || 'active',
      csrSubRole,
      roleDisplayName: roleInfo.displayName || (staticDef && staticDef.displayName) || csrSubRole,
      roleIcon: roleInfo.icon || (staticDef && staticDef.icon),
      roleColor: roleInfo.color || (staticDef && staticDef.color),
      canApprove: roleInfo.canApprove || (staticDef && staticDef.canApprove) || false,
      permissionCount: permList.length
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
