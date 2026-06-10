'use strict';

const facade = require('../repair');
const { repairTradeSettlement } = require('../repair/repairTradeSettlement');
const { publicSurface, API_TIERS } = require('../repair/publicSurface');

describe('repair public surface contract', () => {
  it('facade exports only repairTradeSettlement', () => {
    expect(Object.keys(facade)).toEqual(['repairTradeSettlement']);
    expect(facade.repairTradeSettlement).toBe(repairTradeSettlement);
    expect(Object.keys(publicSurface)).toEqual(API_TIERS.repairUseCase);
  });

  it('repairTradeSettlement rejects missing tradeId', async () => {
    class ParseError extends Error {
      constructor(code, message) {
        super(message);
        this.code = code;
      }
    }
    ParseError.INVALID_QUERY = 102;
    global.Parse = { Error: ParseError };
    await expect(repairTradeSettlement(null, { dryRun: true })).rejects.toMatchObject({
      message: 'tradeId required',
      code: 102,
    });
  });
});
