'use strict';

const facade = require('../investmentEscrow');
const { publicSurface, API_TIERS } = require('../investmentEscrow/publicSurface');

describe('investmentEscrow public surface contract', () => {
  it('facade exports exactly the documented Tier 1–3 keys', () => {
    const expected = [
      ...API_TIERS.stableBooking,
      ...API_TIERS.settlementSupport,
      ...API_TIERS.repairOps,
    ].sort();
    expect(Object.keys(facade).sort()).toEqual(expected);
    expect(Object.keys(publicSurface).sort()).toEqual(expected);
  });

  it('does not expose package-internal Tier 4 helpers on the facade', () => {
    for (const key of API_TIERS.packageInternal) {
      expect(facade[key]).toBeUndefined();
    }
    expect(facade.TRANSACTION_TYPE).toBeUndefined();
    expect(facade.buildPairedLedgerEntries).toBeUndefined();
    expect(facade.sumEscrowLegCreditForTrade).toBeUndefined();
  });

  it('stable booking tier has nine use-cases', () => {
    expect(API_TIERS.stableBooking).toHaveLength(9);
  });
});
