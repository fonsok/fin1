'use strict';

const facade = require('../pairedTradeMirrorSync');
const { publicSurface, API_TIERS } = require('../pairedTradeMirrorSync/publicSurface');

describe('pairedTradeMirrorSync public surface contract', () => {
  it('facade exports exactly the documented Tier 1–2 keys', () => {
    const expected = [
      ...API_TIERS.syncUseCases,
      ...API_TIERS.legResolution,
    ].sort();
    expect(Object.keys(facade).sort()).toEqual(expected);
    expect(Object.keys(publicSurface).sort()).toEqual(expected);
  });

  it('does not expose applyMirrorSellSyncFromTraderLeg on the facade', () => {
    for (const key of API_TIERS.packageInternal) {
      expect(facade[key]).toBeUndefined();
    }
  });

  it('sync use-case tier has two entry points', () => {
    expect(API_TIERS.syncUseCases).toHaveLength(2);
  });
});
