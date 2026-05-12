'use strict';

/**
 * Kontenrahmen-Hinweise und Paarregeln für vertiefte Perioden-Abstimmung.
 * Fachlich: App-Hauptbuch-Konten (FULL_APP_ACCOUNTS) + dokumentierte Erwartungen.
 */

const { FULL_APP_ACCOUNTS } = require('./shared');

/** @type {Record<string, 'debit' | 'credit'>} */
const NORMAL_BALANCE_BY_GROUP = {
  liability: 'credit',
  revenue: 'credit',
  tax: 'credit',
  expense: 'debit',
  clearing: 'credit', // gemischt — nur Hinweis
  asset: 'debit',
};

function buildAccountChartMeta() {
  return FULL_APP_ACCOUNTS.map((a) => ({
    code: a.code,
    name: a.name,
    group: a.group,
    normalBalance: NORMAL_BALANCE_BY_GROUP[a.group] || 'credit',
  }));
}

/**
 * Perioden-Netto je Leg (Soll−Haben wie aggregateAppLedger) — Paare sollen ≈ 0 summieren,
 * wenn das Buchungsmuster vollständig im Zeitraum und Hauptbuch erfasst ist.
 */
const PERIOD_NET_ZERO_PAIRS = [
  {
    id: 'trade_cash_ava_trust',
    description:
      'Trade-Cash (ADR-011): CLT-LIAB-AVA und BANK-TRT-CLT mit transactionType tradeCash.',
    toleranceEUR: 0.05,
    legs: [
      { account: 'CLT-LIAB-AVA', transactionTypes: ['tradeCash'] },
      { account: 'BANK-TRT-CLT', transactionTypes: ['tradeCash'] },
    ],
  },
  {
    id: 'wallet_deposit_ava_trust',
    description: 'Wallet-Einzahlung: CLT-LIAB-AVA vs BANK-TRT-CLT (walletDeposit).',
    toleranceEUR: 0.05,
    legs: [
      { account: 'CLT-LIAB-AVA', transactionTypes: ['walletDeposit'] },
      { account: 'BANK-TRT-CLT', transactionTypes: ['walletDeposit'] },
    ],
  },
  {
    id: 'wallet_withdrawal_ava_trust',
    description: 'Wallet-Auszahlung: CLT-LIAB-AVA vs BANK-TRT-CLT (walletWithdrawal).',
    toleranceEUR: 0.05,
    legs: [
      { account: 'CLT-LIAB-AVA', transactionTypes: ['walletWithdrawal'] },
      { account: 'BANK-TRT-CLT', transactionTypes: ['walletWithdrawal'] },
    ],
  },
];

/** Konten, für die wir (account × transactionType) fein aggregieren — Ressourcen-Schutz. */
function accountsForDetailedAggregation() {
  const s = new Set();
  for (const rule of PERIOD_NET_ZERO_PAIRS) {
    for (const leg of rule.legs) {
      s.add(leg.account);
    }
  }
  return s;
}

module.exports = {
  buildAccountChartMeta,
  PERIOD_NET_ZERO_PAIRS,
  accountsForDetailedAggregation,
  NORMAL_BALANCE_BY_GROUP,
};
