'use strict';

const { pickUserDisplayName } = require('../traderDisplayNameForBeleg');

describe('traderDisplayNameForBeleg', () => {
  test('pickUserDisplayName prefers full name', () => {
    const user = {
      get(k) {
        const data = {
          firstName: 'Max',
          lastName: 'Mustermann',
          username: 'maxm',
          customerNumber: 'C-1',
          email: 'max@example.com',
        };
        return data[k];
      },
    };
    expect(pickUserDisplayName(user, null)).toBe('Max Mustermann');
  });

  test('pickUserDisplayName falls back to username', () => {
    const user = {
      get(k) {
        const data = { firstName: '', lastName: '', username: 'trader1', customerNumber: '', email: '' };
        return data[k];
      },
    };
    expect(pickUserDisplayName(user, null)).toBe('trader1');
  });
});
