'use strict';

const facade = require('../documents');
const { publicSurface, API_TIERS } = require('../documents/publicSurface');

describe('documents public surface contract', () => {
  it('facade exports Tier 1–2 keys only', () => {
    const expected = [
      ...API_TIERS.documentWrites,
      ...API_TIERS.invariantsAndAdmin,
    ].sort();
    expect(Object.keys(facade).sort()).toEqual(expected);
    expect(Object.keys(publicSurface).sort()).toEqual(expected);
  });

  it('has eight document write use-cases', () => {
    expect(API_TIERS.documentWrites).toHaveLength(8);
  });
});
