'use strict';

const {
  shouldSkipPoolActivationForTrade,
} = require('../../../triggers/tradeTriggerPoolActivation');
const {
  resolvePoolActivationDecision,
  POOL_ACTIVATION_SOURCES,
} = require('../poolMirrorActivationService');

describe('tradeTriggerPoolActivation compatibility', () => {
  test('shouldSkipPoolActivationForTrade skips TRADER paired-buy leg', () => {
    const trade = { get: (key) => (key === 'buyLegType' ? 'TRADER' : null) };
    expect(shouldSkipPoolActivationForTrade(trade)).toBe(true);
  });

  test('legacy export resolvePoolActivationDecision matches policy', () => {
    const legacy = { get: () => null };
    expect(
      resolvePoolActivationDecision(legacy, POOL_ACTIVATION_SOURCES.LEGACY_TRADE_AFTER_SAVE).shouldActivate,
    ).toBe(true);
  });
});
