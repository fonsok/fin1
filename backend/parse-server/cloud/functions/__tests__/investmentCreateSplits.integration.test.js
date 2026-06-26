'use strict';

/**
 * Integration: createInvestmentSplits + per-investor investmentNumber + batch idempotency.
 *
 * Locks the production regression where a global unique on investmentNumber alone
 * blocked two investors from both receiving INV-YYYY-NNNNNNN sequence 35, and where
 * retries must replay (investorId, batchId, sequenceNumber) without duplicate rows.
 */

jest.mock('../../utils/canonicalUserId', () => ({
  resolveCanonicalUserId: jest.fn(async (id) => String(id || '').trim()),
}));

jest.mock('../../utils/resolveTraderParseUser', () => ({
  resolveTraderParseUser: jest.fn(async () => ({
    id: 'trader-parse-1',
    get(key) {
      if (key === 'username') return 'jbecker';
      return null;
    },
  })),
}));

jest.mock('../../utils/investmentLimitsValidation', () => ({
  validateInvestmentAmountAgainstLimits: jest.fn(async () => ({ valid: true })),
}));

jest.mock('../../utils/poolMirrorBuyCap', () => ({
  validatePoolMirrorReservationCapacity: jest.fn(async () => ({ valid: true })),
}));

jest.mock('../../functions/legal/legalConsentUserSync', () => ({
  resolveUserLegalAcceptanceState: jest.fn(async () => ({
    acceptedTerms: true,
    acceptedPrivacyPolicy: true,
  })),
  resolveUserRoleAgreementState: jest.fn(async () => ({
    required: true,
    accepted: true,
    role: 'investor',
  })),
  resolveRequiredReConsents: jest.fn(async () => ({ required: [] })),
}));

const { resolveCanonicalUserId } = require('../../utils/canonicalUserId');
const { handleCreateInvestmentSplits } = require('../investmentCreateSplits');

const TRADER_ID = 'trader-parse-1';
const INV_YEAR = 2026;

function makeParseError(code, message) {
  const err = new Error(message);
  err.code = code;
  return err;
}

function buildInMemoryParseHarness() {
  /** @type {Array<{ id: string, attrs: Record<string, unknown> }>} */
  const investments = [];
  let idCounter = 0;

  /** Per-investor sequence — both can land on 35 (different compound keys). */
  const invSeqByInvestor = new Map();

  function nextInvestmentNumber(investorId) {
    const prev = invSeqByInvestor.get(investorId) ?? 34;
    const next = prev + 1;
    invSeqByInvestor.set(investorId, next);
    return `INV-${INV_YEAR}-${String(next).padStart(7, '0')}`;
  }

  function compoundTaken(investorId, investmentNumber) {
    return investments.some(
      (row) => row.attrs.investorId === investorId
        && row.attrs.investmentNumber === investmentNumber,
    );
  }

  function matchesFilters(row, filters) {
    return Object.entries(filters).every(([k, v]) => row.attrs[k] === v);
  }

  class FakeQuery {
    constructor(className) {
      this.className = className;
      this.filters = {};
      this._excludeObjectId = null;
    }
    equalTo(field, value) {
      this.filters[field] = value;
      return this;
    }
    notEqualTo(field, value) {
      if (field === 'objectId') this._excludeObjectId = value;
      return this;
    }
    limit() { return this; }
    async first() {
      if (this.className === 'Investment') {
        const hit = investments.find((row) => {
          if (this._excludeObjectId && row.id === this._excludeObjectId) return false;
          return matchesFilters(row, this.filters);
        });
        return hit ? fakeObject(hit) : undefined;
      }
      if (this.className === 'Document') {
        return undefined;
      }
      return undefined;
    }
    async get(objectId) {
      if (this.className !== 'Investment') {
        throw new ParseStub.Error(101, 'Object not found');
      }
      const hit = investments.find((row) => row.id === objectId);
      if (!hit) {
        throw new ParseStub.Error(101, 'Object not found');
      }
      return fakeObject(hit);
    }
  }

  function removeInvestmentRow(rowId) {
    const idx = investments.findIndex((row) => row.id === rowId);
    if (idx >= 0) investments.splice(idx, 1);
  }

  function fakeObject(row) {
    return {
      id: row.id,
      get(key) { return row.attrs[key]; },
      set(key, value) { row.attrs[key] = value; },
      async save() {
        row.attrs = { ...row.attrs };
        return this;
      },
      async destroy() {
        removeInvestmentRow(row.id);
      },
    };
  }

  class FakeInvestment {
    constructor() {
      this.attrs = {};
      this.id = undefined;
      this.existed = () => false;
    }
    set(key, value) { this.attrs[key] = value; }
    get(key) { return this.attrs[key]; }
    async save() {
      const investorId = String(this.attrs.investorId || '').trim();
      const batchId = String(this.attrs.batchId || '').trim();
      const sequenceNumber = Number(this.attrs.sequenceNumber);

      const existingSplit = investments.find(
        (row) => row.attrs.investorId === investorId
          && row.attrs.batchId === batchId
          && row.attrs.sequenceNumber === sequenceNumber,
      );
      if (existingSplit) {
        const dupErr = makeParseError(137, 'duplicate key');
        dupErr.underlyingError = {
          code: 11000,
          keyPattern: { investorId: 1, investmentNumber: 1 },
          keyValue: {
            investorId,
            investmentNumber: existingSplit.attrs.investmentNumber,
          },
        };
        throw dupErr;
      }

      if (!this.attrs.investmentNumber) {
        this.attrs.investmentNumber = nextInvestmentNumber(investorId);
      }

      const invNum = this.attrs.investmentNumber;
      if (compoundTaken(investorId, invNum)) {
        const dupErr = makeParseError(137, 'E11000 duplicate key');
        dupErr.underlyingError = {
          code: 11000,
          keyPattern: { investorId: 1, investmentNumber: 1 },
          keyValue: { investorId, investmentNumber: invNum },
        };
        throw dupErr;
      }

      idCounter += 1;
      this.id = `inv-${idCounter}`;
      investments.push({ id: this.id, attrs: { ...this.attrs } });
      return this;
    }
  }

  const ParseStub = {
    Error: class ParseError extends Error {
      constructor(code, message) {
        super(message);
        this.code = code;
      }
    },
    Query: FakeQuery,
    Object: {
      destroyAll() {
        return Promise.resolve();
      },
      extend(className) {
        if (className !== 'Investment') {
          throw new Error(`unexpected class ${className}`);
        }
        return FakeInvestment;
      },
    },
  };
  ParseStub.Error.INVALID_SESSION_TOKEN = 209;
  ParseStub.Error.INVALID_VALUE = 102;
  ParseStub.Error.OBJECT_NOT_FOUND = 101;
  ParseStub.Error.DUPLICATE_VALUE = 137;
  ParseStub.Error.OPERATION_FORBIDDEN = 119;

  return { ParseStub, investments, nextInvestmentNumber, invSeqByInvestor };
}

function makeRequest(user, params) {
  return { user, params };
}

function makeSessionUser(id) {
  return {
    id,
    get(key) {
      if (key === 'onboardingCompleted') return true;
      return null;
    },
  };
}

describe('createInvestmentSplits (integration)', () => {
  let harness;

  beforeEach(() => {
    jest.clearAllMocks();
    harness = buildInMemoryParseHarness();
    global.Parse = harness.ParseStub;
    resolveCanonicalUserId.mockImplementation(async (id) => String(id || '').trim());
  });

  afterEach(() => {
    delete global.Parse;
  });

  test('two investors can both receive the same INV sequence number (compound unique)', async () => {
    const investorA = 'investor-smuller';
    const investorB = 'investor-dbraun';
    const userA = makeSessionUser('session-a');
    const userB = makeSessionUser('session-b');

    resolveCanonicalUserId.mockImplementation(async (id) => {
      if (id === 'session-a') return investorA;
      if (id === 'session-b') return investorB;
      return String(id || '').trim();
    });

    const batchA = 'batch-a-001';
    const batchB = 'batch-b-001';
    const sharedNumber = `INV-${INV_YEAR}-0000035`;

    harness.invSeqByInvestor.set(investorA, 34);
    harness.invSeqByInvestor.set(investorB, 34);

    const resA = await handleCreateInvestmentSplits(makeRequest(userA, {
      batchId: batchA,
      traderId: TRADER_ID,
      splits: [{ sequenceNumber: 1, amount: 10_000 }],
    }));
    const resB = await handleCreateInvestmentSplits(makeRequest(userB, {
      batchId: batchB,
      traderId: TRADER_ID,
      splits: [{ sequenceNumber: 1, amount: 5_000 }],
    }));

    expect(resA.splits).toHaveLength(1);
    expect(resB.splits).toHaveLength(1);
    expect(resA.splits[0].investmentNumber).toBe(sharedNumber);
    expect(resB.splits[0].investmentNumber).toBe(sharedNumber);
    expect(resA.splits[0].idempotentReplay).toBe(false);
    expect(resA.batchStatus).toBe('committed');
    expect(resA.splits[0].status).toBe('created');
    expect(harness.investments[0].attrs.traderUsername).toBeTruthy();
    expect(resB.splits[0].idempotentReplay).toBe(false);
    expect(resB.batchStatus).toBe('committed');
    expect(resB.splits[0].status).toBe('created');

    expect(harness.investments).toHaveLength(2);
    const numbers = harness.investments.map((r) => r.attrs.investmentNumber);
    expect(numbers).toEqual([sharedNumber, sharedNumber]);
    const investorIds = harness.investments.map((r) => r.attrs.investorId);
    expect(new Set(investorIds).size).toBe(2);
  });

  test('retrying the same batch returns idempotentReplay without extra rows', async () => {
    const investorId = 'investor-retry';
    const user = makeSessionUser('session-retry');
    resolveCanonicalUserId.mockImplementation(async (id) => (
      id === 'session-retry' ? investorId : String(id || '').trim()
    ));

    const batchId = 'batch-retry-42';
    const params = {
      batchId,
      traderId: TRADER_ID,
      splits: [
        { sequenceNumber: 1, amount: 1_000 },
        { sequenceNumber: 2, amount: 2_000 },
      ],
    };

    const first = await handleCreateInvestmentSplits(makeRequest(user, params));
    expect(first.batchStatus).toBe('committed');
    expect(first.splits.every((s) => s.idempotentReplay === false)).toBe(true);
    expect(harness.investments).toHaveLength(2);

    const second = await handleCreateInvestmentSplits(makeRequest(user, params));
    expect(second.batchStatus).toBe('replayed');
    expect(second.splits).toHaveLength(2);
    expect(second.splits.every((s) => s.idempotentReplay === true)).toBe(true);
    expect(second.splits.every((s) => s.status === 'replayed')).toBe(true);
    expect(second.splits.map((s) => s.investmentId)).toEqual(first.splits.map((s) => s.investmentId));
    expect(harness.investments).toHaveLength(2);
  });

  test('duplicate save race replays existing split when amounts match', async () => {
    const investorId = 'investor-race';
    const user = makeSessionUser('session-race');
    resolveCanonicalUserId.mockImplementation(async (id) => (
      id === 'session-race' ? investorId : String(id || '').trim()
    ));

    const batchId = 'batch-race-1';
    const amount = 3_000;
    const invNum = `INV-${INV_YEAR}-0000099`;

    const InvestmentClass = harness.ParseStub.Object.extend('Investment');
    const baseSave = InvestmentClass.prototype.save;
    InvestmentClass.prototype.save = async function raceSave() {
      if (!this.attrs.investmentNumber) {
        this.attrs.investmentNumber = invNum;
      }
      harness.investments.push({
        id: 'inv-race-inserted',
        attrs: { ...this.attrs },
      });
      const dupErr = makeParseError(137, 'E11000 duplicate key');
      dupErr.underlyingError = {
        code: 11000,
        keyPattern: { investmentNumber: 1 },
        keyValue: { investmentNumber: invNum },
      };
      throw dupErr;
    };

    try {
      const result = await handleCreateInvestmentSplits(makeRequest(user, {
        batchId,
        traderId: TRADER_ID,
        splits: [{ sequenceNumber: 1, amount }],
      }));

      expect(result.splits).toHaveLength(1);
      expect(result.splits[0].idempotentReplay).toBe(true);
      expect(result.splits[0].investmentId).toBe('inv-race-inserted');
      expect(harness.investments).toHaveLength(1);
    } finally {
      InvestmentClass.prototype.save = baseSave;
    }
  });

  test('rolls back earlier splits when a later split save fails (atomic batch)', async () => {
    const investorId = 'investor-atomic';
    const user = makeSessionUser('session-atomic');
    resolveCanonicalUserId.mockImplementation(async (id) => (
      id === 'session-atomic' ? investorId : String(id || '').trim()
    ));

    const batchId = 'batch-atomic-fail';
    const InvestmentClass = harness.ParseStub.Object.extend('Investment');
    const baseSave = InvestmentClass.prototype.save;
    let newSaveCount = 0;

    InvestmentClass.prototype.save = async function atomicFailSave() {
      newSaveCount += 1;
      if (newSaveCount >= 2) {
        throw makeParseError(119, 'simulated reserve failure');
      }
      return baseSave.call(this);
    };

    try {
      await expect(handleCreateInvestmentSplits(makeRequest(user, {
        batchId,
        traderId: TRADER_ID,
        splits: [
          { sequenceNumber: 1, amount: 1_000 },
          { sequenceNumber: 2, amount: 2_000 },
        ],
      }))).rejects.toMatchObject({ code: 119 });

      expect(harness.investments.filter((r) => r.attrs.batchId === batchId)).toHaveLength(0);
    } finally {
      InvestmentClass.prototype.save = baseSave;
    }
  });
});
