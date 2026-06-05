'use strict';

const {
  POOL_ACTIVATION_SOURCES,
  resolvePoolActivationDecision,
  isMirrorPoolOrderLeg,
  isMirrorPoolTradeLeg,
} = require('../poolActivationPolicy');

function makeTrade(fields) {
  return { get: (key) => fields[key] };
}

function makeOrder(fields) {
  return { get: (key) => fields[key] };
}

describe('poolActivationPolicy', () => {
  test('ORDER_MIRROR_LEG allows only MIRROR_POOL trades', () => {
    const mirror = makeTrade({ buyLegType: 'MIRROR_POOL', pairExecutionId: 'pair-1' });
    const trader = makeTrade({ buyLegType: 'TRADER', pairExecutionId: 'pair-1' });

    expect(resolvePoolActivationDecision(mirror, POOL_ACTIVATION_SOURCES.ORDER_MIRROR_LEG).shouldActivate).toBe(true);
    expect(resolvePoolActivationDecision(trader, POOL_ACTIVATION_SOURCES.ORDER_MIRROR_LEG).shouldActivate).toBe(false);
  });

  test('ORDER_MIRROR_LEG accepts mirror order leg when trade row lacks buyLegType', () => {
    const legacyUpsertRow = makeTrade({ buyOrderId: 'ord1234567', pairExecutionId: 'pair-1' });
    const mirrorOrder = makeOrder({ legType: 'MIRROR_POOL', pairExecutionId: 'pair-1' });

    expect(
      resolvePoolActivationDecision(
        legacyUpsertRow,
        POOL_ACTIVATION_SOURCES.ORDER_MIRROR_LEG,
        { order: mirrorOrder },
      ).shouldActivate,
    ).toBe(true);
  });

  test('LEGACY_TRADE_AFTER_SAVE skips order-orchestrated trades', () => {
    const orchestrated = makeTrade({
      buyOrderId: 'ord1234567',
      pairExecutionId: 'pair-1',
      buyLegType: 'MIRROR_POOL',
    });
    expect(
      resolvePoolActivationDecision(orchestrated, POOL_ACTIVATION_SOURCES.LEGACY_TRADE_AFTER_SAVE).shouldActivate,
    ).toBe(false);
  });

  test('LEGACY_TRADE_AFTER_SAVE allows legacy upsert trades', () => {
    const legacy = makeTrade({ tradeNumber: 1, traderId: 'trader-1' });
    expect(
      resolvePoolActivationDecision(legacy, POOL_ACTIVATION_SOURCES.LEGACY_TRADE_AFTER_SAVE).shouldActivate,
    ).toBe(true);
  });

  test('isMirrorPoolOrderLeg identifies mirror order legs', () => {
    expect(isMirrorPoolOrderLeg(makeOrder({ legType: 'MIRROR_POOL' }))).toBe(true);
    expect(isMirrorPoolOrderLeg(makeOrder({ legType: 'TRADER' }))).toBe(false);
  });

  test('isMirrorPoolTradeLeg identifies mirror trade rows', () => {
    expect(isMirrorPoolTradeLeg(makeTrade({ buyLegType: 'MIRROR_POOL' }))).toBe(true);
    expect(isMirrorPoolTradeLeg(makeTrade({ buyLegType: 'TRADER' }))).toBe(false);
  });
});
