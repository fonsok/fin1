'use strict';

const {
  buildPoolMirrorExecutionEigenbelegSnapshot,
  isUsablePoolMirrorEigenbelegSummary,
} = require('../poolMirrorExecutionEigenbelegSnapshot');

describe('poolMirrorExecutionEigenbelegSnapshot', () => {
  test('builds pool-specific summary with Reserved / Pool-Einlage', () => {
    const out = buildPoolMirrorExecutionEigenbelegSnapshot({
      executionType: 'buy',
      docNumber: 'PMBC-2026-0000001',
      poolSnap: {
        tradeId: 'mirror-1',
        tradeNumber: 1,
        symbol: 'CI4YLSD',
        wknOrIsin: 'CI4YLSD',
        underlyingAsset: 'FTSE 100',
        optionDirection: 'PUT',
        status: 'pending',
        poolReservedCapitalTotal: 1000,
        poolCapitalAllocated: 999.91,
        poolResidualTotal: 0.09,
        poolInvestorCount: 1,
        impliedBuyQuantityFromPool: 533,
        costBasisPerShare: 1.88,
        bidPricePerShare: 1.86,
        buyFeesTotal: 8,
        poolSoldQuantityDerived: 0,
        poolSellAmountDerived: 0,
        poolSellVolumeProgress: 0,
      },
      traderSnap: {
        tradeId: 'trader-1',
        tradeNumber: 1,
        buyQuantity: 500,
        soldQuantity: 0,
      },
      linkedTraderDocumentNumber: 'TBC-2026-0000033',
    });

    expect(out.metadata.belegKind).toBe('pool_mirror_execution');
    expect(isUsablePoolMirrorEigenbelegSummary(out.accountingSummaryText)).toBe(true);
    expect(out.accountingSummaryText).toContain('Reserved');
    expect(out.accountingSummaryText).toContain('TBC-2026-0000033');
    expect(out.accountingSummaryText).not.toContain('Ordervolumen');
  });
});
