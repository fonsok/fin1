import { describe, expect, it } from 'vitest';
import { orientInvestorStatementsForAdminPortal } from './orientInvestorStatementsForAdminPortal';
import type { AccountStatementData } from '../../../api/admin';

function stmt(overrides: Partial<AccountStatementData> & { entries: AccountStatementData['entries'] }): AccountStatementData {
  const { entries, ...rest } = overrides;
  return {
    initialBalance: 0,
    closingBalance: 0,
    totalCredits: 0,
    totalDebits: 0,
    netChange: 0,
    sortOrder: 'asc',
    ...rest,
    entries,
  };
}

describe('orientInvestorStatementsForAdminPortal', () => {
  it('does not swap trader payloads', () => {
    const customer = stmt({ presentationMode: 'customer', entries: [] });
    const ledger = stmt({ presentationMode: 'ledger', entries: [] });
    const r = orientInvestorStatementsForAdminPortal('trader', customer, ledger);
    expect(r.customerStatement).toBe(customer);
    expect(r.ledgerStatement).toBe(ledger);
  });

  it('keeps canonical investor pair (merge without activate, raw with activate)', () => {
    const customer = stmt({
      presentationMode: 'customer',
      entries: [
        { objectId: 'app-ledger:x', entryType: 'investment_escrow_reserve', amount: -50, balanceAfter: 950, description: '', source: 'app_subledger', createdAt: '' },
      ],
    });
    const ledger = stmt({
      presentationMode: 'ledger',
      entries: [
        { objectId: 's1', entryType: 'investment_activate', amount: -100, balanceAfter: 900, description: '', source: 'backend', createdAt: '' },
      ],
    });
    const r = orientInvestorStatementsForAdminPortal('investor', customer, ledger);
    expect(r.customerStatement).toBe(customer);
    expect(r.ledgerStatement).toBe(ledger);
  });

  it('swaps when investment_activate appears only on accountStatement (raw mis-assigned)', () => {
    const rawAsMain = stmt({
      presentationMode: 'customer',
      entries: [
        { objectId: 's1', entryType: 'investment_activate', amount: -100, balanceAfter: 900, description: '', source: 'backend', createdAt: '' },
      ],
    });
    const mergeAsLedger = stmt({
      presentationMode: 'ledger',
      entries: [
        { objectId: 'app-ledger:x', entryType: 'investment_escrow_reserve', amount: -50, balanceAfter: 950, description: '', source: 'app_subledger', createdAt: '' },
      ],
    });
    const r = orientInvestorStatementsForAdminPortal('investor', rawAsMain, mergeAsLedger);
    expect(r.customerStatement).toBe(mergeAsLedger);
    expect(r.ledgerStatement).toBe(rawAsMain);
  });

  it('swaps when app_subledger appears only on accountStatementLedger', () => {
    const rawAsMain = stmt({
      presentationMode: 'customer',
      entries: [
        { objectId: 's1', entryType: 'deposit', amount: 1000, balanceAfter: 1000, description: '', source: 'backend', createdAt: '' },
      ],
    });
    const mergeAsLedger = stmt({
      presentationMode: 'ledger',
      entries: [
        { objectId: 'app-ledger:x', entryType: 'investment_escrow_reserve', amount: -50, balanceAfter: 950, description: '', source: 'app_subledger', createdAt: '' },
      ],
    });
    const r = orientInvestorStatementsForAdminPortal('investor', rawAsMain, mergeAsLedger);
    expect(r.customerStatement).toBe(mergeAsLedger);
    expect(r.ledgerStatement).toBe(rawAsMain);
  });

  it('swaps when presentationMode is reversed on the two objects', () => {
    const a = stmt({ presentationMode: 'ledger', entries: [] });
    const b = stmt({ presentationMode: 'customer', entries: [] });
    const r = orientInvestorStatementsForAdminPortal('investor', a, b);
    expect(r.customerStatement).toBe(b);
    expect(r.ledgerStatement).toBe(a);
  });

  it('picks merge-shaped payload as customer when API fields are inverted (mergedLikeness)', () => {
    const mergePayload = stmt({
      presentationMode: 'ledger',
      entries: [
        { objectId: 'app-ledger:x', entryType: 'investment_escrow_reserve', amount: -50, balanceAfter: 9950, description: '', source: 'app_subledger', createdAt: '' },
        { objectId: 'd1', entryType: 'deposit', amount: 10000, balanceAfter: 10000, description: '', source: 'backend', createdAt: '' },
      ],
    });
    const rawPayload = stmt({
      presentationMode: 'customer',
      entries: [
        { objectId: 's1', entryType: 'investment_activate', amount: -1000, balanceAfter: 9000, description: '', source: 'backend', createdAt: '' },
      ],
    });
    const r = orientInvestorStatementsForAdminPortal('investor', rawPayload, mergePayload);
    expect(r.customerStatement).toBe(mergePayload);
    expect(r.ledgerStatement).toBe(rawPayload);
  });
});
