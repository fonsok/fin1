'use strict';

const facade = require('../../tradingSettlementReads');
const { publicSurface, API_TIERS } = require('../publicSurface');

describe('tradingSettlementReads public surface contract', () => {
  it('facade exports four read handlers', () => {
    expect(Object.keys(facade).sort()).toEqual(API_TIERS.readHandlers.sort());
    expect(API_TIERS.readHandlers).toHaveLength(4);
    expect(typeof facade.handleGetAccountStatement).toBe('function');
  });

  it('publicSurface matches facade', () => {
    expect(Object.keys(publicSurface).sort()).toEqual(Object.keys(facade).sort());
  });
});
