import { useState } from 'react';
import { useQuery } from '@tanstack/react-query';
import { cloudFunction } from '../../api/admin';
import { Card, Button, Badge } from '../../components/ui';
import { formatCurrency, formatDateTime } from '../../utils/format';

interface ContraPosting {
  id: string;
  account: string;
  side: 'credit' | 'debit';
  amount: number;
  investorId: string;
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
}

interface LedgerResponse {
  postings: ContraPosting[];
  totals: Record<string, AccountTotals>;
  totalCount: number;
  accounts: AccountDef[];
}

export function BankContraLedgerPage(): JSX.Element {
  const [selectedAccount, setSelectedAccount] = useState<string>('');
  const [investorFilter, setInvestorFilter] = useState('');

  const { data, isLoading, refetch } = useQuery({
    queryKey: ['bankContraLedger', selectedAccount, investorFilter],
    queryFn: () =>
      cloudFunction<LedgerResponse>('getBankContraLedger', {
        ...(selectedAccount ? { account: selectedAccount } : {}),
        ...(investorFilter ? { investorId: investorFilter } : {}),
      }),
    staleTime: 60000,
  });

  const postings = data?.postings || [];
  const totals = data?.totals || {};
  const accounts = data?.accounts || [
    { code: 'BANK-PS-NET', name: 'Bank Clearing – Service Charge NET' },
    { code: 'BANK-PS-VAT', name: 'Bank Clearing – Service Charge VAT' },
  ];

  const exportCSV = () => {
    if (postings.length === 0) return;
    const header = ['Datum', 'Konto', 'Seite', 'Betrag', 'Investor', 'Batch', 'Referenz'].join(',');
    const rows = postings.map((p) =>
      [
        formatDateTime(p.createdAt),
        p.account,
        p.side === 'credit' ? 'Haben' : 'Soll',
        p.amount.toFixed(2),
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
      {/* Header */}
      <div className="flex flex-col sm:flex-row justify-between items-start sm:items-center gap-4">
        <div>
          <h1 className="text-2xl font-bold text-gray-900">Bank Contra Ledger</h1>
          <p className="text-gray-500 mt-1">
            Verrechnungskonten für Platform Service Charges (NET + USt.)
          </p>
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

      {/* Account Totals */}
      <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
        {accounts.map((acc) => {
          const t = totals[acc.code];
          return (
            <Card key={acc.code} className={selectedAccount === acc.code ? 'ring-2 ring-fin1-primary' : ''}>
              <button
                className="w-full text-left"
                onClick={() => setSelectedAccount(selectedAccount === acc.code ? '' : acc.code)}
              >
                <div className="flex items-center justify-between mb-2">
                  <span className="font-medium text-gray-900">{acc.name}</span>
                  <span className="text-xs font-mono text-gray-400">{acc.code}</span>
                </div>
                {t ? (
                  <div className="grid grid-cols-3 gap-2 text-sm">
                    <div>
                      <p className="text-gray-500">Haben</p>
                      <p className="font-medium text-green-600">{formatCurrency(t.credit)}</p>
                    </div>
                    <div>
                      <p className="text-gray-500">Soll</p>
                      <p className="font-medium text-red-600">{formatCurrency(t.debit)}</p>
                    </div>
                    <div>
                      <p className="text-gray-500">Saldo</p>
                      <p className="font-bold text-fin1-primary">{formatCurrency(t.net)}</p>
                    </div>
                  </div>
                ) : (
                  <p className="text-sm text-gray-400">Keine Buchungen</p>
                )}
              </button>
            </Card>
          );
        })}
      </div>

      {/* Filters */}
      <Card>
        <div className="flex flex-col sm:flex-row gap-4 items-end">
          <div className="flex-1">
            <label className="block text-sm font-medium text-gray-700 mb-1">Konto</label>
            <select
              value={selectedAccount}
              onChange={(e) => setSelectedAccount(e.target.value)}
              className="w-full border border-gray-300 rounded-lg px-3 py-2 text-sm"
            >
              <option value="">Alle Konten</option>
              {accounts.map((a) => (
                <option key={a.code} value={a.code}>{a.name}</option>
              ))}
            </select>
          </div>
          <div className="flex-1">
            <label className="block text-sm font-medium text-gray-700 mb-1">Investor-ID</label>
            <input
              type="text"
              value={investorFilter}
              onChange={(e) => setInvestorFilter(e.target.value)}
              placeholder="Investor-ID filtern..."
              className="w-full border border-gray-300 rounded-lg px-3 py-2 text-sm"
            />
          </div>
          <Button
            variant="ghost"
            onClick={() => { setSelectedAccount(''); setInvestorFilter(''); }}
          >
            Filter zurücksetzen
          </Button>
        </div>
      </Card>

      {/* Postings Table */}
      <Card>
        <div className="p-4 border-b border-gray-100 flex justify-between items-center">
          <h2 className="text-lg font-semibold">
            Buchungen ({postings.length})
          </h2>
        </div>

        {isLoading ? (
          <div className="p-8 text-center text-gray-500">Daten werden geladen...</div>
        ) : postings.length === 0 ? (
          <div className="p-8 text-center text-gray-500">
            Keine Buchungen gefunden.
            {!selectedAccount && !investorFilter && (
              <p className="mt-2 text-sm">Buchungen werden erzeugt, wenn Investments mit Platform Service Charge abgerechnet werden.</p>
            )}
          </div>
        ) : (
          <div className="overflow-x-auto">
            <table className="w-full">
              <thead className="bg-gray-50">
                <tr>
                  <th className="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase">Datum</th>
                  <th className="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase">Konto</th>
                  <th className="px-4 py-3 text-center text-xs font-medium text-gray-500 uppercase">Seite</th>
                  <th className="px-4 py-3 text-right text-xs font-medium text-gray-500 uppercase">Betrag</th>
                  <th className="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase">Investor</th>
                  <th className="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase">Referenz</th>
                  <th className="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase">Details</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-gray-100">
                {postings.map((p) => (
                  <tr key={p.id} className="hover:bg-gray-50">
                    <td className="px-4 py-3 text-sm text-gray-500">{formatDateTime(p.createdAt)}</td>
                    <td className="px-4 py-3 text-sm font-mono text-gray-700">{p.account}</td>
                    <td className="px-4 py-3 text-center">
                      <Badge variant={p.side === 'credit' ? 'success' : 'danger'}>
                        {p.side === 'credit' ? 'Haben' : 'Soll'}
                      </Badge>
                    </td>
                    <td className={`px-4 py-3 text-sm text-right font-medium ${p.side === 'credit' ? 'text-green-600' : 'text-red-600'}`}>
                      {formatCurrency(p.amount)}
                    </td>
                    <td className="px-4 py-3 text-sm text-gray-700">{p.investorId || '-'}</td>
                    <td className="px-4 py-3 text-sm font-mono text-gray-500">{p.reference}</td>
                    <td className="px-4 py-3 text-sm text-gray-400">
                      {p.metadata?.component === 'net' ? 'Netto-Anteil' :
                       p.metadata?.component === 'vat' ? 'USt.-Anteil' :
                       Object.keys(p.metadata || {}).length > 0
                         ? Object.entries(p.metadata).map(([k, v]) => `${k}: ${v}`).join(', ')
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
