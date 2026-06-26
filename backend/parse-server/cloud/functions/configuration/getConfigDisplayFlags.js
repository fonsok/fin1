'use strict';

/**
 * Resolve display flags for mobile `getConfig` by preferring admin Configuration (live)
 * over legacy Config.display values.
 */
function mergeShowCommissionBreakdownInCreditNote(legacyDisplay, liveDisplay) {
  if (liveDisplay && typeof liveDisplay.showCommissionBreakdownInCreditNote === 'boolean') {
    return liveDisplay.showCommissionBreakdownInCreditNote;
  }
  if (typeof legacyDisplay?.showCommissionBreakdownInCreditNote === 'boolean') {
    return legacyDisplay.showCommissionBreakdownInCreditNote;
  }
  return false;
}

module.exports = {
  mergeShowCommissionBreakdownInCreditNote,
};
