import { formatLedgerAccountDisplayLabel } from './constants';

export type LedgerAccountCatalogEntry = {
  name: string;
  externalAccountNumber?: string;
};

export type CounterAccountDisplaySegment = {
  internalCode: string;
  primaryLabel: string;
  hasCatalogEntry: boolean;
};

/** Internal ledger code(s) for the counter-account column (before display formatting). */
export function resolveCounterAccountLabel(
  account: string,
  transactionType: string,
  pairedAccountsRaw?: string,
  pairedAccountRaw?: string,
  escrowLegRaw?: string,
  splitPartRaw?: string,
): string {
  const pairedSource = pairedAccountsRaw || pairedAccountRaw || '';
  const pairedAccounts = pairedSource
    .split(',')
    .map((entry) => entry.trim())
    .filter(Boolean);
  if (pairedAccounts.length > 0) return pairedAccounts.join(', ');

  if (transactionType === 'appServiceCharge') {
    if (account === 'PLT-REV-PSC' || account === 'PLT-TAX-VAT') return 'PLT-CLR-GEN';
    if (account === 'PLT-CLR-GEN') return 'PLT-REV-PSC, PLT-TAX-VAT';
  }

  if (transactionType === 'investmentEscrow') {
    const leg = String(escrowLegRaw || '').trim();
    if (leg === 'reserve' || leg === 'releaseReserve' || leg === 'releaseReservedComplete') {
      if (account === 'CLT-LIAB-AVA') return 'CLT-LIAB-RSV';
      if (account === 'CLT-LIAB-RSV') return 'CLT-LIAB-AVA';
    }
    if (leg === 'deploy') {
      if (account === 'CLT-LIAB-RSV') return 'CLT-LIAB-PTR';
      if (account === 'CLT-LIAB-PTR' || account === 'CLT-LIAB-TRD') return 'CLT-LIAB-RSV';
    }
    if (leg === 'partialSellRelease') {
      if (account === 'CLT-LIAB-PTR' || account === 'CLT-LIAB-TRD') return 'CLT-LIAB-PPS';
      if (account === 'CLT-LIAB-PPS') return 'CLT-LIAB-PTR';
    }
    if (leg === 'tradeSettlementPartialPoolRelease') {
      if (account === 'CLT-LIAB-PPS') return 'CLT-LIAB-AVA';
      if (account === 'CLT-LIAB-AVA') return 'CLT-LIAB-PPS';
    }
    if (leg === 'releaseTradingComplete' || leg === 'releaseTradingRefund') {
      if (account === 'CLT-LIAB-PTR' || account === 'CLT-LIAB-TRD') return 'CLT-LIAB-AVA';
      if (account === 'CLT-LIAB-AVA') return 'CLT-LIAB-PTR';
    }
    if (leg === 'reserveCapitalTradeSplit') {
      const part = String(splitPartRaw || '').trim();
      if (account === 'CLT-LIAB-RSV') return 'CLT-LIAB-PTR + CLT-LIAB-AVA';
      if (account === 'CLT-LIAB-PTR' || account === 'CLT-LIAB-TRD') return 'CLT-LIAB-RSV';
      if (account === 'CLT-LIAB-AVA' && part === 'available') return 'CLT-LIAB-RSV';
    }
  }
  return '-';
}

export function formatLedgerAccountCodeLabel(
  code: string,
  accountByCode: ReadonlyMap<string, LedgerAccountCatalogEntry>,
): string {
  const key = code.trim();
  if (!key) return '-';
  const acc = accountByCode.get(key);
  if (acc) return `${formatLedgerAccountDisplayLabel(acc)} (${key})`;
  return key;
}

export function resolveCounterAccountDisplaySegments(
  rawLabel: string,
  accountByCode: ReadonlyMap<string, LedgerAccountCatalogEntry>,
): CounterAccountDisplaySegment[] {
  const trimmed = rawLabel.trim();
  if (!trimmed || trimmed === '-') return [];
  return trimmed
    .split(/\s*(?:,|\+)\s*/)
    .filter(Boolean)
    .map((code) => {
      const key = code.trim();
      const acc = accountByCode.get(key);
      if (acc) {
        return {
          internalCode: key,
          primaryLabel: formatLedgerAccountDisplayLabel(acc),
          hasCatalogEntry: true,
        };
      }
      return {
        internalCode: key,
        primaryLabel: key,
        hasCatalogEntry: false,
      };
    });
}

/** Plain-text label: „Kontonummer Bezeichnung (INTERN-CODE)“. */
export function formatCounterAccountColumnLabel(
  rawLabel: string,
  accountByCode: ReadonlyMap<string, LedgerAccountCatalogEntry>,
): string {
  const trimmed = rawLabel.trim();
  if (!trimmed || trimmed === '-') return '-';
  const segments = trimmed.split(/\s*(?:,|\+)\s*/).filter(Boolean);
  return segments.map((code) => formatLedgerAccountCodeLabel(code, accountByCode)).join(', ');
}
