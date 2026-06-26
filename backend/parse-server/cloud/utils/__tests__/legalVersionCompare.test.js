'use strict';

const {
  compareLegalVersions,
  isLegalVersionOutdated,
} = require('../legalVersionCompare');

describe('legalVersionCompare', () => {
  test('compareLegalVersions orders dotted versions numerically', () => {
    expect(compareLegalVersions('1.0', '2.0')).toBe(-1);
    expect(compareLegalVersions('2.0', '1.0')).toBe(1);
    expect(compareLegalVersions('1.0.2', '1.0.10')).toBe(-1);
    expect(compareLegalVersions('1.0', '1.0')).toBe(0);
  });

  test('isLegalVersionOutdated requires stored version and active target', () => {
    expect(isLegalVersionOutdated('1.0', '2.0')).toBe(true);
    expect(isLegalVersionOutdated('2.0', '1.0')).toBe(false);
    expect(isLegalVersionOutdated('', '2.0')).toBe(false);
    expect(isLegalVersionOutdated('1.0', '')).toBe(false);
  });
});
