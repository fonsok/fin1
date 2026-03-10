'use strict';

/**
 * Normalize requesterId from Parse object (string or Pointer) to string objectId.
 */
function getRequesterIdString(obj) {
  const rid = obj.get ? obj.get('requesterId') : obj.requesterId;
  if (rid == null) return '';
  if (typeof rid === 'string') return rid;
  if (rid.objectId) return rid.objectId;
  if (rid.id) return rid.id;
  return String(rid);
}

function getRoleDescription(role) {
  const descriptions = {
    admin: 'Full App Administrator',
    business_admin: 'Business/Accounting Administrator',
    security_officer: 'Security Officer',
    compliance: 'Compliance Officer',
    customer_service: 'Customer Service Representative',
    system: 'System Process',
  };
  return descriptions[role] || role;
}

module.exports = { getRequesterIdString, getRoleDescription };
