import clsx from 'clsx';
import { useState } from 'react';
import { useQuery } from '@tanstack/react-query';
import { cloudFunction } from '../../api/admin';
import { Card, Button, Badge } from '../../components/ui';
import { useTheme } from '../../context/ThemeContext';
import { formatCurrency, formatDateTime } from '../../utils/format';
import {
  listRowStripeClasses,
  tableBodyDivideClasses,
  tableBodyCellMutedClasses,
  tableBodyCellPrimaryClasses,
  tableHeaderCellTextClasses,
  tableTheadSurfaceClasses,
} from '../../utils/tableStriping';
import { formatLedgerAccountDisplayLabel } from './appLedger/constants';

import { adminBorderChromeSoft, adminCaption, adminControlFieldPh500, adminDualMuted, adminMuted, adminPrimary, adminStrong } from '../../utils/adminThemeClasses';
interface ContraPosting {
  id: string;
  account: string;
  side: 'credit' | 'debit';
  amount: number;
  investorId: string;
  investorName: string;
  batchId: string;
  investmentIds: string[];
  reference: string;
  createdAt: string;
  metadata: Record<string, string>;
}

interface AccountTotals {
  credit: number;
  debit: number;
  net: number;
}

interface AccountDef {
  code: string;
  name: string;
  externalAccountNumber?: string;
}

interface LedgerResponse {
  postings: ContraPosting[];
  totals: Record<string, AccountTotals>;
  totalCount: number;
  accounts: AccountDef[];
}

export function BankContraLedgerPage(): JSX.Element {
  const { theme } = useTheme();
  const isDark = theme === 'dark';
  const [selectedAccount, setSelectedAccount] = useState<string>('');
  const [investorFilter, setInvestorFilter] = useState('');

  const { data, isLoading, refetch } = useQuery({
    queryKey: ['bankContraLedger', selectedAccount],
    queryFn: () =>
      cloudFunction<LedgerResponse>('getBankContraLedger', {
        ...(selectedAccount ? { account: selectedAccount } : {}),
      }),
    staleTime: 60000,
  });

  const postings = data?.postings || [];
  const accounts = data?.accounts || [
    { code: 'BANK-PS-NET', name: 'Bank Clearing – Service Charge NET' },
    { code: 'BANK-PS-VAT', name: 'Bank Clearing – Service Charge VAT' },
  ];

  const normalizedFilter = investorFilter.trim().toLowerCase();
  const filteredPostings = normalizedFilter
    ? postings.filter((p) =>
        (p.investorName || '').toLowerCase().includes(normalizedFilter) ||
        (p.investorId || '').toLowerCase().includes(normalizedFilter))
    : postings;

  const totals: Record<string, AccountTotals> = {};
  for (const p of filteredPostings) {
    const key = p.account;
    if (!totals[key]) {
      totals[key] = { credit: 0, debit: 0, net: 0 };
    }
    if (p.side === 'credit') {
      totals[key].credit += p.amount;
      totals[key].net += p.amount;
    } else {
      totals[key].debit += p.amount;
      totals[key].net -= p.amount;
    }
  }

  const pageTitle = clsx('text-2xl font-bold', adminPrimary(isDark));
  const leadMuted = clsx('mt-1', adminMuted(isDark));
  const formLabel = clsx('block text-sm font-medium mb-1', adminStrong(isDark));
  const controlSm = clsx(
    'w-full border rounded-lg px-3 py-2 text-sm',
    adminControlFieldPh500(isDark),
  );
  const accountTitle = clsx('font-medium', adminPrimary(isDark));
  const accountCode = clsx('text-xs font-mono', tableBodyCellMutedClasses(isDark));
  const legLabel = clsx('text-sm', tableBodyCellMutedClasses(isDark));
  const emptyMini = clsx('text-sm', adminCaption(isDark));
  const emptyState = clsx('p-8 text-center', tableBodyCellMutedClasses(isDark));
  const sectionH2 = clsx('text-lg font-semibold', adminPrimary(isDark));
  const toolbarBorder = clsx('p-4 border-b flex justify-between items-center', adminBorderChromeSoft(isDark));

  const exportCSV = () => {
    if (filteredPostings.length === 0) return;
    const header = ['Datum', 'Konto', 'Seite', 'Betrag', 'Investor', 'Investor-ID', 'Batch', 'Referenz'].join(',');
    const rows = filteredPostings.map((p) =>
      [
        formatDateTime(p.createdAt),
        p.account,
        p.side === 'credit' ? 'Haben' : 'Soll',
        p.amount.toFixed(2),
        p.investorName || p.investorId,
        p.investorId,
        p.batchId,
        p.reference,
      ]
        .map((v) => `"${v}"`)
        .join(',')
    );
    const csv = [header, ...rows].join('\n');
    const blob = new Blob([csv], { type: 'text/csv;charset=utf-8;' });
    const url = URL.createObjectURL(blob);
    const link = document.createElement('a');
    link.href = url;
    link.download = `bank-contra-ledger-${new Date().toISOString().slice(0, 10)}.csv`;
    link.click();
    URL.revokeObjectURL(url);
  };

  return (
    <div className="space-y-6">
      <div className="flex flex-col sm:flex-row justify-between items-start sm:items-center gap-4">
        <div>
          <h1 className={pageTitle}>Bank Contra Ledger</h1>
          <p className={leadMuted}>Verrechnungskonten für App Service Charges (NET + USt.)</p>
        </div>
        <div className="flex items-center gap-2">
          <Button variant="secondary" onClick={exportCSV} disabled={postings.length === 0}>
            CSV Export
          </Button>
          <Button variant="secondary" onClick={() => refetch()} disabled={isLoading}>
            {isLoading ? 'Laden...' : 'Aktualisieren'}
          </Button>
        </div>
      </div>

      <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
        {accounts.map((acc) => {
          const t = totals[acc.code];
          return (
            <Card key={acc.code} className={selectedAccount === acc.code ? 'ring-2 ring-fin1-primary' : ''}>
              <button
                type="button"
                className="w-full text-left"
                onClick={() => setSelectedAccount(selectedAccount === acc.code ? '' : acc.code)}
              >
                <div className="flex items-center justify-between mb-2">
                  <span className={accountTitle}>{formatLedgerAccountDisplayLabel(acc)}</span>
                  <span className={accountCode}>{acc.code}</span>
                </div>
                {t ? (
                  <div className="grid grid-cols-3 gap-2 text-sm">
                    <div>
                      <p className={legLabel}>Haben</p>
                      <p className="font-medium text-green-600">{formatCurrency(t.credit)}</p>
                    </div>
                    <div>
                      <p className={legLabel}>Soll</p>
                      <p className="font-medium text-red-600">{formatCurrency(t.debit)}</p>
                    </div>
                    <div>
                      <p className={legLabel}>Saldo</p>
                      <p className="font-bold text-fin1-primary">{formatCurrency(t.net)}</p>
                    </div>
                  </div>
                ) : (
                  <p className={emptyMini}>Keine Buchungen</p>
                )}
              </button>
            </Card>
          );
        })}
      </div>

      <Card>
        <div className="flex flex-col sm:flex-row gap-4 items-end">
          <div className="flex-1">
            <label className={formLabel}>Konto</label>
            <select value={selectedAccount} onChange={(e) => setSelectedAccount(e.target.value)} className={controlSm}>
              <option value="">Alle Konten</option>
              {accounts.map((a) => (
                <option key={a.code} value={a.code}>
                  {formatLedgerAccountDisplayLabel(a)}
                </option>
              ))}
            </select>
          </div>
          <div className="flex-1">
            <label className={formLabel}>Investor</label>
            <input
              type="text"
              value={investorFilter}
              onChange={(e) => setInvestorFilter(e.target.value)}
              placeholder="Name oder ID filtern..."
              className={controlSm}
            />
          </div>
          <Button
            variant="ghost"
            onClick={() => {
              setSelectedAccount('');
              setInvestorFilter('');
            }}
          >
            Filter zurücksetzen
          </Button>
        </div>
      </Card>

      <Card>
        <div className={toolbarBorder}>
          <h2 className={sectionH2}>Buchungen ({filteredPostings.length})</h2>
        </div>

        {isLoading ? (
          <div className={emptyState}>Daten werden geladen...</div>
        ) : filteredPostings.length === 0 ? (
          <div className={emptyState}>
            Keine Buchungen gefunden.
            {!selectedAccount && !investorFilter && (
              <p className={clsx('mt-2 text-sm', adminDualMuted(isDark))}>
                Buchungen werden erzeugt, wenn Investments mit App Service Charge abgerechnet werden.
              </p>
            )}
          </div>
        ) : (
          <div className="overflow-x-auto">
            <table className="w-full">
              <thead className={tableTheadSurfaceClasses(isDark)}>
                <tr>
                  <th className={clsx('px-4 py-3 text-left text-xs font-medium uppercase', tableHeaderCellTextClasses(isDark))}>
                    Datum
                  </th>
                  <th className={clsx('px-4 py-3 text-left text-xs font-medium uppercase', tableHeaderCellTextClasses(isDark))}>
                    Konto
                  </th>
                  <th className={clsx('px-4 py-3 text-center text-xs font-medium uppercase', tableHeaderCellTextClasses(isDark))}>
                    Seite
                  </th>
                  <th className={clsx('px-4 py-3 text-right text-xs font-medium uppercase', tableHeaderCellTextClasses(isDark))}>
                    Betrag
                  </th>
                  <th className={clsx('px-4 py-3 text-left text-xs font-medium uppercase', tableHeaderCellTextClasses(isDark))}>
                    Investor
                  </th>
                  <th className={clsx('px-4 py-3 text-left text-xs font-medium uppercase', tableHeaderCellTextClasses(isDark))}>
                    Referenz
                  </th>
                  <th className={clsx('px-4 py-3 text-left text-xs font-medium uppercase', tableHeaderCellTextClasses(isDark))}>
                    Details
                  </th>
                </tr>
              </thead>
              <tbody className={tableBodyDivideClasses(isDark)}>
                {filteredPostings.map((p, index) => (
                  <tr
                    key={p.id}
                    className={clsx(
                      listRowStripeClasses(isDark, index),
                      isDark ? 'hover:bg-slate-700/35' : 'hover:bg-gray-50',
                    )}
                  >
                    <td className={clsx('px-4 py-3 text-sm whitespace-nowrap', tableBodyCellMutedClasses(isDark))}>
                      {formatDateTime(p.createdAt)}
                    </td>
                    <td className={clsx('px-4 py-3 text-sm font-mono whitespace-nowrap', tableBodyCellPrimaryClasses(isDark))}>
                      {p.account}
                    </td>
                    <td className="px-4 py-3 text-center">
                      <Badge variant={p.side === 'credit' ? 'success' : 'danger'}>
                        {p.side === 'credit' ? 'Haben' : 'Soll'}
                      </Badge>
                    </td>
                    <td
                      className={clsx(
                        'px-4 py-3 text-sm text-right font-medium whitespace-nowrap',
                        p.side === 'credit' ? 'text-green-600' : 'text-red-600',
                      )}
                    >
                      {formatCurrency(p.amount)}
                    </td>
                    <td className={clsx('px-4 py-3 text-sm whitespace-nowrap', tableBodyCellPrimaryClasses(isDark))}>
                      {p.investorName || p.investorId || '-'}
                    </td>
                    <td className={clsx('px-4 py-3 text-sm font-mono whitespace-nowrap', tableBodyCellMutedClasses(isDark))}>
                      {p.reference}
                    </td>
                    <td className={clsx('px-4 py-3 text-sm', adminCaption(isDark))}>
                      {p.metadata?.component === 'net'
                        ? 'Netto-Anteil'
                        : p.metadata?.component === 'vat'
                          ? 'USt.-Anteil'
                          : Object.keys(p.metadata || {}).length > 0
                            ? Object.entries(p.metadata)
                                .map(([k, v]) => `${k}: ${v}`)
                                .join(', ')
                            : '-'}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </Card>
    </div>
  );
}
