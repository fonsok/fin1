import { useState } from 'react';
import clsx from 'clsx';
import { Card, CardHeader, Badge } from '../../../components/ui';
import { formatDateTime, formatCurrency } from '../../../utils/format';
import { useTheme } from '../../../context/ThemeContext';
import { listRowStripeClasses } from '../../../utils/tableStriping';
import type { AccountStatementData, AccountStatementEntryItem } from '../../../api/admin';

interface Props {
  data: AccountStatementData;
  userRole: string;
}

const ENTRY_TYPE_LABELS: Record<string, string> = {
  deposit: 'Einzahlung',
  withdrawal: 'Auszahlung',
  investment_activate: 'Investment aktiviert',
  investment_return: 'Investment Rückzahlung',
  investment_refund: 'Investment Erstattung',
  investment_profit: 'Gewinnausschüttung',
  commission_debit: 'Provision (Abzug)',
  commission_credit: 'Provisionsgutschrift',
  residual_return: 'Restbetrag Rückgabe',
  trade_buy: 'Wertpapierkauf',
  trade_sell: 'Wertpapierverkauf',
  trading_fees: 'Handelsgebühren',
};

function entryLabel(type: string): string {
  return ENTRY_TYPE_LABELS[type] || type;
}

function entryBadgeVariant(type: string): 'success' | 'danger' | 'warning' | 'neutral' | 'info' {
  if (type.includes('profit') || type === 'commission_credit' || type === 'deposit' || type === 'investment_return' || type === 'residual_return' || type === 'trade_sell') return 'success';
  if (type.includes('debit') || type === 'withdrawal' || type === 'trade_buy' || type === 'trading_fees') return 'danger';
  if (type === 'investment_activate') return 'warning';
  return 'neutral';
}

export function AccountStatementCard({ data, userRole }: Props) {
  const { theme } = useTheme();
  const isDark = theme === 'dark';
  const [expanded, setExpanded] = useState(data.entries.length <= 10);

  const visibleEntries = expanded ? data.entries : data.entries.slice(-5);
  const hasHidden = !expanded && data.entries.length > 5;

  return (
    <Card>
      <CardHeader title={userRole === 'trader' ? 'Account Balance & Kontoauszug' : 'Cash Balance & Kontoauszug'} />

      {/* Summary boxes */}
      <div className="grid grid-cols-2 md:grid-cols-5 gap-4 mb-6">
        <SummaryBox label="Anfangssaldo" value={formatCurrency(data.initialBalance)} isDark={isDark} />
        <SummaryBox label="Gutschriften" value={formatCurrency(data.totalCredits)} isDark={isDark} color="green" />
        <SummaryBox label="Belastungen" value={formatCurrency(data.totalDebits)} isDark={isDark} color="red" />
        <SummaryBox label="Nettoveränderung" value={formatCurrency(data.netChange)} isDark={isDark} color={data.netChange >= 0 ? 'green' : 'red'} />
        <SummaryBox label="Aktueller Saldo" value={formatCurrency(data.closingBalance)} isDark={isDark} color="blue" highlight />
      </div>

      {/* Statement table */}
      {data.entries.length > 0 ? (
        <>
          {hasHidden && (
            <button
              onClick={() => setExpanded(true)}
              className={clsx(
                'mb-3 text-sm font-medium px-3 py-1.5 rounded-md transition-colors',
                isDark ? 'text-blue-400 hover:bg-slate-800' : 'text-blue-600 hover:bg-blue-50',
              )}
            >
              Alle {data.entries.length} Einträge anzeigen
            </button>
          )}
          <div className="overflow-x-auto rounded-lg border border-transparent">
            <table className="w-full text-sm">
              <thead className={clsx(isDark ? 'bg-slate-800/90' : 'bg-gray-100')}>
                <tr>
                  <Th isDark={isDark} align="left">Datum</Th>
                  <Th isDark={isDark} align="left">Buchungstext</Th>
                  <Th isDark={isDark} align="left">Typ</Th>
                  <Th isDark={isDark} align="right">Belastung</Th>
                  <Th isDark={isDark} align="right">Gutschrift</Th>
                  <Th isDark={isDark} align="right">Saldo</Th>
                  <Th isDark={isDark} align="left">Beleg</Th>
                </tr>
              </thead>
              <tbody className={clsx(isDark ? 'divide-y divide-slate-700' : 'divide-y divide-gray-100')}>
                {/* Opening balance row */}
                <tr className={clsx(isDark ? 'bg-slate-900/40' : 'bg-gray-50')}>
                  <td className={clsx('px-3 py-2', isDark ? 'text-slate-400' : 'text-gray-500')} colSpan={5}>
                    <span className="italic">Anfangssaldo</span>
                  </td>
                  <td className={clsx('px-3 py-2 text-right font-medium tabular-nums', isDark ? 'text-slate-200' : 'text-gray-900')}>
                    {formatCurrency(data.initialBalance)}
                  </td>
                  <td />
                </tr>
                {visibleEntries.map((entry, idx) => (
                  <StatementRow key={entry.objectId} entry={entry} idx={idx} isDark={isDark} />
                ))}
              </tbody>
            </table>
          </div>
          {expanded && data.entries.length > 10 && (
            <button
              onClick={() => setExpanded(false)}
              className={clsx(
                'mt-3 text-sm font-medium px-3 py-1.5 rounded-md transition-colors',
                isDark ? 'text-blue-400 hover:bg-slate-800' : 'text-blue-600 hover:bg-blue-50',
              )}
            >
              Weniger anzeigen
            </button>
          )}
        </>
      ) : (
        <p className={clsx('text-sm py-4', isDark ? 'text-slate-400' : 'text-gray-500')}>
          Keine Kontoauszugseinträge vorhanden.
        </p>
      )}
    </Card>
  );
}

function StatementRow({ entry, idx, isDark }: { entry: AccountStatementEntryItem; idx: number; isDark: boolean }) {
  const isDebit = entry.amount < 0;
  const amountColor = isDebit
    ? (isDark ? 'text-red-400' : 'text-red-600')
    : (isDark ? 'text-emerald-400' : 'text-green-600');

  return (
    <tr className={listRowStripeClasses(isDark, idx, { hover: true })}>
      <td className={clsx('px-3 py-2 whitespace-nowrap text-xs', isDark ? 'text-slate-300' : 'text-gray-600')}>
        {formatDateTime(entry.createdAt)}
      </td>
      <td className={clsx('px-3 py-2', isDark ? 'text-slate-200' : 'text-gray-800')}>
        <div>{entry.description}</div>
        {entry.tradeNumber != null && (
          <div className={clsx('text-xs', isDark ? 'text-slate-400' : 'text-gray-500')}>
            Trade #{entry.tradeNumber}
          </div>
        )}
      </td>
      <td className="px-3 py-2">
        <Badge variant={entryBadgeVariant(entry.entryType)}>
          {entryLabel(entry.entryType)}
        </Badge>
      </td>
      <td className={clsx('px-3 py-2 text-right tabular-nums font-medium', isDebit ? amountColor : (isDark ? 'text-slate-500' : 'text-gray-300'))}>
        {isDebit ? formatCurrency(Math.abs(entry.amount)) : '\u2014'}
      </td>
      <td className={clsx('px-3 py-2 text-right tabular-nums font-medium', !isDebit ? amountColor : (isDark ? 'text-slate-500' : 'text-gray-300'))}>
        {!isDebit ? formatCurrency(entry.amount) : '\u2014'}
      </td>
      <td className={clsx('px-3 py-2 text-right tabular-nums font-medium', isDark ? 'text-slate-100' : 'text-gray-900')}>
        {formatCurrency(entry.balanceAfter)}
      </td>
      <td className={clsx('px-3 py-2 text-xs font-mono', isDark ? 'text-slate-400' : 'text-gray-500')}>
        {entry.referenceDocumentId || '\u2014'}
      </td>
    </tr>
  );
}

function SummaryBox({ label, value, isDark, color, highlight }: {
  label: string;
  value: string;
  isDark: boolean;
  color?: 'green' | 'red' | 'blue';
  highlight?: boolean;
}) {
  const colorClasses = {
    green: isDark ? 'text-emerald-400' : 'text-green-600',
    red: isDark ? 'text-red-400' : 'text-red-600',
    blue: isDark ? 'text-blue-400' : 'text-blue-600',
  };
  const bgClasses = highlight
    ? (isDark ? 'bg-blue-950/40 border border-blue-700/50 ring-1 ring-blue-700/30' : 'bg-blue-50 border border-blue-200')
    : (isDark ? 'bg-slate-900/60 border border-slate-700' : 'bg-gray-50 border border-gray-200');

  return (
    <div className={clsx('text-center p-3 rounded-lg', bgClasses)}>
      <p className={clsx('text-xs mb-1', isDark ? 'text-slate-400' : 'text-gray-500')}>{label}</p>
      <p className={clsx('text-lg font-bold tabular-nums', color ? colorClasses[color] : (isDark ? 'text-slate-100' : 'text-gray-900'))}>
        {value}
      </p>
    </div>
  );
}

function Th({ children, isDark, align }: { children: React.ReactNode; isDark: boolean; align: string }) {
  return (
    <th
      className={clsx(
        'px-3 py-2 text-xs font-medium uppercase tracking-wide whitespace-nowrap',
        align === 'right' ? 'text-right' : 'text-left',
        isDark ? 'text-slate-400' : 'text-gray-600',
      )}
    >
      {children}
    </th>
  );
}
