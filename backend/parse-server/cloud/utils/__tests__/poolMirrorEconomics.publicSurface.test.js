'use strict';

const facade = require('../poolMirrorEconomics');
const { publicSurface, API_TIERS } = require('../poolMirrorEconomics/publicSurface');

describe('poolMirrorEconomics public surface contract', () => {
  it('facade exports exactly the documented Tier 1–2 keys', () => {
    const expected = [
      ...API_TIERS.useCases,
      ...API_TIERS.sellMath,
    ].sort();
    expect(Object.keys(facade).sort()).toEqual(expected);
    expect(Object.keys(publicSurface).sort()).toEqual(expected);
  });

  it('does not expose package-internal helpers on the facade', () => {
    for (const key of API_TIERS.packageInternal) {
      expect(facade[key]).toBeUndefined();
    }
  });

  it('use-case tier has fourteen entry points', () => {
    expect(API_TIERS.useCases).toHaveLength(14);
    expect(API_TIERS.useCases).toContain('tradeEconomicsSnapshot');
  });
});
