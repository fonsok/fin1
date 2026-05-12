'use strict';

const {
  getMappedAccounts: mapAccountsWithResolver,
  getLedgerAccountMappings,
  getMappingSnapshotForAccount,
} = require('../../../utils/accountingHelper/accountMappingResolver');

const APP_ACCOUNTS = [
  // Kundenguthaben (Teil-Verbindlichkeiten) – Buchungen folgen bei serverseitiger Escrow-Policy
  { code: 'CLT-LIAB-AVA', name: 'Kundenguthaben – verfügbar', group: 'liability' },
  { code: 'CLT-LIAB-RSV', name: 'Kundenguthaben – für Investments reserviert', group: 'liability' },
  { code: 'CLT-LIAB-TRD', name: 'Kundenguthaben – im Handel / Pool', group: 'liability' },
  { code: 'PLT-REV-PSC', name: 'Erlös Appgebühr (netto)', group: 'revenue' },
  { code: 'PLT-REV-ORD', name: 'Erlös Ordergebühren', group: 'revenue' },
  { code: 'PLT-REV-EXC', name: 'Erlös Börsenplatzgebühren', group: 'revenue' },
  { code: 'PLT-REV-FRG', name: 'Fremdkostenpauschale', group: 'revenue' },
  { code: 'PLT-REV-COM', name: 'Provisionserlös', group: 'revenue' },
  { code: 'PLT-TAX-VAT', name: 'USt-Verbindlichkeit (Output)', group: 'tax' },
  { code: 'PLT-TAX-VST', name: 'Vorsteuer (Input)', group: 'tax' },
  // ADR-010: FA-Verbindlichkeiten aus Settlement (Quellensteuer / Soli / KiSt)
  { code: 'PLT-TAX-WHT', name: 'Quellensteuer-Verbindlichkeit', group: 'tax' },
  { code: 'PLT-TAX-SOL', name: 'Solidaritätszuschlag-Verbindlichkeit', group: 'tax' },
  { code: 'PLT-TAX-CHU', name: 'Kirchensteuer-Verbindlichkeit', group: 'tax' },
  { code: 'PLT-EXP-OPS', name: 'Betriebsaufwand', group: 'expense' },
  { code: 'PLT-EXP-REF', name: 'Erstattungsaufwand', group: 'expense' },
  { code: 'PLT-CLR-GEN', name: 'Verrechnungskonto', group: 'clearing' },
  { code: 'PLT-CLR-REF', name: 'Erstattungs-Verrechnungskonto', group: 'clearing' },
  { code: 'PLT-CLR-VAT', name: 'USt-Abführung Verrechnungskonto', group: 'clearing' },
  // ADR-010: Provisionsverbindlichkeit (Clearing Investor↔Trader)
  { code: 'PLT-LIAB-COM', name: 'Provisionsverbindlichkeit Trader', group: 'liability' },
];

const BANK_CONTRA_ACCOUNTS = [
  { code: 'BANK-PS-NET', name: 'Bank Clearing – Service Charge NET', group: 'clearing' },
  { code: 'BANK-PS-VAT', name: 'Bank Clearing – Service Charge VAT', group: 'clearing' },
  // ADR-011: Treuhand-Bank Kundengelder (Trade BUY/SELL, Wallet IN/OUT)
  { code: 'BANK-TRT-CLT', name: 'Treuhand-Bank Kundengelder', group: 'asset' },
];

const FULL_APP_ACCOUNTS = [...APP_ACCOUNTS, ...BANK_CONTRA_ACCOUNTS];

function getMappedAccounts() {
  return mapAccountsWithResolver(FULL_APP_ACCOUNTS);
}

function mapBankContraToEntry(p) {
  const account = p.get('account');
  const mappingSnapshot = getMappingSnapshotForAccount(account) || {};
  return {
    id: p.id,
    account,
    side: p.get('side'),
    amount: p.get('amount'),
    userId: p.get('investorId') || '',
    userRole: 'investor',
    transactionType: 'appServiceCharge',
    referenceId: p.get('batchId') || '',
    referenceType: 'investment_batch',
    description: `Bank Contra ${account} – ${p.get('investorName') || p.get('investorId') || '?'}`,
    createdAt: p.get('createdAt'),
    metadata: p.get('metadata') || {},
    ...mappingSnapshot,
  };
}

module.exports = {
  APP_ACCOUNTS,
  BANK_CONTRA_ACCOUNTS,
  FULL_APP_ACCOUNTS,
  getMappedAccounts,
  getLedgerAccountMappings,
  getMappingSnapshotForAccount,
  mapBankContraToEntry,
};
