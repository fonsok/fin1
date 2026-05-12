/** SKR / externes Konto vor Bezeichnung, z. B. „1591 Kundenguthaben – …“. */
export function formatLedgerAccountDisplayLabel(account: {
  name: string;
  externalAccountNumber?: string;
}): string {
  const num = String(account.externalAccountNumber || '').trim();
  if (num) return `${num} ${account.name}`;
  return account.name;
}

export const TRANSACTION_TYPE_LABELS: Record<string, string> = {
  investmentEscrow: 'Investment-Escrow (Kundenguthaben)',
  appServiceCharge: 'Appgebühr',
  // Legacy key from older backend payloads (kept for compatibility).
  platformServiceCharge: 'Appgebühr',
  orderFee: 'Ordergebühr',
  exchangeFee: 'Börsenplatzgebühr',
  foreignCosts: 'Fremdkosten',
  commission: 'Provision',
  refund: 'Erstattung',
  creditNote: 'Gutschrift',
  vatRemittance: 'USt-Abführung',
  vatInputClaim: 'Vorsteuer',
  operatingExpense: 'Betriebsausgabe',
  adjustment: 'Korrektur',
  reversal: 'Storno',
};

export const GROUP_LABELS: Record<string, string> = {
  liability: 'Kundenguthaben (Teilverbindlichkeiten)',
  revenue: 'Erlöskonten',
  tax: 'Steuerkonten',
  expense: 'Aufwandskonten',
  clearing: 'Verrechnungskonten',
};

export function getOverviewClasses(isDark: boolean) {
  return {
    overviewLabelClass: isDark ? 'text-slate-200' : 'text-gray-600',
    overviewSubtitleClass: isDark ? 'text-slate-300' : 'text-gray-500',
    greenCardClass: isDark
      ? 'bg-gradient-to-r from-green-900/30 to-green-900/10 border-green-700/50'
      : 'bg-gradient-to-r from-green-50 to-green-100/50 border-green-200',
    redCardClass: isDark
      ? 'bg-gradient-to-r from-red-900/25 to-red-900/10 border-red-700/45'
      : 'bg-gradient-to-r from-red-50 to-red-100/50 border-red-200',
    blueCardClass: isDark
      ? 'bg-gradient-to-r from-blue-900/25 to-blue-900/10 border-blue-700/45'
      : 'bg-gradient-to-r from-blue-50 to-blue-100/50 border-blue-200',
    purpleCardClass: isDark
      ? 'bg-gradient-to-r from-purple-900/25 to-purple-900/10 border-purple-700/45'
      : 'bg-gradient-to-r from-purple-50 to-purple-100/50 border-purple-200',
    greenValueClass: isDark ? 'text-green-300' : 'text-green-700',
    redValueClass: isDark ? 'text-red-300' : 'text-red-600',
    blueValueClass: isDark ? 'text-blue-300' : 'text-blue-700',
    purpleValueClass: isDark ? 'text-purple-300' : 'text-purple-700',
  };
}
