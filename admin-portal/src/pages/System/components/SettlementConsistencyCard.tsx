import clsx from 'clsx';
import type { ReactNode } from 'react';
import { Badge, Card } from '../../../components/ui';
import { formatDateTime } from '../../../utils/format';
import {
  listRowStripeClasses,
  tableBodyDivideClasses,
  tableHeaderCellTextClasses,
  tableTheadSurfaceClasses,
} from '../../../utils/tableStriping';

type HealthStatus = 'healthy' | 'degraded' | 'down' | 'unknown';

export type SettlementConsistencyStatus = {
  overall: HealthStatus;
  checkedTrades: number;
  checkedInvestments: number;
  mismatchCount: number;
  epsilon: number;
  checkedAt: string;
  mismatchSamples: Array<{
    tradeId: string;
    tradeNumber?: number | string;
    investmentId: string;
    investorId: string;
    expected: { grossReturn: number; commission: number; taxTotal: number };
    actual: { grossReturn: number; commission: number; taxTotal: number };
    diff: { grossReturn: number; commission: number; taxTotal: number };
  }>;
};

type Props = {
  isDark: boolean;
  settlementConsistency: SettlementConsistencyStatus;
  settlementConsistencyLoading: boolean;
  renderStatusBadge: (status: HealthStatus) => ReactNode;
};

export function SettlementConsistencyCard({
  isDark,
  settlementConsistency,
  settlementConsistencyLoading,
  renderStatusBadge,
}: Props) {
  return (
    <Card className={clsx('border', settlementConsistency.overall === 'healthy'
      ? (isDark ? 'border-emerald-700 bg-emerald-950/20' : 'border-green-200 bg-green-50')
      : (isDark ? 'border-amber-700 bg-amber-950/20' : 'border-yellow-200 bg-yellow-50'))}>
      <div className="flex items-start justify-between gap-4 flex-col md:flex-row">
        <div>
          <h3 className="text-md font-semibold">Settlement Delta/Completion Konsistenz</h3>
          <p className={clsx('text-sm mt-1', isDark ? 'text-slate-300' : 'text-gray-700')}>
            Prueft pro Completed Trade die Invariante: Teil-Sell-Deltas + Completion-Rest entsprechen der erwarteten Endabrechnung.
          </p>
          <p className={clsx('text-xs mt-1', isDark ? 'text-slate-400' : 'text-gray-600')}>
            Letzte Pruefung: {formatDateTime(settlementConsistency.checkedAt)} · Toleranz: ±{settlementConsistency.epsilon.toFixed(2)}
          </p>
        </div>
        <div className="flex items-center gap-3">
          {settlementConsistencyLoading ? <Badge variant="neutral">Laedt…</Badge> : renderStatusBadge(settlementConsistency.overall)}
        </div>
      </div>

      <div className="mt-4 grid grid-cols-1 md:grid-cols-3 gap-3">
        <div className={clsx('rounded-md border p-3', isDark ? 'border-slate-700 bg-slate-900/40' : 'border-gray-200 bg-white')}>
          <p className="text-xs text-gray-500">Gepruefte Trades</p>
          <p className="text-lg font-semibold">{settlementConsistency.checkedTrades}</p>
        </div>
        <div className={clsx('rounded-md border p-3', isDark ? 'border-slate-700 bg-slate-900/40' : 'border-gray-200 bg-white')}>
          <p className="text-xs text-gray-500">Gepruefte Investments</p>
          <p className="text-lg font-semibold">{settlementConsistency.checkedInvestments}</p>
        </div>
        <div className={clsx('rounded-md border p-3', settlementConsistency.mismatchCount === 0
          ? (isDark ? 'border-emerald-700 bg-emerald-950/20' : 'border-green-200 bg-green-50')
          : (isDark ? 'border-red-700 bg-red-950/20' : 'border-red-200 bg-red-50'))}>
          <p className="text-xs text-gray-500">Mismatches</p>
          <p className={clsx('text-lg font-semibold', settlementConsistency.mismatchCount === 0 ? 'text-green-500' : 'text-red-500')}>
            {settlementConsistency.mismatchCount}
          </p>
        </div>
      </div>

      {settlementConsistency.mismatchSamples.length > 0 && (
        <div className="mt-4 overflow-x-auto">
          <table className="w-full">
            <thead className={tableTheadSurfaceClasses(isDark)}>
              <tr>
                <th className={clsx('px-3 py-2 text-left text-xs font-medium uppercase', tableHeaderCellTextClasses(isDark))}>Trade</th>
                <th className={clsx('px-3 py-2 text-left text-xs font-medium uppercase', tableHeaderCellTextClasses(isDark))}>Investment</th>
                <th className={clsx('px-3 py-2 text-left text-xs font-medium uppercase', tableHeaderCellTextClasses(isDark))}>Diff Return</th>
                <th className={clsx('px-3 py-2 text-left text-xs font-medium uppercase', tableHeaderCellTextClasses(isDark))}>Diff Provision</th>
                <th className={clsx('px-3 py-2 text-left text-xs font-medium uppercase', tableHeaderCellTextClasses(isDark))}>Diff Steuer</th>
              </tr>
            </thead>
            <tbody className={tableBodyDivideClasses(isDark)}>
              {settlementConsistency.mismatchSamples.slice(0, 8).map((sample, index) => (
                <tr key={`${sample.tradeId}-${sample.investmentId}`} className={listRowStripeClasses(isDark, index)}>
                  <td className="px-3 py-2 text-sm">{sample.tradeNumber ? `#${sample.tradeNumber}` : sample.tradeId}</td>
                  <td className="px-3 py-2 text-sm">{sample.investmentId}</td>
                  <td className={clsx('px-3 py-2 text-sm', Math.abs(sample.diff.grossReturn) <= settlementConsistency.epsilon ? '' : 'text-red-500')}>
                    {sample.diff.grossReturn.toFixed(2)}
                  </td>
                  <td className={clsx('px-3 py-2 text-sm', Math.abs(sample.diff.commission) <= settlementConsistency.epsilon ? '' : 'text-red-500')}>
                    {sample.diff.commission.toFixed(2)}
                  </td>
                  <td className={clsx('px-3 py-2 text-sm', Math.abs(sample.diff.taxTotal) <= settlementConsistency.epsilon ? '' : 'text-red-500')}>
                    {sample.diff.taxTotal.toFixed(2)}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
    </Card>
  );
}
