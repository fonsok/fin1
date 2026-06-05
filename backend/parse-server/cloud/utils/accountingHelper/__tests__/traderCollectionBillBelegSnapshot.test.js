'use strict';

jest.mock('../../helpers', () => ({
  calculateOrderFees: jest.fn(() => ({
    orderFee: 5,
    exchangeFee: 1,
    foreignCosts: 1.5,
    totalFees: 7.5,
  })),
}));

const {
  buildTraderCollectionBillBelegSnapshot,
  buildTradingFeesBelegSnapshot,
  formatTraderCollectionBillSummaryText,
  traderCollectionBillDisplaySections,
  TRADER_COLLECTION_BILL_SCHEMA_VERSION,
  isUsableTraderBelegSummaryText,
  metadataNeedsBackfill,
} = require('../traderCollectionBillBelegSnapshot');

function mockTrade(overrides = {}) {
  const data = {
    id: 'trade-1',
    tradeNumber: 33,
    symbol: 'CI4YLSD',
    quantity: 500,
    feeConfig: {},
    createdAt: new Date('2026-05-15T14:30:00.000Z'),
    buyOrder: {
      price: 1.86,
      quantity: 500,
      wkn: 'CI4YLSD',
      optionDirection: 'PUT',
      underlyingAsset: 'FTSE 100',
      strikePrice: '12.808',
      issuer: 'Citigroup',
      createdAt: new Date('2026-05-15T14:30:00.000Z'),
    },
    ...overrides,
  };
  return {
    id: data.id,
    get(k) {
      return data[k];
    },
  };
}

describe('traderCollectionBillBelegSnapshot', () => {
  test('builds v1 metadata + summary + booking invariants', () => {
    const trade = mockTrade();
    const out = buildTraderCollectionBillBelegSnapshot({
      trade,
      order: trade.get('buyOrder'),
      executionType: 'buy',
      grossAmount: 930,
      label: 'Kaufabrechnung',
      docNumber: 'TBC-2026-0000033',
      tradeNumber: 33,
      traderParty: {
        traderId: 'traderObj12',
        traderDisplayName: 'Trader One',
        traderUsername: 'trader1',
      },
    });

    expect(out.metadata.belegSchemaVersion).toBe(TRADER_COLLECTION_BILL_SCHEMA_VERSION);
    expect(out.metadata.traderDisplayName).toBe('Trader One');
    expect(out.accountingSummaryText).toContain('Trader: Trader One');
    expect(out.metadata.amount).toBe(930);
    expect(out.metadata.totalWithFees).toBe(937.5);
    expect(out.metadata.fees.orderFee).toBe(5);
    expect(out.booking.signedTotal).toBe(-937.5);
    expect(out.accountingSummaryText).toContain('TBC-2026-0000033');
    expect(out.accountingSummaryText).toContain('Σ KAUF');
    expect(out.accountingSummaryText).toContain('Handelsplatzgebühr');
  });

  test('prefers invoice securities line for instrument', () => {
    const trade = mockTrade();
    const invoice = {
      get(k) {
        const data = {
          invoiceDate: new Date('2026-05-15T14:30:00.000Z'),
          lineItems: [
            { itemType: 'securities', description: 'CI4YLSD - PUT - FTSE 100 - 12.808 Pkt. - Citigroup' },
            { itemType: 'exchangeFee', description: 'Börsenplatzgebühr (XETRA)' },
          ],
        };
        return data[k];
      },
    };
    const out = buildTraderCollectionBillBelegSnapshot({
      trade,
      executionType: 'buy',
      grossAmount: 930,
      label: 'Kaufabrechnung',
      docNumber: 'TBC-1',
      tradeNumber: 1,
      invoice,
    });
    expect(out.metadata.instrumentLine).toContain('Citigroup');
    expect(out.metadata.tradingVenue).toBe('XETRA');
  });

  test('display sections match metadata without recompute', () => {
    const meta = {
      belegSchemaVersion: 1,
      belegLabel: 'Kaufabrechnung',
      executionType: 'buy',
      instrumentLine: 'CI4YLSD - PUT',
      quantity: 500,
      price: 1.86,
      amount: 930,
      fees: { orderFee: 5, exchangeFee: 1, foreignCosts: 1.5, totalFees: 7.5 },
      totalWithFees: 937.5,
      valueDate: '15.05.26',
      tradingVenue: 'XETRA',
    };
    const doc = {
      get(k) {
        if (k === 'accountingDocumentNumber') return 'TBC-1';
        if (k === 'tradeNumber') return 1;
        return null;
      },
    };
    const sections = traderCollectionBillDisplaySections(meta, doc);
    const text = formatTraderCollectionBillSummaryText({
      label: 'Kaufabrechnung',
      docNumber: 'TBC-1',
      tradeNumber: 1,
      metadata: meta,
    });
    expect(sections.some((s) => s.title === 'KAUF')).toBe(true);
    expect(text).toContain('Ordervolumen');
    expect(text).toContain('Valuta');
  });

  test('rejects non-positive grossAmount', () => {
    expect(() => buildTraderCollectionBillBelegSnapshot({
      trade: mockTrade(),
      executionType: 'buy',
      grossAmount: 0,
      label: 'Kauf',
      docNumber: 'TBC-0',
      tradeNumber: 1,
    })).toThrow('grossAmount must be > 0');
  });

  test('isUsableTraderBelegSummaryText detects SSOT markers', () => {
    expect(isUsableTraderBelegSummaryText('')).toBe(false);
    expect(isUsableTraderBelegSummaryText('nur Text')).toBe(false);
    expect(isUsableTraderBelegSummaryText('Ordervolumen 930,00 €')).toBe(true);
  });

  test('metadataNeedsBackfill flags legacy sparse metadata', () => {
    expect(metadataNeedsBackfill(null)).toBe(true);
    expect(metadataNeedsBackfill({ amount: 100 })).toBe(true);
    expect(metadataNeedsBackfill({
      belegSchemaVersion: 1,
      amount: 930,
      fees: { totalFees: 7.5, orderFee: 5 },
    })).toBe(true);
    expect(metadataNeedsBackfill({
      belegSchemaVersion: 1,
      amount: 930,
      traderDisplayName: 'Trader One',
      fees: { totalFees: 7.5, orderFee: 5 },
    })).toBe(false);
  });

  test('buildTradingFeesBelegSnapshot for trading_fees ledger companion', () => {
    const out = buildTradingFeesBelegSnapshot({
      trade: mockTrade(),
      totalFees: 12.5,
      feeBreakdown: { orderFee: 10, exchangeFee: 1, foreignCosts: 1.5 },
      label: 'Gebührenabrechnung',
      docNumber: 'TFS-2026-0000001',
      tradeNumber: 33,
    });
    expect(out.metadata.executionType).toBe('fees');
    expect(out.metadata.belegKind).toBe('traderTradingFees');
    expect(out.metadata.fees.totalFees).toBe(12.5);
    expect(out.accountingSummaryText).toContain('Σ Gebühren');
    expect(out.booking.signedTotal).toBe(-12.5);
  });
});
