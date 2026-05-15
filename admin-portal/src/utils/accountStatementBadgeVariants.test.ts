import { describe, expect, it } from 'vitest';
import { accountStatementEntryChipClasses } from './accountStatementBadgeVariants';

describe('accountStatementEntryChipClasses', () => {
  it('maps trade_buy and trade_sell to different hues', () => {
    const buy = accountStatementEntryChipClasses('trade_buy', true);
    const sell = accountStatementEntryChipClasses('trade_sell', true);
    expect(buy).toContain('blue');
    expect(sell).toContain('violet');
    expect(buy).not.toEqual(sell);
  });
});
