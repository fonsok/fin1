import clsx from 'clsx';
import { Card, CardHeader } from '../../../components/ui';
import { formatCurrency } from '../../../utils/format';
import type { InvestorOutcomeHighlights } from '../../../api/admin';
import { StatBox } from './UserShared';
import { adminMuted } from '../../../utils/adminThemeClasses';

interface Props {
  data: InvestorOutcomeHighlights;
  isDark: boolean;
}

export function InvestorOutcomeHighlightsCard({ data, isDark }: Props) {
  return (
    <Card>
      <CardHeader title="Investor-Kontoauszug Kurzauswertung" />
      <div className="grid grid-cols-2 md:grid-cols-3 gap-4 mb-4">
        <StatBox
          label="Gewinne / Rückflüsse / Rest"
          value={formatCurrency(data.sumProfitReturnsResiduals)}
          color={data.sumProfitReturnsResiduals >= 0 ? 'green' : 'red'}
        />
        <StatBox label="Gebühren (netto)" value={formatCurrency(data.sumFees)} color="red" />
        <StatBox label="Einbehaltene Steuern" value={formatCurrency(data.sumTaxesWithheld)} color="red" />
        <StatBox
          label="Trade-Cash & Ordergebühren"
          value={formatCurrency(data.sumTradeCashAndOrderFees)}
          color="gray"
        />
        <StatBox
          label="Ein- / Auszahlungen"
          value={formatCurrency(data.sumDepositsWithdrawals)}
          color={data.sumDepositsWithdrawals >= 0 ? 'green' : 'red'}
        />
      </div>
      <p className={clsx('text-xs leading-relaxed', adminMuted(isDark))}>{data.disclaimer}</p>
    </Card>
  );
}
