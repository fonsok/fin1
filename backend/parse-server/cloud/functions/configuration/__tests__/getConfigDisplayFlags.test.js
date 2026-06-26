'use strict';

const { mergeShowCommissionBreakdownInCreditNote } = require('../getConfigDisplayFlags');

describe('mergeShowCommissionBreakdownInCreditNote', () => {
  test('prefers live Configuration (admin portal) over legacy Config.display', () => {
    expect(
      mergeShowCommissionBreakdownInCreditNote(
        { showCommissionBreakdownInCreditNote: false },
        { showCommissionBreakdownInCreditNote: true },
      ),
    ).toBe(true);
  });

  test('falls back to legacy Config.display when live value is missing', () => {
    expect(
      mergeShowCommissionBreakdownInCreditNote(
        { showCommissionBreakdownInCreditNote: true },
        {},
      ),
    ).toBe(true);
  });

  test('defaults to false when neither source provides a boolean', () => {
    expect(mergeShowCommissionBreakdownInCreditNote({}, {})).toBe(false);
    expect(mergeShowCommissionBreakdownInCreditNote(undefined, undefined)).toBe(false);
  });
});
