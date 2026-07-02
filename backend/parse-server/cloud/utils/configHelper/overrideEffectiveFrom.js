'use strict';

function parseEffectiveFrom(effectiveFrom) {
  if (!effectiveFrom) {
    return null;
  }
  const from = effectiveFrom instanceof Date ? effectiveFrom : new Date(effectiveFrom);
  if (Number.isNaN(from.getTime())) {
    return null;
  }
  return from;
}

function isOverrideEffective(effectiveFrom, asOf = new Date()) {
  const from = parseEffectiveFrom(effectiveFrom);
  if (!from) {
    return true;
  }
  const at = asOf instanceof Date ? asOf : new Date(asOf);
  return from.getTime() <= at.getTime();
}

function isScheduledOverride(effectiveFrom, asOf = new Date()) {
  const from = parseEffectiveFrom(effectiveFrom);
  if (!from) {
    return false;
  }
  const at = asOf instanceof Date ? asOf : new Date(asOf);
  return from.getTime() > at.getTime();
}

module.exports = {
  isOverrideEffective,
  isScheduledOverride,
};
