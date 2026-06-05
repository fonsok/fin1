'use strict';

const {
  formatDeValueDate,
  formatDeClosingDate,
  settlementFromInvoice,
  tradingVenueFromLineItems,
} = require('../belegSettlementFields');

describe('belegSettlementFields', () => {
  test('formats Valuta and Schlusstag like iOS', () => {
    const d = new Date('2026-05-15T14:30:00.000Z');
    expect(formatDeValueDate(d)).toBe('15.05.26');
    expect(formatDeClosingDate(d)).toContain('15.05.2026');
    expect(formatDeClosingDate(d)).toContain('Uhr');
  });

  test('extracts trading venue from invoice line items', () => {
    expect(tradingVenueFromLineItems([
      { itemType: 'exchangeFee', description: 'Börsenplatzgebühr (XETRA)' },
    ])).toBe('XETRA');
  });

  test('settlementFromInvoice uses securities description', () => {
    const invoice = {
      get(k) {
        const data = {
          invoiceDate: new Date('2026-05-15T10:00:00.000Z'),
          lineItems: [
            { itemType: 'securities', description: 'CI4YLSD - PUT - FTSE 100' },
            { itemType: 'exchangeFee', description: 'Börsenplatzgebühr (XETRA)' },
          ],
        };
        return data[k];
      },
    };
    const s = settlementFromInvoice(invoice);
    expect(s.instrumentLine).toContain('CI4YLSD');
    expect(s.tradingVenue).toBe('XETRA');
    expect(s.valueDate).toBe('15.05.26');
  });
});
