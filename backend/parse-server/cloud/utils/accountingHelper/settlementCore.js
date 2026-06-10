'use strict';

/**
 * Facade: Trade settlement orchestration (`settleAndDistribute`).
 * Implementation split under accountingHelper/settlementCore/ — all
 * require('./settlementCore') paths stay valid.
 */

const { settleAndDistribute } = require('./settlementCore/settleAndDistribute');

module.exports = {
  settleAndDistribute,
};
