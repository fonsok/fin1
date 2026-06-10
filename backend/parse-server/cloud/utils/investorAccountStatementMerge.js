'use strict';

/**
 * Facade: Investor account statement merge (AccountStatement + AVA AppLedger).
 * API tiers: Documentation/BOOKING_AND_BELEG_SSOT.md (Investor-Kontoauszug).
 * Implementation: `investorAccountStatementMerge/publicSurface.js` + submodules.
 */

const { publicSurface } = require('./investorAccountStatementMerge/publicSurface');

module.exports = publicSurface;
