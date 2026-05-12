'use strict';

const { assertNoDuplicateServiceChargeBatch } = require('../invoiceDuplicateGuard');

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

describe('assertNoDuplicateServiceChargeBatch', () => {
  function makeInvoice(attrs, id = null) {
    return {
      id,
      get(key) {
        return attrs[key];
      },
    };
  }

  test('no-op for unrelated invoice types', async () => {
    const ParseMock = {
      ...makeParseMock(),
      Query: jest.fn().mockImplementation(() => {
        throw new Error('Query should not run');
      }),
    };
    await assertNoDuplicateServiceChargeBatch(
      makeInvoice({ invoiceType: 'trade_fee', batchId: 'b1' }),
      ParseMock
    );
    expect(ParseMock.Query).not.toHaveBeenCalled();
  });

  test('no-op when batchId is missing', async () => {
    const ParseMock = {
      ...makeParseMock(),
      Query: jest.fn(),
    };
    await assertNoDuplicateServiceChargeBatch(
      makeInvoice({ invoiceType: 'service_charge' }),
      ParseMock
    );
    expect(ParseMock.Query).not.toHaveBeenCalled();
  });

  test('allows first service_charge for a batch', async () => {
    const query = {
      containedIn: jest.fn().mockReturnThis(),
      equalTo: jest.fn().mockReturnThis(),
      notEqualTo: jest.fn().mockReturnThis(),
      first: jest.fn().mockResolvedValue(null),
    };
    const ParseMock = {
      ...makeParseMock(),
      Query: jest.fn().mockReturnValue(query),
    };
    await assertNoDuplicateServiceChargeBatch(
      makeInvoice({
        invoiceType: 'service_charge',
        batchId: '  batch-abc  ',
      }),
      ParseMock
    );
    expect(query.containedIn).toHaveBeenCalledWith(
      'invoiceType',
      expect.arrayContaining(['service_charge', 'app_service_charge', 'platform_service_charge'])
    );
    expect(query.equalTo).toHaveBeenCalledWith('batchId', 'batch-abc');
    expect(query.notEqualTo).not.toHaveBeenCalled();
  });

  test('throws DUPLICATE_VALUE when another row exists', async () => {
    const query = {
      containedIn: jest.fn().mockReturnThis(),
      equalTo: jest.fn().mockReturnThis(),
      notEqualTo: jest.fn().mockReturnThis(),
      first: jest.fn().mockResolvedValue({ id: 'existing' }),
    };
    const ParseMock = {
      ...makeParseMock(),
      Query: jest.fn().mockReturnValue(query),
    };
    await expect(
      assertNoDuplicateServiceChargeBatch(
        makeInvoice({ invoiceType: 'service_charge', batchId: 'x' }, 'new-id'),
        ParseMock
      )
    ).rejects.toMatchObject({ code: 137 });
    expect(query.notEqualTo).toHaveBeenCalledWith('objectId', 'new-id');
  });

  test('legacy platform_service_charge uses same guard (family query)', async () => {
    const query = {
      containedIn: jest.fn().mockReturnThis(),
      equalTo: jest.fn().mockReturnThis(),
      notEqualTo: jest.fn().mockReturnThis(),
      first: jest.fn().mockResolvedValue({ id: 'dup' }),
    };
    const ParseMock = {
      ...makeParseMock(),
      Query: jest.fn().mockReturnValue(query),
    };
    await expect(
      assertNoDuplicateServiceChargeBatch(
        makeInvoice({ invoiceType: 'platform_service_charge', batchId: 'y' }),
        ParseMock
      )
    ).rejects.toMatchObject({ code: 137 });
    expect(query.containedIn).toHaveBeenCalledWith(
      'invoiceType',
      expect.arrayContaining(['platform_service_charge'])
    );
  });

  test('app_service_charge is guarded like service_charge', async () => {
    const query = {
      containedIn: jest.fn().mockReturnThis(),
      equalTo: jest.fn().mockReturnThis(),
      notEqualTo: jest.fn().mockReturnThis(),
      first: jest.fn().mockResolvedValue(null),
    };
    const ParseMock = {
      ...makeParseMock(),
      Query: jest.fn().mockReturnValue(query),
    };
    await assertNoDuplicateServiceChargeBatch(
      makeInvoice({ invoiceType: 'app_service_charge', batchId: 'z' }),
      ParseMock
    );
    expect(query.containedIn).toHaveBeenCalled();
    expect(query.equalTo).toHaveBeenCalledWith('batchId', 'z');
  });
});
