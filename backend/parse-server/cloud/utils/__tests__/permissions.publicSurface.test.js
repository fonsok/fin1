'use strict';

const facade = require('../permissions');
const { publicSurface, API_TIERS } = require('../permissions/publicSurface');

describe('permissions public surface contract', () => {
  it('facade exports exactly the documented Tier 1–4 keys', () => {
    const expected = [
      ...API_TIERS.guards,
      ...API_TIERS.constants,
      ...API_TIERS.roleIntrospection,
      ...API_TIERS.audit,
    ].sort();
    expect(Object.keys(facade).sort()).toEqual(expected);
    expect(Object.keys(publicSurface).sort()).toEqual(expected);
  });

  it('does not expose package-internal role helpers on the facade', () => {
    for (const key of API_TIERS.packageInternal) {
      expect(facade[key]).toBeUndefined();
    }
  });

  it('guard tier has three use-cases', () => {
    expect(API_TIERS.guards).toHaveLength(3);
  });
});
