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

  it('defaults showCommissionBreakdownInCreditNote to disabled', () => {
    const config = resolveConfig(undefined);
    expect(config.showCommissionBreakdownInCreditNote).toBe(0);
  });

  it('merges display.showCommissionBreakdownInCreditNote from backend response', () => {
    const config = resolveConfig({
      display: { showCommissionBreakdownInCreditNote: false },
    } as ConfigResponse);

    expect(config.showCommissionBreakdownInCreditNote).toBe(false);
  });

  it('defaults showTraderDashboardInvestmentActiveStatus to enabled', () => {
    const config = resolveConfig(undefined);
    expect(config.showTraderDashboardInvestmentActiveStatus).toBe(1);
  });

  it('defaults minTraderBuyOrderAmount to 300', () => {
    const config = resolveConfig(undefined);
    expect(config.minTraderBuyOrderAmount).toBe(300);
  });
});
