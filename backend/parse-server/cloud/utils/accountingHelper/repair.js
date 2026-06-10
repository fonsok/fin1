'use strict';

/**
 * Facade: Trade-Settlement Reparatur (admin-only).
 * API tiers: `repair/publicSurface.js`. Implementation under `repair/`.
 */

const { publicSurface } = require('./repair/publicSurface');

module.exports = publicSurface;
