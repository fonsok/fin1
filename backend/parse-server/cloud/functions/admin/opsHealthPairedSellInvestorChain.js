'use strict';

const { scanPairedSellInvestorChainIntegrity } = require('../../utils/pairedSellInvestorChainIntegrity');

/**
 * Admin / ops: end-to-end paired buy → trader sell → mirror sync → investor settlement.
 * SSOT: Documentation/PAIRED_BUY_SELL_INVESTOR_INVARIANTS.md
 */
async function handleGetPairedSellInvestorChainStatus(request) {
  const limit = Number(request.params?.limit || 25);
  const result = await scanPairedSellInvestorChainIntegrity({ limit });
  return {
    ...result,
    checkedAt: new Date().toISOString(),
  };
}

module.exports = {
  handleGetPairedSellInvestorChainStatus,
};
