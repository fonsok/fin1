'use strict';

const { assertNoDuplicateInvestmentSplit } = require('../investmentDuplicateGuard');

function makeParseMock() {
  class ParseError extends Error {
    constructor(code, message) {
      super(message);
      this.code = code;
    }
  }
  ParseError.DUPLICATE_VALUE = 137;
  return { Error: ParseError };
}

describe('assertNoDuplicateInvestmentSplit', () => {
  function makeInvestment(attrs, id = null) {
    return {
      id,
      get(key) {
        return attrs[key];
      },
    };
  }

  test('no-op when required key fields are missing', async () => {
    const ParseMock = {
      ...makeParseMock(),
      Query: jest.fn().mockImplementation(() => {
        throw new Error('Query should not run');
      }),
    };

    await assertNoDuplicateInvestmentSplit(
      makeInvestment({ investorId: 'inv-1', sequenceNumber: 1 }),
      ParseMock
    );
    await assertNoDuplicateInvestmentSplit(
      makeInvestment({ investorId: 'inv-1', batchId: 'batch-1' }),
      ParseMock
    );

    expect(ParseMock.Query).not.toHaveBeenCalled();
  });

  test('allows first split for key (investorId, batchId, sequenceNumber)', async () => {
    const query = {
      equalTo: jest.fn().mockReturnThis(),
      notEqualTo: jest.fn().mockReturnThis(),
      first: jest.fn().mockResolvedValue(null),
    };
    const ParseMock = {
      ...makeParseMock(),
      Query: jest.fn().mockReturnValue(query),
    };

    await assertNoDuplicateInvestmentSplit(
      makeInvestment({
        investorId: 'investor-1',
        batchId: ' batch-42 ',
        sequenceNumber: 2,
      }),
      ParseMock
    );

    expect(query.equalTo).toHaveBeenCalledWith('investorId', 'investor-1');
    expect(query.equalTo).toHaveBeenCalledWith('batchId', 'batch-42');
    expect(query.equalTo).toHaveBeenCalledWith('sequenceNumber', 2);
    expect(query.notEqualTo).not.toHaveBeenCalled();
  });

  test('throws DUPLICATE_VALUE when split already exists', async () => {
    const query = {
      equalTo: jest.fn().mockReturnThis(),
      notEqualTo: jest.fn().mockReturnThis(),
      first: jest.fn().mockResolvedValue({ id: 'existing-id' }),
    };
    const ParseMock = {
      ...makeParseMock(),
      Query: jest.fn().mockReturnValue(query),
    };

    await expect(
      assertNoDuplicateInvestmentSplit(
        makeInvestment(
          {
            investorId: 'investor-1',
            batchId: 'batch-42',
            sequenceNumber: 2,
          },
          'new-id'
        ),
        ParseMock
      )
    ).rejects.toMatchObject({ code: 137 });

    expect(query.notEqualTo).toHaveBeenCalledWith('objectId', 'new-id');
  });
});
