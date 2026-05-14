import clsx from 'clsx';
import { Badge, getStatusVariant } from '../../../components/ui';
import { formatCurrency, getStatusDisplay } from '../../../utils/format';
import { listRowStripeClasses } from '../../../utils/tableStriping';
import type { InvestmentItem } from '../../../api/admin';

import { adminPrimary, adminSoft, adminStrong } from '../../../utils/adminThemeClasses';
interface Props {
  title: string;
  items: InvestmentItem[];
  isDark: boolean;
}

function extractShortId(id: string): string {
  return id.length > 8 ? id.slice(0, 8) : id;
}

export function InvestmentTable({ title, items, isDark }: Props) {
  return (
    <div>
      <h4 className={clsx('font-medium mb-3', adminStrong(isDark))}>
        {title}
      </h4>
      <div className="overflow-x-auto rounded-lg border border-transparent">
        <table className="w-full text-sm">
          <thead className={clsx(isDark ? 'bg-slate-800/90' : 'bg-gray-100')}>
            <tr>
              <Th isDark={isDark} align="left">Investment Nr.</Th>
              <Th isDark={isDark} align="left">Trader</Th>
              <Th isDark={isDark} align="left">Trade Nr.</Th>
              <Th isDark={isDark} align="right">InvestAmount (&euro;)</Th>
              <Th isDark={isDark} align="right">Profit (&euro;)</Th>
              <Th isDark={isDark} align="right">Return (%)</Th>
              <Th isDark={isDark} align="left">Beleg / Rechnung</Th>
              <Th isDark={isDark} align="center">Status</Th>
            </tr>
          </thead>
          <tbody className={clsx(isDark ? 'divide-y divide-slate-700' : 'divide-y divide-gray-100')}>
            {items.map((inv, idx) => {
              const profit = inv.profit || 0;
              const returnPct = inv.profitPercentage ?? 0;
              const profitColor = profit >= 0
                ? (isDark ? 'text-emerald-400' : 'text-green-600')
                : (isDark ? 'text-red-400' : 'text-red-600');

              return (
                <tr key={inv.objectId} className={listRowStripeClasses(isDark, idx, { hover: true })}>
                  <td className={clsx('px-3 py-2.5 font-mono text-xs', isDark ? 'text-fin1-primary' : 'text-fin1-primary')}>
                    {extractShortId(inv.objectId)}
                  </td>
                  <td className={clsx('px-3 py-2.5', isDark ? 'text-slate-200' : 'text-gray-800')}>
                    {inv.traderName || inv.traderId}
                  </td>
                  <td className={clsx('px-3 py-2.5 font-mono', isDark ? 'text-slate-200' : 'text-gray-800')}>
                    {inv.tradeNumber != null ? String(inv.tradeNumber).padStart(3, '0') : '\u2014'}
                  </td>
                  <td className={clsx('px-3 py-2.5 text-right tabular-nums', adminPrimary(isDark))}>
                    {formatCurrency(inv.amount)}
                  </td>
                  <td className={clsx('px-3 py-2.5 text-right tabular-nums font-medium', profitColor)}>
                    {profit !== 0 ? formatCurrency(profit) : '\u2014'}
                  </td>
                  <td className={clsx('px-3 py-2.5 text-right tabular-nums', profitColor)}>
                    {returnPct !== 0 ? `${returnPct.toFixed(2)}` : '\u2014'}
                  </td>
                  <td className={clsx('px-3 py-2.5 text-xs', adminSoft(isDark))}>
                    {inv.docRef || '\u2014'}
                  </td>
                  <td className="px-3 py-2.5 text-center">
                    <Badge variant={getStatusVariant(inv.status)}>
                      {getStatusDisplay(inv.status)}
                    </Badge>
                  </td>
                </tr>
              );
            })}
          </tbody>
        </table>
      </div>
    </div>
  );
}

function Th({ children, isDark, align }: { children: React.ReactNode; isDark: boolean; align: string }) {
  return (
    <th
      className={clsx(
        'px-3 py-2 text-xs font-medium uppercase tracking-wide whitespace-nowrap',
        align === 'right' ? 'text-right' : align === 'center' ? 'text-center' : 'text-left',
        isDark ? 'text-slate-400' : 'text-gray-600',
      )}
    >
      {children}
    </th>
  );
}
