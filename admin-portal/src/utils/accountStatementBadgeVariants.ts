import clsx from 'clsx';
import { CHIP_BASE, CHIP_SIZE_SM, chipAccentClasses, type ChipAccent } from './chipVariants';

export const STATEMENT_CHIP_BASE = clsx(CHIP_BASE, CHIP_SIZE_SM);

const ENTRY_CHIP_DARK: Record<string, string> = {
  deposit: 'bg-emerald-500/20 text-emerald-100 border-emerald-400/70',
  withdrawal: 'bg-red-500/20 text-red-100 border-red-400/70',
  investment_activate: 'bg-amber-500/20 text-amber-100 border-amber-400/70',
  investment_return: 'bg-green-500/20 text-green-100 border-green-400/70',
  investment_refund: 'bg-teal-500/20 text-teal-100 border-teal-400/70',
  investment_profit: 'bg-emerald-500/20 text-emerald-100 border-emerald-400/70',
  commission_debit: 'bg-rose-500/20 text-rose-100 border-rose-400/70',
  commission_credit: 'bg-green-500/20 text-green-100 border-green-400/70',
  residual_return: 'bg-cyan-500/20 text-cyan-100 border-cyan-400/70',
  trade_buy: 'bg-blue-500/20 text-blue-100 border-blue-400/70',
  trade_sell: 'bg-violet-500/20 text-violet-100 border-violet-400/70',
  trading_fees: 'bg-orange-500/20 text-orange-100 border-orange-400/70',
  app_service_charge: 'bg-red-500/20 text-red-100 border-red-400/70',
  investment_escrow_reserve: 'bg-amber-500/20 text-amber-100 border-amber-400/70',
  investment_escrow_deploy: 'bg-orange-500/20 text-orange-100 border-orange-400/70',
  investment_escrow_release: 'bg-sky-500/20 text-sky-100 border-sky-400/70',
};

const ENTRY_CHIP_LIGHT: Record<string, string> = {
  deposit: 'bg-emerald-100 text-emerald-800 border-emerald-400/70',
  withdrawal: 'bg-red-100 text-red-800 border-red-400/70',
  investment_activate: 'bg-amber-100 text-amber-800 border-amber-400/70',
  investment_return: 'bg-green-100 text-green-800 border-green-400/70',
  investment_refund: 'bg-teal-100 text-teal-800 border-teal-400/70',
  investment_profit: 'bg-emerald-100 text-emerald-800 border-emerald-400/70',
  commission_debit: 'bg-rose-100 text-rose-800 border-rose-400/70',
  commission_credit: 'bg-green-100 text-green-800 border-green-400/70',
  residual_return: 'bg-cyan-100 text-cyan-800 border-cyan-400/70',
  trade_buy: 'bg-blue-100 text-blue-800 border-blue-400/70',
  trade_sell: 'bg-violet-100 text-violet-800 border-violet-400/70',
  trading_fees: 'bg-orange-100 text-orange-800 border-orange-400/70',
  app_service_charge: 'bg-red-100 text-red-800 border-red-400/70',
  investment_escrow_reserve: 'bg-amber-100 text-amber-800 border-amber-400/70',
  investment_escrow_deploy: 'bg-orange-100 text-orange-800 border-orange-400/70',
  investment_escrow_release: 'bg-sky-100 text-sky-800 border-sky-400/70',
};

const FALLBACK_ACCENTS: ChipAccent[] = [
  'blue',
  'indigo',
  'violet',
  'cyan',
  'slate',
];

function normalizeEntryType(value: string): string {
  return value?.toLowerCase().trim() || '';
}

function stableAccent(key: string): ChipAccent {
  let hash = 0;
  for (let i = 0; i < key.length; i += 1) {
    hash = (hash * 31 + key.charCodeAt(i)) >>> 0;
  }
  return FALLBACK_ACCENTS[hash % FALLBACK_ACCENTS.length];
}

export function accountStatementEntryChipClasses(entryType: string, isDark: boolean): string {
  const key = normalizeEntryType(entryType);
  const tone = isDark ? ENTRY_CHIP_DARK[key] : ENTRY_CHIP_LIGHT[key];
  if (tone) {
    return clsx(STATEMENT_CHIP_BASE, tone);
  }
  return chipAccentClasses(stableAccent(key), isDark);
}
