'use strict';

/**
 * Partial sells: one sell invoice per sell order (not one per trade).
 * Logic mirror — full trigger needs Parse global.
 */

describe('orderInvoice partial sell policy', () => {
  test('sell invoices are not deduplicated by tradeId alone', () => {
    const source = require('fs').readFileSync(
      require('path').join(__dirname, '../orderInvoice.js'),
      'utf8',
    );
    expect(source).toContain('if (linkedTradeId && !isSell)');
    expect(source).toContain('underlyingAsset,');
    expect(source).toMatch(/itemType:\s*'securities'/);
  });
});
