'use strict';

const USER_PII_FIELDS = ['phone_number'];

const VALID_USER_ROLES = [
  'investor',
  'trader',
  'admin',
  'customer_service',
  'compliance',
  'business_admin',
  'security_officer',
  'system',
];

const VALID_USER_STATUSES = ['pending', 'active', 'suspended', 'locked', 'closed', 'deleted'];

module.exports = {
  USER_PII_FIELDS,
  VALID_USER_ROLES,
  VALID_USER_STATUSES,
};
