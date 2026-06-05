'use strict';

const {
  documentPartyRole,
  formatPartyValue,
  attachPartyFieldsToRow,
} = require('../documentPartyPresentation');

function mockDoc(type, fields = {}) {
  return {
    get(key) {
      if (key === 'type') return type;
      return fields[key];
    },
  };
}

describe('documentPartyPresentation', () => {
  test('documentPartyRole maps trader and investor types', () => {
    expect(documentPartyRole('traderCollectionBill', mockDoc('traderCollectionBill'))).toBe('trader');
    expect(documentPartyRole('traderCreditNote', mockDoc('traderCreditNote'))).toBe('trader');
    expect(documentPartyRole('investorCollectionBill', mockDoc('investorCollectionBill'))).toBe('investor');
    expect(documentPartyRole('investmentReservationEigenbeleg', mockDoc('investmentReservationEigenbeleg')))
      .toBe('investor');
    expect(documentPartyRole('invoice', mockDoc('invoice'))).toBe('other');
  });

  test('formatPartyValue combines name and id', () => {
    expect(formatPartyValue('abc1234567', 'Max Mustermann')).toBe('Max Mustermann · abc1234567');
    expect(formatPartyValue('abc1234567', '')).toBe('abc1234567');
    expect(formatPartyValue('', 'Max')).toBe('—');
  });

  test('attachPartyFieldsToRow sets traderName for trader documents', () => {
    const doc = mockDoc('traderCollectionBill', { userId: 'traderObj12' });
    const displayMap = new Map([
      ['traderObj12', { name: 'Trader One', username: 't1', customerNumber: '' }],
    ]);
    const row = { type: 'traderCollectionBill', userId: 'traderObj12' };
    const out = attachPartyFieldsToRow(row, doc, displayMap);
    expect(out.partyRole).toBe('trader');
    expect(out.partyDisplayName).toBe('Trader One');
    expect(out.traderId).toBe('traderObj12');
    expect(out.traderName).toBe('Trader One');
    expect(out.partyLabel).toBe('Trader');
  });
});
