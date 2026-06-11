import { CONFIG_DEFAULT_VALUES } from './configResolve';

export const COMMISSION_RATE_PARAMETER_KEYS = [
  'investorCommissionRateTotal',
  'traderCommissionRate',
  'appCommissionRate',
] as const;

export const COMMISSION_RATE_BUNDLE_PARAMETER_NAME = 'commissionRateBundle';

export const COMMISSION_RATE_BUNDLE_DISPLAY_NAME = 'Erfolgsprovision App + Trader';

export const COMMISSION_RATE_BUNDLE_DESCRIPTION =
  'Gesamtprovision für Investoren (Collection Bill „Commission“) mit Aufteilung Trader / App. '
  + 'Summe muss exakt gelten: Trader + App = Gesamt.';

export type CommissionSplitPresetId =
  | 'equal_50_50'
  | 'trader_60'
  | 'trader_40'
  | 'trader_only'
  | 'app_only'
  | 'custom';

export interface CommissionRates {
  investorCommissionRateTotal: number;
  traderCommissionRate: number;
  appCommissionRate: number;
}

export interface CommissionSplitPreset {
  id: CommissionSplitPresetId;
  label: string;
  traderShareOfTotal: number;
}

export const COMMISSION_SPLIT_PRESETS: CommissionSplitPreset[] = [
  { id: 'equal_50_50', label: '50 % Trader / 50 % App', traderShareOfTotal: 0.5 },
  { id: 'trader_60', label: '60 % Trader / 40 % App', traderShareOfTotal: 0.6 },
  { id: 'trader_40', label: '40 % Trader / 60 % App', traderShareOfTotal: 0.4 },
  { id: 'trader_only', label: '100 % Trader / 0 % App', traderShareOfTotal: 1 },
  { id: 'app_only', label: '0 % Trader / 100 % App', traderShareOfTotal: 0 },
  { id: 'custom', label: 'Benutzerdefiniert', traderShareOfTotal: Number.NaN },
];

export function roundRate(n: number): number {
  return Math.round(Number(n) * 10000) / 10000;
}

export function computeRatesFromPreset(total: number, traderShare: number): CommissionRates {
  const normalizedTotal = roundRate(total);
  const trader = roundRate(normalizedTotal * traderShare);
  const app = roundRate(normalizedTotal - trader);
  return {
    investorCommissionRateTotal: normalizedTotal,
    traderCommissionRate: trader,
    appCommissionRate: app,
  };
}

export function readCommissionRatesFromConfig(
  config: Record<string, number | string | boolean>,
): CommissionRates {
  return {
    investorCommissionRateTotal: roundRate(
      Number(config.investorCommissionRateTotal ?? CONFIG_DEFAULT_VALUES.investorCommissionRateTotal),
    ),
    traderCommissionRate: roundRate(
      Number(config.traderCommissionRate ?? CONFIG_DEFAULT_VALUES.traderCommissionRate),
    ),
    appCommissionRate: roundRate(
      Number(config.appCommissionRate ?? CONFIG_DEFAULT_VALUES.appCommissionRate),
    ),
  };
}

export function detectPresetFromRates(rates: CommissionRates): CommissionSplitPresetId {
  const { investorCommissionRateTotal: total, traderCommissionRate: trader, appCommissionRate: app } = rates;
  if (total <= 0) {
    return 'equal_50_50';
  }

  for (const preset of COMMISSION_SPLIT_PRESETS) {
    if (preset.id === 'custom') {
      continue;
    }
    const expected = computeRatesFromPreset(total, preset.traderShareOfTotal);
    if (
      expected.traderCommissionRate === roundRate(trader)
      && expected.appCommissionRate === roundRate(app)
    ) {
      return preset.id;
    }
  }
  return 'custom';
}

export function ratesAreEqual(a: CommissionRates, b: CommissionRates): boolean {
  return (
    roundRate(a.investorCommissionRateTotal) === roundRate(b.investorCommissionRateTotal)
    && roundRate(a.traderCommissionRate) === roundRate(b.traderCommissionRate)
    && roundRate(a.appCommissionRate) === roundRate(b.appCommissionRate)
  );
}

export function validateCommissionRates(rates: CommissionRates): string | null {
  if (rates.investorCommissionRateTotal < 0 || rates.investorCommissionRateTotal > 1) {
    return 'Gesamtprovision muss zwischen 0 % und 100 % liegen.';
  }
  if (rates.traderCommissionRate < 0 || rates.traderCommissionRate > 1) {
    return 'Trader-Provision muss zwischen 0 % und 100 % liegen.';
  }
  if (rates.appCommissionRate < 0 || rates.appCommissionRate > 1) {
    return 'App-Erfolgsprovision muss zwischen 0 % und 100 % liegen.';
  }
  const sum = roundRate(rates.traderCommissionRate + rates.appCommissionRate);
  const target = roundRate(rates.investorCommissionRateTotal);
  if (sum !== target) {
    return `Summe muss exakt der Gesamtprovision entsprechen (aktuell ${(sum * 100).toFixed(2)} % ≠ ${(target * 100).toFixed(2)} %).`;
  }
  return null;
}

export function formatCommissionRatesSummary(rates: CommissionRates): string {
  const pct = (rate: number) =>
    `${(roundRate(rate) * 100).toFixed(1).replace(/\.0$/, '')} %`;
  return `${pct(rates.investorCommissionRateTotal)} gesamt — Trader ${pct(rates.traderCommissionRate)} · App ${pct(rates.appCommissionRate)}`;
}

export function formatSplitPresetLabel(preset: CommissionSplitPreset, total: number): string {
  if (preset.id === 'custom') {
    return preset.label;
  }
  const rates = computeRatesFromPreset(total, preset.traderShareOfTotal);
  const pct = (rate: number) =>
    `${(roundRate(rate) * 100).toFixed(1).replace(/\.0$/, '')} %`;
  return `${preset.label} (${pct(rates.traderCommissionRate)} + ${pct(rates.appCommissionRate)})`;
}
