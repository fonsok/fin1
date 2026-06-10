'use strict';

const facade = require('../traderAccountStatementPresentation');
const { publicSurface, API_TIERS } = require('../traderAccountStatementPresentation/publicSurface');

describe('traderAccountStatementPresentation public surface contract', () => {
  it('facade exports Tier 1–2 keys only', () => {
    const expected = [
      ...API_TIERS.customerApi,
      ...API_TIERS.belegEnrichment,
    ].sort();
    expect(Object.keys(facade).sort()).toEqual(expected);
    expect(Object.keys(publicSurface).sort()).toEqual(expected);
  });

  it('does not expose timeline builder internals on the facade', () => {
    for (const key of API_TIERS.packageInternal) {
      expect(facade[key]).toBeUndefined();
    }
  });
});
