import { describe, it, expect } from 'vitest';
import { resolveConfig, type ConfigResponse } from './configResolve';
import { APP_NAME } from '../../constants/branding';

describe('resolveConfig', () => {
  it('returns numeric and string defaults when data is undefined', () => {
    const config = resolveConfig(undefined);

    expect(config.vatRate).toBe(0.19);
    expect(config.taxCollectionMode).toBe('customer_self_reports');
    expect(config.legalAppName).toBe(APP_NAME);
  });

  it('maps legacy flat appName to legalAppName when config object is empty', () => {
    const config = resolveConfig({
      config: { appName: 'LegacyApp' },
    } as ConfigResponse);

    expect(config.legalAppName).toBe('LegacyApp');
  });
});
