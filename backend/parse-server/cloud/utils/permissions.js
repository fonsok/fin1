'use strict';

/**
 * Facade: Role-Based Access Control.
 * API tiers: `permissions/publicSurface.js`.
 * @see Documentation/FIN1_APP_DOCS/09_ADMIN_ROLES_SEPARATION.md
 */

const { publicSurface } = require('./permissions/publicSurface');

module.exports = publicSurface;
