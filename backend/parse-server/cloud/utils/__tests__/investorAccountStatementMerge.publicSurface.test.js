'use strict';

const facade = require('../investorAccountStatementMerge');
const { publicSurface, API_TIERS } = require('../investorAccountStatementMerge/publicSurface');

describe('investorAccountStatementMerge public surface contract', () => {
  it('facade exports exactly the documented Tier 1–2 keys', () => {
    const expected = [
      ...API_TIERS.customerUseCases,
      ...API_TIERS.adminSupport,
    ].sort();
    expect(Object.keys(facade).sort()).toEqual(expected);
    expect(Object.keys(publicSurface).sort()).toEqual(expected);
  });

  it('does not expose package-internal helpers on the facade', () => {
    for (const key of API_TIERS.packageInternal) {
      expect(facade[key]).toBeUndefined();
    }
  });

  it('customer tier has five primary use-cases', () => {
    expect(API_TIERS.customerUseCases).toHaveLength(5);
  });
});
