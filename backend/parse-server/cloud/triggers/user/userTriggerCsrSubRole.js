'use strict';

/**
 * CSR sub-role hint from email local-part (customer_service only).
 */
function inferCsrSubRoleFromEmail(emailLower) {
  if (!emailLower) return null;

  if (emailLower.includes('l1@') || emailLower.includes('level1@') || emailLower.includes('csr1@')) {
    return 'level_1';
  }
  if (emailLower.includes('l2@') || emailLower.includes('level2@') || emailLower.includes('csr2@')) {
    return 'level_2';
  }
  if (emailLower.includes('fraud@')) {
    return 'fraud_analyst';
  }
  if (emailLower.includes('compliance@')) {
    return 'compliance_officer';
  }
  if (emailLower.includes('tech@') || emailLower.includes('technical@')) {
    return 'tech_support';
  }
  if (emailLower.includes('lead@') || emailLower.includes('teamlead@')) {
    return 'teamlead';
  }
  return null;
}

module.exports = {
  inferCsrSubRoleFromEmail,
};
