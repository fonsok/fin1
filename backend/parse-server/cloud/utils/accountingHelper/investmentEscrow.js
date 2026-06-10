'use strict';

/**
 * Facade: Investment-Escrow (CLT-LIAB-*): reserve → pool trade (PTR) → release.
 * Balanced pairs only; idempotent per investmentId + metadata.leg.
 * See Documentation/INVESTMENT_ESCROW_LEDGER_SKETCH.md (§5.1 API tiers).
 *
 * Implementation: `investmentEscrow/publicSurface.js` + submodules under `investmentEscrow/`.
 * All existing `require('./investmentEscrow')` paths stay valid for Tier 1–3 exports.
 */

const { publicSurface } = require('./investmentEscrow/publicSurface');

module.exports = publicSurface;
