'use strict';

const facade = require('../usersDetailStatementsAndWallet');
const { publicSurface, API_TIERS } = require('../usersDetailStatementsAndWallet/publicSurface');

describe('usersDetailStatementsAndWallet public surface contract', () => {
  it('facade exports only the primary admin use-case', () => {
    expect(Object.keys(facade)).toEqual(API_TIERS.adminUseCase);
    expect(Object.keys(publicSurface)).toEqual(['loadAccountStatementAndWalletControls']);
  });

  it('does not expose internal mappers on the facade', () => {
    for (const key of API_TIERS.packageInternal) {
      expect(facade[key]).toBeUndefined();
    }
  });
});
