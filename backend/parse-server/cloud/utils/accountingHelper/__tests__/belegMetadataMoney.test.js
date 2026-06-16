'use strict';

const {
  finalizeTraderBelegMetadata,
  finalizeInvestorBelegMetadata,
  finalizeBelegMetadataForPersist,
  normalizeMoneyField,
  isCentAlignedEuro,
} = require('../belegMetadataMoney');
const { euroToCents } = require('../moneyCents');

describe('belegMetadataMoney (P3c-2a)', () => {
  test('finalizeTraderBelegMetadata cent-normalizes amount, fees, totalWithFees', () => {
    const out = finalizeTraderBelegMetadata({
      belegKind: 'traderCollectionBill',
      amount: 1095.4200000001,
      totalWithFees: 1087.9200000001,
      fees: {
        orderFee: 5.0000000001,
        exchangeFee: 1,
        foreignCosts: 1.5,
        totalFees: 7.5000000001,
      },
      quantity: 400,
      price: 2.73855,
    }, { tradeId: 'trade-1' });

    expect(out.amount).toBe(1095.42);
    expect(out.totalWithFees).toBe(1087.92);
    expect(out.fees.totalFees).toBe(7.5);
    expect(out.quantity).toBe(400);
    expect(out.price).toBe(2.73855);
    expect(isCentAlignedEuro(out.amount)).toBe(true);
    expect(isCentAlignedEuro(out.fees.orderFee)).toBe(true);
  });

  test('finalizeTraderBelegMetadata throws on non-finite amount', () => {
    expect(() => finalizeTraderBelegMetadata({
      amount: Number.NaN,
      fees: { totalFees: 1 },
    })).toThrow(/non-finite amount/);
  });

  test('finalizeInvestorBelegMetadata normalizes top-level and leg fees', () => {
    const out = finalizeInvestorBelegMetadata({
      belegKind: 'investorCollectionBill',
      grossProfit: 528.7600000001,
      commission: 52.8800000001,
      netProfit: 475.9200000001,
      transferAmount: 475.9200000001,
      buyLeg: {
        amount: 999.9360000001,
        fees: { totalFees: 7.5 },
        quantity: 500,
      },
      sellLeg: {
        amount: 1500.0000000001,
        fees: { totalFees: 8.25 },
        quantity: 500,
      },
      taxBreakdown: {
        withholdingTax: 10.0000000001,
        totalTax: 12.3400000001,
      },
    });

    expect(out.grossProfit).toBe(528.76);
    expect(out.buyLeg.amount).toBe(999.94);
    expect(out.buyLeg.fees.totalFees).toBe(7.5);
    expect(out.sellLeg.amount).toBe(1500);
    expect(out.taxBreakdown.totalTax).toBe(12.34);
    expect(euroToCents(out.commission)).toBe(5288);
  });

  test('finalizeBelegMetadataForPersist routes by belegKind', () => {
    const trader = finalizeBelegMetadataForPersist({
      belegKind: 'traderCollectionBill',
      amount: 100.001,
      fees: { totalFees: 1.001 },
      totalWithFees: 99.001,
    });
    expect(trader.amount).toBe(100);

    const investor = finalizeBelegMetadataForPersist({
      belegKind: 'investorCollectionBill',
      grossProfit: 10.004,
      commission: 1.004,
      netProfit: 9,
      transferAmount: 9,
      buyLeg: { amount: 100.004, fees: { totalFees: 1 } },
      sellLeg: { amount: 110.004, fees: { totalFees: 1 } },
    });
    expect(investor.grossProfit).toBe(10);
  });

  test('normalizeMoneyField rejects non-finite values', () => {
    expect(() => normalizeMoneyField(Number.POSITIVE_INFINITY, 'amount')).toThrow(/non-finite/);
  });
});
