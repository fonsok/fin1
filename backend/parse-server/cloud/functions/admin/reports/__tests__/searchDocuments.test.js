'use strict';

jest.mock('../../../../utils/permissions', () => ({
  requirePermission: jest.fn(),
}));

const {
  handleSearchDocuments,
  handleGetDocumentByObjectId,
  handleGetDocumentByLedgerReference,
  serializeParseDateValue,
  documentTimestampRaw,
} = require('../searchDocuments');

function mockParse() {
  global.Parse = global.Parse || {};
  if (!global.Parse.Error) {
    global.Parse.Error = class ParseError extends Error {
      constructor(code, message) {
        super(message);
        this.code = code;
      }
      static get INVALID_QUERY() { return 102; }
    };
  }
}

class FakeQuery {
  constructor(className) {
    this.className = className;
    this.constraints = { equalTo: {}, containedIn: {}, matches: [] };
    this.dateConstraints = {};
    this.selectFields = null;
    this.skipValue = 0;
    this.limitValue = 100;
    this.sort = null;
  }

  equalTo(field, value) {
    this.constraints.equalTo[field] = value;
    return this;
  }

  containedIn(field, values) {
    this.constraints.containedIn[field] = values;
    return this;
  }

  matches(field, regex, modifier) {
    this.constraints.matches.push({ field, regex, modifier });
    return this;
  }

  greaterThanOrEqualTo(field, value) {
    this.dateConstraints[`${field}>=`] = value;
    return this;
  }

  lessThanOrEqualTo(field, value) {
    this.dateConstraints[`${field}<=`] = value;
    return this;
  }

  ascending(field) { this.sort = { field, dir: 'asc' }; return this; }
  descending(field) { this.sort = { field, dir: 'desc' }; return this; }

  select(fields) { this.selectFields = fields; return this; }
  skip(n) { this.skipValue = n; return this; }
  limit(n) { this.limitValue = n; return this; }

  async find() {
    return FakeQuery.__results.slice(this.skipValue, this.skipValue + this.limitValue);
  }

  async count() {
    return FakeQuery.__results.length;
  }

  async get(objectId) {
    const found = FakeQuery.__results.find((r) => r.id === objectId);
    if (!found) {
      throw new Error('not found');
    }
    return found;
  }
}

FakeQuery.__results = [];
FakeQuery.or = function or(...queries) {
  // Behaviour-equivalent stand-in: return a fresh Document query so AND can chain on top.
  return new FakeQuery(queries[0]?.className || 'Document');
};
FakeQuery.and = function and(...queries) {
  return new FakeQuery(queries[0]?.className || 'Document');
};

function row(id, attrs) {
  const createdAt = attrs.createdAt ?? attrs.uploadedAt ?? null;
  return {
    id,
    createdAt,
    get(k) {
      if (k === 'createdAt') return createdAt;
      return attrs[k];
    },
  };
}

describe('searchDocuments', () => {
  const filteredParams = {
    limit: 25,
    type: ['investorCollectionBill', 'investmentReservationEigenbeleg'],
  };

  beforeEach(() => {
    mockParse();
    global.Parse.Query = FakeQuery;

    FakeQuery.__results = [
      row('doc-cb-1', {
        userId: 'inv-1',
        name: 'CollectionBill_1.pdf',
        type: 'investorCollectionBill',
        status: 'verified',
        fileURL: 'parse://abc.pdf',
        size: 12_345,
        uploadedAt: new Date('2026-04-01T10:00:00Z'),
        verifiedAt: new Date('2026-04-01T10:00:01Z'),
        documentNumber: 'CB-2026-0000001',
        accountingDocumentNumber: 'CB-2026-0000001',
        tradeId: 'tr-1',
        investmentId: 'inv-obj-1',
      }),
      row('doc-eb-1', {
        userId: 'inv-2',
        name: 'Eigenbeleg_Reservierung_001.pdf',
        type: 'investmentReservationEigenbeleg',
        status: 'verified',
        fileURL: 'eigenbeleg-reservierung://EBR-1.pdf',
        size: 4_096,
        uploadedAt: new Date('2026-04-02T10:00:00Z'),
        verifiedAt: new Date('2026-04-02T10:00:01Z'),
        documentNumber: 'EBR-2026-0000001',
        accountingDocumentNumber: 'EBR-2026-0000001',
        investmentId: 'inv-obj-2',
        accountingSummaryText: 'GoB Eigenbeleg ...',
      }),
    ];
  });

  test('returns paginated rows with hasMore=false when below limit', async () => {
    const out = await handleSearchDocuments({ params: filteredParams });
    expect(out.items).toHaveLength(2);
    expect(out.hasMore).toBe(false);
    expect(out.limit).toBe(25);
    expect(out.skip).toBe(0);
    expect(out.items[0].partyRole).toBe('investor');
    expect(out.items[0].partyLabel).toBe('Investor');
    expect(out.items[0].partyUserId).toBe('inv-1');
  });

  test('clamps limit to max', async () => {
    const out = await handleSearchDocuments({ params: { ...filteredParams, limit: 9999 } });
    expect(out.limit).toBe(100);
  });

  test('rejects query without any search predicate', async () => {
    await expect(handleSearchDocuments({ params: { limit: 25 } })).rejects.toThrow('mindestens ein Filter');
  });

  test('does not return accountingSummaryText in list payload', async () => {
    const out = await handleSearchDocuments({ params: filteredParams });
    expect(out.items[1]).not.toHaveProperty('accountingSummaryText');
  });

  test('getDocumentByObjectId returns full payload incl. accountingSummaryText', async () => {
    const out = await handleGetDocumentByObjectId({ params: { objectId: 'doc-eb-1' } });
    expect(out.objectId).toBe('doc-eb-1');
    expect(out.type).toBe('investmentReservationEigenbeleg');
    expect(out.accountingSummaryText).toContain('GoB');
  });

  test('getDocumentByObjectId rejects when objectId is missing', async () => {
    await expect(handleGetDocumentByObjectId({ params: {} })).rejects.toThrow('objectId required');
  });

  test('getDocumentByObjectId tolerates string uploadedAt and falls back to createdAt', async () => {
    FakeQuery.__results = [
      row('tbc-33', {
        userId: 'trader-1',
        name: 'Kaufabrechnung_Trade33.pdf',
        type: 'traderCollectionBill',
        status: 'verified',
        fileURL: 'parse://tbc.pdf',
        size: 900,
        uploadedAt: '2026-05-15T12:00:00.000Z',
        createdAt: new Date('2026-05-15T12:00:00.000Z'),
        accountingDocumentNumber: 'TBC-2026-0000033',
        tradeId: 'trade-33',
        accountingSummaryText: 'Kaufabrechnung Trade #33',
      }),
    ];
    const out = await handleGetDocumentByObjectId({ params: { objectId: 'tbc-33' } });
    expect(out.uploadedAt).toBe('2026-05-15T12:00:00.000Z');
    expect(out.accountingDocumentNumber).toBe('TBC-2026-0000033');
    expect(out.partyRole).toBe('trader');
    expect(out.traderId).toBe('trader-1');
    expect(out.partyUserId).toBe('trader-1');
  });

  test('getDocumentByObjectId uses createdAt when backend bill has no uploadedAt', async () => {
    FakeQuery.__results = [
      row('tbc-no-up', {
        userId: 'trader-1',
        name: 'Kaufabrechnung_Trade34.pdf',
        type: 'traderCollectionBill',
        status: '',
        fileURL: '',
        size: 512,
        createdAt: new Date('2026-05-16T08:30:00.000Z'),
        accountingDocumentNumber: 'TBC-2026-0000034',
        tradeId: 'trade-34',
      }),
    ];
    const doc = FakeQuery.__results[0];
    expect(documentTimestampRaw(doc)).toEqual(new Date('2026-05-16T08:30:00.000Z'));
    const out = await handleGetDocumentByObjectId({ params: { objectId: 'tbc-no-up' } });
    expect(out.uploadedAt).toBe('2026-05-16T08:30:00.000Z');
  });
});

describe('serializeParseDateValue', () => {
  test('accepts Date, ISO string, and Parse date dict', () => {
    expect(serializeParseDateValue(new Date('2026-01-02T03:04:05.000Z'))).toBe('2026-01-02T03:04:05.000Z');
    expect(serializeParseDateValue('2026-01-02T03:04:05.000Z')).toBe('2026-01-02T03:04:05.000Z');
    expect(serializeParseDateValue({ __type: 'Date', iso: '2026-01-02T03:04:05.000Z' }))
      .toBe('2026-01-02T03:04:05.000Z');
    expect(serializeParseDateValue(null)).toBeNull();
  });
});

/** FakeQuery.find ignores equalTo; ledger lookup uses sequential equalTo queries — narrow Query mock. */
class LedgerExactNumberQuery extends FakeQuery {
  async find() {
    const eq = this.constraints.equalTo || {};
    if (eq.accountingDocumentNumber) {
      const want = String(eq.accountingDocumentNumber);
      const hit = FakeQuery.__results.filter(
        (r) => String(r.get('accountingDocumentNumber') || '') === want,
      );
      return hit.slice(0, this.limitValue);
    }
    if (eq.documentNumber) {
      const want = String(eq.documentNumber);
      const hit = FakeQuery.__results.filter(
        (r) => String(r.get('documentNumber') || '') === want,
      );
      return hit.slice(0, this.limitValue);
    }
    return super.find();
  }
}

describe('getDocumentByLedgerReference', () => {
  beforeEach(() => {
    mockParse();
    global.Parse.Query = LedgerExactNumberQuery;
    FakeQuery.__results = [
      row('doc-cb-1', {
        userId: 'inv-1',
        name: 'CollectionBill_1.pdf',
        type: 'investorCollectionBill',
        status: 'verified',
        fileURL: 'parse://abc.pdf',
        size: 12_345,
        uploadedAt: new Date('2026-04-01T10:00:00Z'),
        verifiedAt: new Date('2026-04-01T10:00:01Z'),
        documentNumber: 'CB-2026-0000001',
        accountingDocumentNumber: 'CB-2026-0000001',
        tradeId: 'tr-1',
        investmentId: 'inv-obj-1',
      }),
      row('doc-eb-1', {
        userId: 'inv-2',
        name: 'Eigenbeleg_Reservierung_001.pdf',
        type: 'investmentReservationEigenbeleg',
        status: 'verified',
        fileURL: 'eigenbeleg-reservierung://EBR-1.pdf',
        size: 4_096,
        uploadedAt: new Date('2026-04-02T10:00:00Z'),
        verifiedAt: new Date('2026-04-02T10:00:01Z'),
        documentNumber: 'EBR-2026-0000001',
        accountingDocumentNumber: 'EBR-2026-0000001',
        investmentId: 'inv-obj-2',
        accountingSummaryText: 'GoB Eigenbeleg ...',
      }),
    ];
  });

  test('rejects when neither objectId nor number', async () => {
    await expect(handleGetDocumentByLedgerReference({ params: {} })).rejects.toThrow(
      'objectId oder referenceDocumentNumber',
    );
  });

  test('resolves by referenceDocumentNumber (accountingDocumentNumber match)', async () => {
    const out = await handleGetDocumentByLedgerReference({
      params: { referenceDocumentNumber: 'EBR-2026-0000001' },
    });
    expect(out.objectId).toBe('doc-eb-1');
    expect(out.accountingSummaryText).toContain('GoB');
  });

  test('delegates to objectId path when valid objectId passed', async () => {
    const out = await handleGetDocumentByLedgerReference({ params: { objectId: 'doc-eb-1' } });
    expect(out.objectId).toBe('doc-eb-1');
  });

  test('throws OBJECT_NOT_FOUND when number unknown', async () => {
    await expect(
      handleGetDocumentByLedgerReference({ params: { referenceDocumentNumber: 'MISSING-999' } }),
    ).rejects.toThrow('kein Beleg zu Nummer');
  });
});
