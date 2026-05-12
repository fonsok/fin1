'use strict';

const DEFAULT_CHART_CODE = 'SKR03';
const DEFAULT_CHART_VERSION = '2026-05-v1';

const ACCOUNT_MAPPINGS = {
  'PLT-TAX-VST': { externalAccountNumber: '1576', vatKey: 'V19', taxTreatment: 'input_vat' },
  'PLT-TAX-VAT': { externalAccountNumber: '1776', vatKey: 'U19', taxTreatment: 'output_vat' },
  // ADR-010: Quellensteuer / Soli / Kirchensteuer als FA-Verbindlichkeiten
  // (SKR03 1741/1742/1743). VAT-Key 'frei', da Lohn-/Kapitalertragssteuer-
  // Verbindlichkeiten umsatzsteuerlich neutral durchgeleitet werden.
  'PLT-TAX-WHT': { externalAccountNumber: '1741', vatKey: 'frei', taxTreatment: 'non_taxable' },
  'PLT-TAX-SOL': { externalAccountNumber: '1742', vatKey: 'frei', taxTreatment: 'non_taxable' },
  'PLT-TAX-CHU': { externalAccountNumber: '1743', vatKey: 'frei', taxTreatment: 'non_taxable' },
  'PLT-REV-PSC': { externalAccountNumber: '8400', vatKey: 'U19', taxTreatment: 'output_vat' },
  'PLT-REV-ORD': { externalAccountNumber: '8400', vatKey: 'U19', taxTreatment: 'output_vat' },
  'PLT-REV-EXC': { externalAccountNumber: '8400', vatKey: 'U19', taxTreatment: 'output_vat' },
  'PLT-REV-FRG': { externalAccountNumber: '8400', vatKey: 'U19', taxTreatment: 'output_vat' },
  'PLT-REV-COM': { externalAccountNumber: '8400', vatKey: 'U19', taxTreatment: 'output_vat' },
  'PLT-EXP-OPS': { externalAccountNumber: '6800', vatKey: 'V19', taxTreatment: 'input_vat' },
  'PLT-EXP-REF': { externalAccountNumber: '4730', vatKey: 'frei', taxTreatment: 'non_taxable' },
  'PLT-CLR-GEN': { externalAccountNumber: '1360', vatKey: 'frei', taxTreatment: 'non_taxable' },
  'PLT-CLR-REF': { externalAccountNumber: '1360', vatKey: 'frei', taxTreatment: 'non_taxable' },
  'PLT-CLR-VAT': { externalAccountNumber: '1360', vatKey: 'frei', taxTreatment: 'non_taxable' },
  // ADR-010: Provisionsverbindlichkeit Plattform→Trader (SKR03 1700, sonstige
  // Verbindlichkeit). Saldenneutral pro Trade in Phase 1 (100% Trader-Cut).
  'PLT-LIAB-COM': { externalAccountNumber: '1700', vatKey: 'frei', taxTreatment: 'non_taxable' },
  'BANK-PS-NET': { externalAccountNumber: '1200', vatKey: 'frei', taxTreatment: 'non_taxable' },
  'BANK-PS-VAT': { externalAccountNumber: '1200', vatKey: 'frei', taxTreatment: 'non_taxable' },
  // ADR-011: Treuhand-Bankkonto Kundengelder (SKR03 1230, "Bank Treuhand").
  // Aktivkonto; debit bei Geldeingang/Sell-Erlös, credit bei Buy/Withdrawal.
  'BANK-TRT-CLT': { externalAccountNumber: '1230', vatKey: 'frei', taxTreatment: 'non_taxable' },
  'CLT-LIAB-AVA': { externalAccountNumber: '1590', vatKey: 'frei', taxTreatment: 'non_taxable' },
  'CLT-LIAB-RSV': { externalAccountNumber: '1591', vatKey: 'frei', taxTreatment: 'non_taxable' },
  'CLT-LIAB-TRD': { externalAccountNumber: '1592', vatKey: 'frei', taxTreatment: 'non_taxable' },
};

function getMappingSnapshotForAccount(accountCode, options = {}) {
  const mapped = ACCOUNT_MAPPINGS[accountCode];
  if (!mapped) {
    if (options.strict) {
      throw new Error(`Missing ledger account mapping for account "${accountCode}"`);
    }
    return {
      internalAccountId: accountCode,
      chartCodeSnapshot: '',
      chartVersionSnapshot: '',
      externalAccountNumberSnapshot: '',
      vatKeySnapshot: '',
      taxTreatmentSnapshot: '',
      mappingIdSnapshot: '',
    };
  }
  return {
    internalAccountId: accountCode,
    chartCodeSnapshot: DEFAULT_CHART_CODE,
    chartVersionSnapshot: DEFAULT_CHART_VERSION,
    externalAccountNumberSnapshot: mapped.externalAccountNumber,
    vatKeySnapshot: mapped.vatKey,
    taxTreatmentSnapshot: mapped.taxTreatment,
    mappingIdSnapshot: `${DEFAULT_CHART_CODE}:${DEFAULT_CHART_VERSION}:${accountCode}`,
  };
}

function isStrictMappingEnabled() {
  const value = String(process.env.FIN1_LEDGER_STRICT_MAPPING || '').trim().toLowerCase();
  return value === '1' || value === 'true' || value === 'yes' || value === 'on';
}

function getSnapshotOptions(options = {}) {
  if (typeof options.strict === 'boolean') return options;
  return { ...options, strict: isStrictMappingEnabled() };
}

function applyLedgerSnapshotToEntry(entry, accountCode, options = {}) {
  const snapshot = getMappingSnapshotForAccount(accountCode, getSnapshotOptions(options));
  entry.set('internalAccountId', snapshot.internalAccountId);
  entry.set('chartCodeSnapshot', snapshot.chartCodeSnapshot);
  entry.set('chartVersionSnapshot', snapshot.chartVersionSnapshot);
  entry.set('externalAccountNumberSnapshot', snapshot.externalAccountNumberSnapshot);
  entry.set('vatKeySnapshot', snapshot.vatKeySnapshot);
  entry.set('taxTreatmentSnapshot', snapshot.taxTreatmentSnapshot);
  entry.set('mappingIdSnapshot', snapshot.mappingIdSnapshot);
  return snapshot;
}

function mergeMetadataWithSnapshot(metadata, snapshot) {
  const baseMetadata = metadata || {};
  return Object.assign({}, baseMetadata, {
    chartCodeSnapshot: snapshot.chartCodeSnapshot,
    chartVersionSnapshot: snapshot.chartVersionSnapshot,
    externalAccountNumberSnapshot: snapshot.externalAccountNumberSnapshot,
    vatKeySnapshot: snapshot.vatKeySnapshot,
    taxTreatmentSnapshot: snapshot.taxTreatmentSnapshot,
    mappingIdSnapshot: snapshot.mappingIdSnapshot,
  });
}

function mapAccountDefinition(accountDef) {
  const mapped = ACCOUNT_MAPPINGS[accountDef.code];
  return {
    ...accountDef,
    chartCode: mapped ? DEFAULT_CHART_CODE : '',
    chartVersion: mapped ? DEFAULT_CHART_VERSION : '',
    externalAccountNumber: mapped ? mapped.externalAccountNumber : '',
    vatKey: mapped ? mapped.vatKey : '',
    taxTreatment: mapped ? mapped.taxTreatment : '',
  };
}

function getMappedAccounts(accounts) {
  return accounts.map(mapAccountDefinition);
}

function getLedgerAccountMappings() {
  return Object.entries(ACCOUNT_MAPPINGS).map(([internalAccountId, mapped]) => ({
    internalAccountId,
    chartCode: DEFAULT_CHART_CODE,
    chartVersion: DEFAULT_CHART_VERSION,
    externalAccountNumber: mapped.externalAccountNumber,
    vatKey: mapped.vatKey,
    taxTreatment: mapped.taxTreatment,
    mappingId: `${DEFAULT_CHART_CODE}:${DEFAULT_CHART_VERSION}:${internalAccountId}`,
  }));
}

function buildMappingValidationReport(accountCodes = []) {
  const uniqueAccountCodes = [...new Set(accountCodes)];
  const mappings = getLedgerAccountMappings();
  const mappedAccountCodes = new Set(mappings.map((m) => m.internalAccountId));
  const missingMappings = uniqueAccountCodes.filter((code) => !mappedAccountCodes.has(code));

  const mappingById = new Set();
  const duplicateMappingIds = [];
  for (const m of mappings) {
    if (mappingById.has(m.mappingId)) duplicateMappingIds.push(m.mappingId);
    mappingById.add(m.mappingId);
  }

  return {
    chartCode: DEFAULT_CHART_CODE,
    chartVersion: DEFAULT_CHART_VERSION,
    strictMappingEnabled: isStrictMappingEnabled(),
    totalInternalAccounts: uniqueAccountCodes.length,
    totalMappings: mappings.length,
    missingMappings,
    duplicateMappingIds,
    isValid: missingMappings.length === 0 && duplicateMappingIds.length === 0,
  };
}

module.exports = {
  DEFAULT_CHART_CODE,
  DEFAULT_CHART_VERSION,
  getMappingSnapshotForAccount,
  applyLedgerSnapshotToEntry,
  mergeMetadataWithSnapshot,
  getMappedAccounts,
  getLedgerAccountMappings,
  isStrictMappingEnabled,
  buildMappingValidationReport,
};
