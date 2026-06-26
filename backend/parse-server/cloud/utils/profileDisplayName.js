'use strict';

/**
 * Short display label for UserProfile rows (e.g. "Jan B.").
 * Safe when firstName/lastName are missing (early signup before personal-info step).
 */
function formatProfileShortDisplayName(profile, fallback = 'Trader') {
  if (!profile || typeof profile.get !== 'function') {
    return String(fallback || 'Trader').trim() || 'Trader';
  }
  return formatNameFieldsShortDisplayName(
    profile.get('firstName'),
    profile.get('lastName'),
    fallback,
  );
}

function formatNameFieldsShortDisplayName(firstName, lastName, fallback = 'Trader') {
  const first = String(firstName || '').trim();
  const last = String(lastName || '').trim();
  if (first && last) {
    return `${first} ${last.charAt(0)}.`;
  }
  if (first) return first;
  if (last) return last;
  const fb = String(fallback || '').trim();
  return fb || 'Trader';
}

module.exports = {
  formatProfileShortDisplayName,
  formatNameFieldsShortDisplayName,
};
