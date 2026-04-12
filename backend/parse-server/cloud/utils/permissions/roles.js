'use strict';

const { PERMISSIONS } = require('./constants');

function getPermissionsForRole(role) {
  return PERMISSIONS[role] || [];
}

function isValidRole(role) {
  return Object.keys(PERMISSIONS).includes(role);
}

function getAdminRoles() {
  return [
    'admin',
    'business_admin',
    'security_officer',
    'compliance',
    'customer_service',
  ];
}

function getApprovalRoles() {
  return ['admin', 'business_admin', 'security_officer', 'compliance'];
}

function getFinancialRoles() {
  return ['admin', 'business_admin'];
}

function getSecurityRoles() {
  return ['admin', 'security_officer', 'compliance'];
}

function isElevatedRole(role) {
  return ['admin', 'business_admin', 'security_officer', 'compliance'].includes(role);
}

module.exports = {
  getPermissionsForRole,
  isValidRole,
  getAdminRoles,
  getApprovalRoles,
  getFinancialRoles,
  getSecurityRoles,
  isElevatedRole,
};
