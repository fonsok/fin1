'use strict';

const { requireAdminRole } = require('../../utils/permissions');
const { CSR_PERMISSION_DEFINITIONS, CSR_ROLE_DEFINITIONS } = require('../support/csrRoleStaticSets');

Parse.Cloud.define('seedCSRPermissions', async (request) => {
  // Allow Master Key or admin role
  if (!request.master) {
    requireAdminRole(request);
  }

  const existingQuery = new Parse.Query('CSRPermission');
  const existingCount = await existingQuery.count({ useMasterKey: true });

  if (existingCount > 0) {
    return {
      success: false,
      message: `${existingCount} permissions already exist. Use 'forceReseedCSRPermissions' to overwrite.`,
      created: 0,
    };
  }

  const Permission = Parse.Object.extend('CSRPermission');
  let created = 0;

  for (const permData of CSR_PERMISSION_DEFINITIONS) {
    const perm = new Permission();
    perm.set('key', permData.key);
    perm.set('displayName', permData.displayName);
    perm.set('category', permData.category);
    perm.set('isReadOnly', permData.isReadOnly);
    perm.set('requiresApproval', permData.requiresApproval);
    perm.set('triggersComplianceCheck', permData.triggersComplianceCheck);
    perm.set('requiresAMLDocumentation', permData.requiresAMLDocumentation);
    perm.set('isActive', true);
    await perm.save(null, { useMasterKey: true });
    created++;
  }

  console.log(`Seeded ${created} CSR permissions`);

  const rolesResult = await seedCSRRolesInternal();

  return {
    success: true,
    message: `Created ${created} permissions and ${rolesResult.created} roles`,
    permissionsCreated: created,
    rolesCreated: rolesResult.created,
  };
});

/**
 * Internal function to seed CSR roles with their permission sets
 */
async function seedCSRRolesInternal() {
  const existingQuery = new Parse.Query('CSRRole');
  const existingCount = await existingQuery.count({ useMasterKey: true });

  if (existingCount > 0) {
    return { success: false, message: 'Roles already exist', created: 0 };
  }

  const Role = Parse.Object.extend('CSRRole');
  let created = 0;

  for (const roleData of CSR_ROLE_DEFINITIONS) {
    const role = new Role();
    role.set('key', roleData.key);
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
    created++;
  }

  return { success: true, created };
}

/**
 * Force reseed CSR permissions (deletes existing first)
 * Can be called with Master Key or by an admin user
 */
Parse.Cloud.define('forceReseedCSRPermissions', async (request) => {
  // Allow Master Key or admin role
  if (!request.master) {
    requireAdminRole(request);
  }

  // Delete existing permissions
  const permQuery = new Parse.Query('CSRPermission');
  const existingPerms = await permQuery.find({ useMasterKey: true });
  await Parse.Object.destroyAll(existingPerms, { useMasterKey: true });

  // Delete existing roles
  const roleQuery = new Parse.Query('CSRRole');
  const existingRoles = await roleQuery.find({ useMasterKey: true });
  await Parse.Object.destroyAll(existingRoles, { useMasterKey: true });

  // Reseed
  return Parse.Cloud.run('seedCSRPermissions', {}, { sessionToken: request.user.getSessionToken() });
});

console.log('Seed Functions loaded');
