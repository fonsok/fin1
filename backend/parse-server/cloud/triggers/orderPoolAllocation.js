'use strict';

const {
  activatePoolMirrorForTrade,
  POOL_ACTIVATION_SOURCES,
} = require('../services/poolMirrorActivation/poolMirrorActivationService');

async function allocateTradeToInvestmentPools(trade, order = null) {
  return activatePoolMirrorForTrade(trade, {
    source: POOL_ACTIVATION_SOURCES.ORDER_MIRROR_LEG,
    order,
  });
}

module.exports = {
  allocateTradeToInvestmentPools,
};
