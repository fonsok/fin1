'use strict';

const PLATFORM_ACCOUNTS = [
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
  { code: 'PLT-EXP-OPS', name: 'Betriebsaufwand', group: 'expense' },
  { code: 'PLT-EXP-REF', name: 'Erstattungsaufwand', group: 'expense' },
  { code: 'PLT-CLR-GEN', name: 'Verrechnungskonto', group: 'clearing' },
  { code: 'PLT-CLR-REF', name: 'Erstattungs-Verrechnungskonto', group: 'clearing' },
  { code: 'PLT-CLR-VAT', name: 'USt-Abführung Verrechnungskonto', group: 'clearing' },
];

const BANK_CONTRA_ACCOUNTS = [
  { code: 'BANK-PS-NET', name: 'Bank Clearing – Service Charge NET', group: 'clearing' },
  { code: 'BANK-PS-VAT', name: 'Bank Clearing – Service Charge VAT', group: 'clearing' },
];

const FULL_PLATFORM_ACCOUNTS = [...PLATFORM_ACCOUNTS, ...BANK_CONTRA_ACCOUNTS];

function mapBankContraToEntry(p) {
  return {
    id: p.id,
    account: p.get('account'),
    side: p.get('side'),
    amount: p.get('amount'),
    userId: p.get('investorId') || '',
    userRole: 'investor',
    transactionType: 'platformServiceCharge',
    referenceId: p.get('batchId') || '',
    referenceType: 'investment_batch',
    description: `Bank Contra ${p.get('account')} – ${p.get('investorName') || p.get('investorId') || '?'}`,
    createdAt: p.get('createdAt'),
    metadata: p.get('metadata') || {},
  };
}

module.exports = {
  PLATFORM_ACCOUNTS,
  BANK_CONTRA_ACCOUNTS,
  FULL_PLATFORM_ACCOUNTS,
  mapBankContraToEntry,
};
