'use strict';

const FRESHNESS_WARN_SECONDS = 8 * 24 * 60 * 60; // 8 days (cron runs weekly)
const FRESHNESS_FAIL_SECONDS = 14 * 24 * 60 * 60; // 14 days
const SETTLEMENT_EPSILON = 0.02;

module.exports = {
  FRESHNESS_WARN_SECONDS,
  FRESHNESS_FAIL_SECONDS,
  SETTLEMENT_EPSILON,
};
