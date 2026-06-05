'use strict';

const {
  partitionInvestorCollectionBills,
  buildTraderBelege,
  buildPoolBelege,
} = require('../summaryReportTradeBelege');

function mockDoc({
  id,
  type,
  tradeId,
  investmentId,
  executionType,
  docNumber,
  createdAt,
}) {
  return {
    id,
    get(key) {
      const data = {
        type,
        tradeId,
        investmentId,
        accountingDocumentNumber: docNumber,
        userId: 'inv-1',
        metadata: { executionType },
        createdAt: createdAt || new Date('2026-01-01'),
        name: `${type}_${executionType || ''}`,
      };
      return data[key];
    },
  };
}

describe('summaryReportTradeBelege', () => {
  test('buildTraderBelege maps buy, sells, fees, credit note', () => {
    const docs = [
      mockDoc({ id: 'b1', type: 'traderCollectionBill', executionType: 'buy', docNumber: 'TBC-1' }),
      mockDoc({ id: 's1', type: 'traderCollectionBill', executionType: 'sell', docNumber: 'TSC-1', createdAt: new Date('2026-01-02') }),
      mockDoc({ id: 's2', type: 'traderCollectionBill', executionType: 'sell', docNumber: 'TSC-2', createdAt: new Date('2026-01-03') }),
      mockDoc({ id: 'f1', type: 'invoice', executionType: 'fees', docNumber: 'TFS-1' }),
      mockDoc({ id: 'c1', type: 'traderCreditNote', docNumber: 'TCN-1' }),
    ];
    const out = buildTraderBelege(docs);
    expect(out.buy?.documentId).toBe('b1');
    expect(out.sells).toHaveLength(2);
    expect(out.fees).toBeUndefined();
    expect(out.creditNote?.documentId).toBe('c1');
  });

  test('partitionInvestorCollectionBills: settled → last is full, earlier partial', () => {
    const docs = [
      mockDoc({
        id: 'p1',
        type: 'investorCollectionBill',
        investmentId: 'inv-a',
        docNumber: 'CB-1',
        createdAt: new Date('2026-01-01'),
      }),
      mockDoc({
        id: 'p2',
        type: 'investorCollectionBill',
        investmentId: 'inv-a',
        docNumber: 'CB-2',
        createdAt: new Date('2026-01-02'),
      }),
      mockDoc({
        id: 'full',
        type: 'investorCollectionBill',
        investmentId: 'inv-a',
        docNumber: 'CB-3',
        createdAt: new Date('2026-01-03'),
      }),
    ];
    const { investorFullSettlement, investorPartialSells } = partitionInvestorCollectionBills(
      docs,
      [{ investmentId: 'inv-a', isSettled: true }],
    );
    expect(investorFullSettlement).toHaveLength(1);
    expect(investorFullSettlement[0].documentId).toBe('full');
    expect(investorPartialSells).toHaveLength(2);
    expect(investorPartialSells[0].visibility).toBe('internal');
    expect(investorPartialSells[0].billKind).toBe('partial_sell');
  });

  test('buildPoolBelege uses pool mirror eigenbeleg docs, not trader TBC', () => {
    const poolDocs = [
      mockDoc({
        id: 'pm1',
        type: 'poolMirrorExecutionEigenbeleg',
        executionType: 'buy',
        docNumber: 'PMBC-9',
      }),
      mockDoc({
        id: 'cb1',
        type: 'investorCollectionBill',
        investmentId: 'inv-x',
        docNumber: 'CB-9',
      }),
    ];
    const pool = buildPoolBelege({
      poolDocs,
      participations: [{ investmentId: 'inv-x', isSettled: false }],
    });
    expect(pool.traderExecution.buy?.documentId).toBe('pm1');
    expect(pool.traderExecution.buy?.documentNumber).toBe('PMBC-9');
    expect(pool.traderExecution.buy?.label).toBe('Kaufabrechnung (Pool-Mirror)');
    expect(pool.investorPartialSells).toHaveLength(1);
  });
});
