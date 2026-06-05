'use strict';

const { projectDocumentDetail } = require('../documentBelegPresentation');

function mockDoc(fields) {
  const data = { metadata: {}, ...fields };
  return {
    id: data.id || 'doc-1',
    get(key) {
      return data[key];
    },
  };
}

describe('documentBelegPresentation', () => {
  test('traderCollectionBill buy → KAUF block with fees like iOS', () => {
    const doc = mockDoc({
      type: 'traderCollectionBill',
      userId: 'traderObj12',
      accountingDocumentNumber: 'TBC-2026-0000033',
      tradeNumber: 1,
      metadata: {
        executionType: 'buy',
        symbol: 'CI4YLSD',
        instrumentLine: 'CI4YLSD - PUT - FTSE 100 - 12.808 Pkt. - Citigroup',
        quantity: 500,
        price: 1.86,
        amount: 930,
        fees: { orderFee: 5, exchangeFee: 1, foreignCosts: 1.5, totalFees: 7.5 },
        totalWithFees: 937.5,
        valueDate: '15.05.26',
        closingDate: '15.05.2026, 14:30 Uhr',
        tradingVenue: 'XETRA',
      },
    });
    const out = projectDocumentDetail(doc, undefined, { partyDisplayName: 'Trader One' });
    expect(['computed', 'snapshot']).toContain(out.summarySource);
    const header = out.displaySections.find((s) => s.title === 'Kaufabrechnung');
    expect(header?.rows.some((r) => r.label === 'Trader (User-ID)' && r.value.includes('Trader One'))).toBe(true);
    expect(out.accountingSummaryText).toContain('Ordervolumen');
    expect(out.accountingSummaryText).toContain('Valuta');
    expect(out.accountingSummaryText).toContain('Handelsplatz');
    expect(out.accountingSummaryText).toContain('Σ KAUF');
    const kauf = out.displaySections.find((s) => s.title === 'KAUF');
    expect(kauf?.rows.some((r) => r.label === 'Handelsplatzgebühr')).toBe(true);
    expect(kauf?.rows.some((r) => r.label === 'Valuta')).toBe(true);
    expect(kauf?.rows.some((r) => r.label === 'Σ KAUF')).toBe(true);
  });

  test('investorCollectionBill → buyLeg/sellLeg in display', () => {
    const doc = mockDoc({
      type: 'investorCollectionBill',
      accountingDocumentNumber: 'CB-1',
      metadata: {
        totalBuyCost: 991.82,
        transferAmount: 500,
        buyLeg: { quantity: 491, price: 2.02, amount: 991.82, fees: { totalFees: 8 } },
        sellLeg: { quantity: 0, amount: 0 },
      },
    });
    const out = projectDocumentDetail(doc);
    expect(out.displaySections.some((s) => s.title.includes('Kauf'))).toBe(true);
    expect(out.accountingSummaryText).toContain('991,82');
  });

  test('stored accountingSummaryText wins over computed', () => {
    const doc = mockDoc({
      type: 'investmentReservationEigenbeleg',
      accountingSummaryText: 'Eigenbeleg gespeichert',
      metadata: { amount: 1000 },
    });
    const out = projectDocumentDetail(doc);
    expect(out.summarySource).toBe('stored');
    expect(out.accountingSummaryText).toBe('Eigenbeleg gespeichert');
  });
});
