'use strict';

jest.mock('../../../../utils/permissions', () => ({
  requirePermission: jest.fn(),
}));

const { handleExportAuditorFinancialCsv } = require('../auditorExport');

function mockParse() {
  global.Parse = global.Parse || {};
  if (!global.Parse.Error) {
    global.Parse.Error = class ParseError extends Error {
      constructor(code, message) {
        super(message);
        this.code = code;
      }
      static get INVALID_QUERY() {
        return 102;
      }
    };
  }
}

function row(id, attrs) {
  return {
    id,
    get(k) {
      return attrs[k];
    },
  };
}

describe('exportAuditorFinancialCsv (handleExportAuditorFinancialCsv)', () => {
  const from = '2026-01-01T00:00:00.000Z';
  const to = '2026-01-31T23:59:59.999Z';

  beforeEach(() => {
    mockParse();
    const resultsByClass = {
      AccountStatement: [
        row('st1', {
          createdAt: new Date('2026-01-10T12:00:00.000Z'),
          userId: 'userA',
          entryType: 'deposit',
          amount: 50,
          balanceAfter: 50,
          tradeId: '',
          tradeNumber: 1,
          investmentId: '',
          investmentNumber: '',
          referenceDocumentId: 'doc1',
          referenceDocumentNumber: 'WDR-2026-0000001',
          businessCaseId: 'bc-test-1',
          businessReference: 'Beleg WDR-2026-0000001',
          description: 'Einzahlung',
          source: 'backend',
        }),
      ],
      AppLedgerEntry: [
        row('gl1', {
          createdAt: new Date('2026-01-10T12:01:00.000Z'),
          account: 'CLT-LIAB-AVA',
          side: 'credit',
          amount: 50,
          userId: 'userA',
          userRole: 'user',
          transactionType: 'walletDeposit',
          referenceId: 'wt1',
          referenceType: 'WalletTransaction',
          description: 'deposit',
          metadata: { leg: 'wallet:deposit', businessCaseId: 'bc-test-1', referenceDocumentNumber: 'WDR-2026-0000001' },
        }),
      ],
      Document: [
        row('doc1', {
          createdAt: new Date('2026-01-10T12:00:00.000Z'),
          userId: 'userA',
          type: 'financial',
          accountingDocumentNumber: 'WDR-2026-0000001',
          documentNumber: '',
          tradeId: '',
          investmentId: '',
          referenceId: 'wt1',
          referenceType: 'WalletTransaction',
          businessCaseId: 'bc-test-1',
          source: 'backend',
        }),
      ],
      WalletTransaction: [
        row('wt1', {
          createdAt: new Date('2026-01-10T11:59:00.000Z'),
          completedAt: new Date('2026-01-10T12:00:00.000Z'),
          userId: 'userA',
          transactionType: 'deposit',
          amount: 50,
          transactionNumber: 'TXN-2026-0000001',
          businessCaseId: 'bc-test-1',
          status: 'completed',
          reference: '',
        }),
      ],
      Invoice: [
        row('inv1', {
          createdAt: new Date('2026-01-20T10:00:00.000Z'),
          invoiceNumber: 'INV-2026-0000001',
          invoiceType: 'service_charge',
          userId: 'userA',
          batchId: 'batch1',
          tradeId: '',
          orderId: '',
          businessCaseId: 'bc-inv-2',
          totalAmount: 12.34,
          source: 'backend',
        }),
      ],
    };

    global.Parse.Query = jest.fn((className) => {
      const self = {
        _className: className,
        _eq: {},
        equalTo(field, value) {
          self._eq[field] = value;
          return self;
        },
        find: async () => {
          let list = resultsByClass[className] || [];
          const bc = self._eq.businessCaseId;
          const metaBc = self._eq['metadata.businessCaseId'];
          if (bc) {
            list = list.filter((r) => String(r.get('businessCaseId') || '') === String(bc));
          }
          if (metaBc) {
            list = list.filter((r) => String((r.get('metadata') || {}).businessCaseId || '') === String(metaBc));
          }
          return list;
        },
        greaterThanOrEqualTo: () => self,
        lessThanOrEqualTo: () => self,
        ascending: () => self,
        limit: () => self,
      };
      return self;
    });
  });

  it('returns CSV blocks and dataDictionary for a valid date range', async () => {
    const out = await handleExportAuditorFinancialCsv({
      params: { dateFrom: from, dateTo: to, limitPerSection: 100 },
    });

    expect(out.rowCounts.accountStatement).toBe(1);
    expect(out.rowCounts.appLedgerEntry).toBe(1);
    expect(out.csv.accountStatement).toContain('bc-test-1');
    expect(out.csv.accountStatement).toContain('referenceDocumentNumber');
    expect(out.csv.appLedgerEntry).toContain('wallet:deposit');
    expect(out.dataDictionary.correlationField).toBe('businessCaseId');
    expect(out.parameters.dateFrom).toContain('2026-01-01');
  });

  it('filters by businessCaseId when provided', async () => {
    const out = await handleExportAuditorFinancialCsv({
      params: { dateFrom: from, dateTo: to, businessCaseId: 'bc-test-1', limitPerSection: 100 },
    });

    expect(out.parameters.businessCaseId).toBe('bc-test-1');
    expect(out.csv.invoice).not.toContain('bc-inv-2');
    expect(out.csv.accountStatement).toContain('bc-test-1');
  });

  it('rejects missing date range', async () => {
    await expect(handleExportAuditorFinancialCsv({ params: {} }))
      .rejects.toThrow(/dateFrom/);
  });
});
