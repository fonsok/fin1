'use strict';

function normalizeString(value) {
  if (typeof value !== 'string') return '';
  return value.trim();
}

function parseLegalVersionParts(version) {
  const normalized = normalizeString(version);
  if (!normalized) return [];
  return normalized
    .split('.')
    .map((part) => {
      const digits = part.replace(/[^0-9].*$/, '');
      const parsed = Number.parseInt(digits, 10);
      return Number.isFinite(parsed) ? parsed : 0;
    });
}

/**
 * @returns {-1|0|1} negative when left is older than right
 */
function compareLegalVersions(left, right) {
  const leftParts = parseLegalVersionParts(left);
  const rightParts = parseLegalVersionParts(right);
  const length = Math.max(leftParts.length, rightParts.length);

  for (let index = 0; index < length; index += 1) {
    const leftValue = leftParts[index] || 0;
    const rightValue = rightParts[index] || 0;
    if (leftValue < rightValue) return -1;
    if (leftValue > rightValue) return 1;
  }
  return 0;
}

/** True when userVersion is set and strictly older than activeVersion. */
function isLegalVersionOutdated(userVersion, activeVersion) {
  const stored = normalizeString(userVersion);
  const active = normalizeString(activeVersion);
  if (!stored || !active) return false;
  return compareLegalVersions(stored, active) < 0;
}

module.exports = {
  compareLegalVersions,
  isLegalVersionOutdated,
  parseLegalVersionParts,
};
