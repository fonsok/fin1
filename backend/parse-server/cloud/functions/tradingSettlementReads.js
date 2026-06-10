'use strict';

/**
 * Facade: Trading settlement read Cloud Functions.
 * API tiers: `tradingSettlementReads/publicSurface.js`.
 */

const { publicSurface } = require('./tradingSettlementReads/publicSurface');

module.exports = publicSurface;
