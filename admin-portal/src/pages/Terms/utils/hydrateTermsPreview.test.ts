import { describe, it, expect } from 'vitest';
import { hydrateTermsPreviewText } from './hydrateTermsPreview';

describe('hydrateTermsPreviewText', () => {
  it('replaces APP_NAME placeholders (curly + legacy parens)', () => {
    const input = 'Hello {{APP_NAME}} and {(APP_NAME)}';
    expect(hydrateTermsPreviewText(input, { appName: 'GGGGG' })).toBe('Hello GGGGG and GGGGG');
  });

  it('replaces APP_NAME placeholders with whitespace variants', () => {
    const input = 'A {{ APP_NAME }} B {( APP_NAME )} C {{app_name}}';
    expect(hydrateTermsPreviewText(input, { appName: 'GGGGG' })).toBe('A GGGGG B GGGGG C GGGGG');
  });

  it('replaces PRODUCT_NAME alias placeholders', () => {
    const input = '{{PRODUCT_NAME}}';
    expect(hydrateTermsPreviewText(input, { appName: 'GGGGG' })).toBe('GGGGG');
  });

  it('replaces LEGAL_PLATFORM_NAME when provided', () => {
    const input = '{{LEGAL_PLATFORM_NAME}} / {(LEGAL_PLATFORM_NAME)}';
    expect(hydrateTermsPreviewText(input, { appName: 'A', platformName: 'B' })).toBe('B / B');
  });

  it('returns raw input when preview values are missing', () => {
    expect(hydrateTermsPreviewText('{{APP_NAME}}', null)).toBe('{{APP_NAME}}');
  });
});
