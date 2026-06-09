'use strict';

/**
 * Facade: Paired buy (executePairedBuy) TRADER ↔ MIRROR_POOL trade sync.
 * API tiers: `pairedTradeMirrorSync/publicSurface.js`.
 * Implementation: `pairedTradeMirrorSync/legResolution.js`, `sellSync.js`.
 */

const { publicSurface } = require('./pairedTradeMirrorSync/publicSurface');

module.exports = publicSurface;
