'use strict';

/**
 * Facade: GoB accounting documents (Parse `Document` rows).
 * API tiers: `documents/publicSurface.js`. Implementation under `documents/`.
 */

const { publicSurface } = require('./documents/publicSurface');

module.exports = publicSurface;
