'use strict';

const { computeInvestorBuyLeg } = require('../../../../utils/accountingHelper/legs');
const {
  buildPartialSellEvents,
  groupInvestorPartialSellBelegeByEvent,
} = require('../summaryReportPartialSellEvents');

function mockParseTrade(data) {
  return {
    id: data.id || 'trade-1',
    get(key) {
      return data[key];
    },
  };
}

describe('buildPartialSellEvents', () => {
  const participations = [
    {
      investmentId: 'inv-1',
      investmentNumber: 'INV-001',
      investorId: 'user-1',
      investorName: 'Investor One',
      investmentCapital: 1000,
      investmentStatus: 'active',
    },
  ];

  test('two partial sells: per-event delta matches settlement sellFraction', () => {
    const buyLeg = computeInvestorBuyLeg(1000, 2.02, {});
    const traderTrade = mockParseTrade({
      quantity: 1000,
      buyOrder: { quantity: 1000, totalAmount: 2020, price: 2.02 },
      sellOrders: [
        { quantity: 200, totalAmount: 600, price: 3, createdAt: '2026-01-10T10:00:00.000Z' },
        { quantity: 300, totalAmount: 900, price: 3, createdAt: '2026-01-15T10:00:00.000Z' },
      ],
    });
    const poolTrade = mockParseTrade({
      buyOrder: { price: 2.02 },
      entryPrice: 2.02,
    });

    const events = buildPartialSellEvents({
      traderTrade,
      poolTrade,
      poolMirrorSnap: {
        impliedBuyQuantityFromPool: buyLeg.quantity,
        costBasisPerShare: 2.0403,
        sellPrice: 3,
      },
      participations,
      feeConfig: {},
      commissionRate: 0.11,
    });

    expect(events).toHaveLength(2);

    expect(events[0].eventIndex).toBe(1);
    expect(events[0].traderSellQuantity).toBe(200);
    expect(events[0].traderSellQuantityCumulative).toBe(200);
    expect(events[0].traderSellVolumeProgress).toBe(0.2);
    expect(events[0].sellFraction).toBe(0.2);
    expect(events[0].poolSellQuantity).toBe(98);
    expect(events[0].isFinalExit).toBe(false);

    expect(events[1].eventIndex).toBe(2);
    expect(events[1].traderSellQuantity).toBe(300);
    expect(events[1].traderSellQuantityCumulative).toBe(500);
    expect(events[1].traderSellVolumeProgress).toBe(0.5);
    expect(events[1].sellFraction).toBe(0.3);
    expect(events[1].poolSellQuantityCumulative).toBe(245);
    expect(events[1].isFinalExit).toBe(false);

    expect(events[0].investorRealizations[0].sellQuantity).toBe(98);
    expect(events[1].investorRealizations[0].sellQuantity).toBeGreaterThan(0);
    expect(events[1].investorRealizations[0].grossProfit).toBeDefined();
    expect(
      events[0].investorRealizations[0].sellQuantity + events[1].investorRealizations[0].sellQuantity,
    ).toBe(events[1].poolSellQuantityCumulative);
  });

  test('SG4GTIH-Szenario: 598 Pool-Stück, Investor-Summe = Pool-Kumulativ', () => {
    const traderTrade = mockParseTrade({
      quantity: 1000,
      buyAmount: 1660,
      buyOrder: { quantity: 1000, totalAmount: 1660, price: 1.66 },
      sellOrders: [
        { quantity: 500, totalAmount: 1000, price: 2, createdAt: '2026-06-01T10:00:00.000Z' },
        { quantity: 200, totalAmount: 600, price: 3, createdAt: '2026-06-02T10:00:00.000Z' },
      ],
    });
    const poolTrade = mockParseTrade({
      buyOrder: { price: 1.66, quantity: 1000, totalAmount: 1660 },
    });

    const events = buildPartialSellEvents({
      traderTrade,
      poolTrade,
      poolMirrorSnap: {
        impliedBuyQuantityFromPool: 598,
        costBasisPerShare: 1.6713,
        sellPrice: 2,
      },
      participations,
      feeConfig: {},
      commissionRate: 0.11,
    });

    expect(events).toHaveLength(2);
    expect(events[0].poolSellQuantity).toBe(299);
    expect(events[0].investorRealizations[0].sellQuantity).toBe(299);
    expect(events[1].poolSellQuantity).toBe(119);
    expect(events[1].investorRealizations[0].sellQuantity).toBe(119);
    expect(events[1].poolSellQuantityCumulative).toBe(418);
    expect(
      events[0].investorRealizations[0].sellQuantity + events[1].investorRealizations[0].sellQuantity,
    ).toBe(418);
  });

  test('full trader exit sells all 598 pool pieces (no 597 rounding rest)', () => {
    const traderTrade = mockParseTrade({
      quantity: 1000,
      buyOrder: { quantity: 1000, totalAmount: 1660, price: 1.66 },
      sellOrders: [
        { quantity: 333, totalAmount: 666, price: 2, createdAt: '2026-06-01T10:00:00.000Z' },
        { quantity: 333, totalAmount: 666, price: 2, createdAt: '2026-06-02T10:00:00.000Z' },
        { quantity: 334, totalAmount: 668, price: 2, createdAt: '2026-06-03T10:00:00.000Z' },
      ],
    });
    const poolTrade = mockParseTrade({
      buyOrder: { price: 1.66, quantity: 1000, totalAmount: 1660 },
    });

    const events = buildPartialSellEvents({
      traderTrade,
      poolTrade,
      poolMirrorSnap: {
        impliedBuyQuantityFromPool: 598,
        costBasisPerShare: 1.6713,
        sellPrice: 2,
      },
      participations,
      feeConfig: {},
      commissionRate: 0.11,
    });

    expect(events).toHaveLength(3);
    expect(events[2].isFinalExit).toBe(true);
    expect(events[2].poolSellQuantityCumulative).toBe(598);
    expect(events[2].traderSellVolumeProgress).toBe(1);
    const investorSum = events.reduce(
      (s, e) => s + (e.investorRealizations[0]?.sellQuantity || 0),
      0,
    );
    expect(investorSum).toBe(598);
  });

  test('links belege by event index', () => {
    const traderTrade = mockParseTrade({
      quantity: 1000,
      buyOrder: { quantity: 1000, price: 2 },
      sellOrders: [
        { quantity: 100, totalAmount: 300, price: 3 },
        { quantity: 100, totalAmount: 310, price: 3.1 },
      ],
    });

    const events = buildPartialSellEvents({
      traderTrade,
      poolTrade: traderTrade,
      poolMirrorSnap: { impliedBuyQuantityFromPool: 495 },
      participations,
      traderBelege: {
        sells: [
          { documentId: 't-sell-1', documentNumber: 'TSC-1' },
          { documentId: 't-sell-2', documentNumber: 'TSC-2' },
        ],
      },
      poolBelege: {
        traderExecution: {
          sells: [
            { documentId: 'p-sell-1', documentNumber: 'PM-1' },
            { documentId: 'p-sell-2', documentNumber: 'PM-2' },
          ],
        },
        investorPartialSells: [
          { documentId: 'cb-1', investmentId: 'inv-1', createdAt: '2026-01-01' },
          { documentId: 'cb-2', investmentId: 'inv-1', createdAt: '2026-01-02' },
        ],
      },
      feeConfig: {},
      commissionRate: 0.11,
    });

    expect(events[0].traderSellBeleg?.documentId).toBe('t-sell-1');
    expect(events[1].poolMirrorSellBeleg?.documentId).toBe('p-sell-2');
    expect(events[0].investorPartialSellBelege[0]?.documentId).toBe('cb-1');
    expect(events[1].investorPartialSellBelege[0]?.documentId).toBe('cb-2');
  });
});

describe('groupInvestorPartialSellBelegeByEvent', () => {
  test('groups per investment by chronological index', () => {
    const participations = [
      { investmentId: 'inv-a' },
      { investmentId: 'inv-b' },
    ];
    const links = [
      { investmentId: 'inv-a', createdAt: '2026-01-01', documentId: 'a1' },
      { investmentId: 'inv-b', createdAt: '2026-01-01', documentId: 'b1' },
      { investmentId: 'inv-a', createdAt: '2026-01-02', documentId: 'a2' },
      { investmentId: 'inv-b', createdAt: '2026-01-02', documentId: 'b2' },
    ];
    const grouped = groupInvestorPartialSellBelegeByEvent(links, participations, 2);
    expect(grouped[0].map((l) => l.documentId).sort()).toEqual(['a1', 'b1']);
    expect(grouped[1].map((l) => l.documentId).sort()).toEqual(['a2', 'b2']);
  });
});
