'use strict';

const { round2 } = require('../shared');
const {
  readCreditNoteInlineBreakdownMax,
  shouldInlineCreditNoteBreakdown,
} = require('../../../services/poolMirrorActivation/poolMirrorScaleLimits');

function mapBreakdownRow(b) {
  return {
    investorId: b.investorId,
    investorName: b.investorName || null,
    investmentId: b.investmentId,
    grossProfit: round2(b.grossProfit),
    commission: round2(b.commission),
    taxWithheld: round2(b.taxWithheld || 0),
  };
}

/**
 * Credit note metadata: full per-investor rows only up to cap; otherwise summary fields only.
 */
function buildCreditNoteInvestorBreakdownMetadata(investorBreakdown = []) {
  const rows = Array.isArray(investorBreakdown) ? investorBreakdown : [];
  const investorCount = rows.length;
  const inlineMax = readCreditNoteInlineBreakdownMax();
  const truncated = !shouldInlineCreditNoteBreakdown(investorCount);

  return {
    investorCount,
    investorBreakdownTruncated: truncated,
    investorBreakdownInlineMax: inlineMax,
    investorBreakdown: truncated ? [] : rows.map(mapBreakdownRow),
  };
}

module.exports = {
  buildCreditNoteInvestorBreakdownMetadata,
  mapBreakdownRow,
};
