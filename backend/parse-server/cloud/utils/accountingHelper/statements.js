'use strict';

/**
 * Facade: Personenkonto (`bookAccountStatementEntry`) + Settlement-GL-Posting
 * (`bookSettlementEntry`). Implementation split for maintainability:
 *   - `accountStatementWriter.js` — single AccountStatement row + Phase 3b balance
 *   - `settlementGLRules.js` — entryType → GL pair mapping
 *   - `settlementGLPoster.js` — bookSettlementEntry + postLedgerPair wiring
 *
 * All existing `require('./statements')` paths stay valid.
 */

const { bookAccountStatementEntry } = require('./accountStatementWriter');
const {
  bookSettlementEntry,
  bookInvestorCommissionClearingGL,
  getSettlementGLRule,
  ORDER_FEE_COMPONENTS,
} = require('./settlementGLPoster');

module.exports = {
  bookAccountStatementEntry,
  bookSettlementEntry,
  bookInvestorCommissionClearingGL,
  getSettlementGLRule,
  ORDER_FEE_COMPONENTS,
};
