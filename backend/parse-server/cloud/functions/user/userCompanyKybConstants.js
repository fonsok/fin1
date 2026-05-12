'use strict';

const VALID_STEPS = [
  'legal_entity',
  'registered_address',
  'tax_compliance',
  'beneficial_owners',
  'authorized_representatives',
  'documents',
  'declarations',
  'submission',
];

const SCHEMA_VERSION = 1;
const TERMINAL_STATUSES = ['pending_review', 'approved', 'rejected'];

module.exports = {
  VALID_STEPS,
  SCHEMA_VERSION,
  TERMINAL_STATUSES,
};
