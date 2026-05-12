'use strict';

const { settleAndDistribute } = require('./settlementCore');
const {
  bookTraderBuyEntryIfMissing,
  bookTraderSellDeltaIfAny,
  bookInvestorPartialRealizationDeltaIfAny,
} = require('./settlementDeltas');

module.exports = {
  settleAndDistribute,
  settleCompletedTrade: settleAndDistribute,
  bookTraderBuyEntryIfMissing,
  bookTraderSellDeltaIfAny,
  bookInvestorPartialRealizationDeltaIfAny,
};
