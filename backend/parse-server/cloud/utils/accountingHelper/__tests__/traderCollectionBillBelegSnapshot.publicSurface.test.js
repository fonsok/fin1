'use strict';

const facade = require('../traderCollectionBillBelegSnapshot');
const { publicSurface, API_TIERS } = require('../traderCollectionBillBelegSnapshot/publicSurface');

describe('traderCollectionBillBelegSnapshot public surface contract', () => {
  it('facade exports Tier 1–2 keys only', () => {
    const expected = [
      ...API_TIERS.belegSnapshots,
      ...API_TIERS.backfillSupport,
    ].sort();
    expect(Object.keys(facade).sort()).toEqual(expected);
    expect(Object.keys(publicSurface).sort()).toEqual(expected);
  });

  it('does not expose formatting helpers on the facade', () => {
    for (const key of API_TIERS.packageInternal) {
      expect(facade[key]).toBeUndefined();
    }
  });
});
