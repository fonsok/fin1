import clsx from 'clsx';
import type { InvestorCollectionBillFeeLine, InvestorCollectionBillSummary } from '../../../api/admin';
import { formatCurrency, formatDateTime } from '../../../utils/format';
import { adminBodyStrong, adminMuted, adminPrimary, adminSoft, adminTableBodyDivide } from '../../../utils/adminThemeClasses';

const FEE_LABELS: Record<string, string> = {
  orderFee: 'Ordergebühr',
  exchangeFee: 'Börsenplatzgebühr',
  foreignCosts: 'Fremdkostenpauschale',
  totalFees: 'Gebühren gesamt',
};

function feeLabel(key: string): string {
  return FEE_LABELS[key] || key;
}

function feesForSide(components: InvestorCollectionBillFeeLine[], side: 'buy' | 'sell') {
  return components.filter((f) => f.side === side && f.key !== 'totalFees' && f.amount > 0);
}

function sumFees(components: InvestorCollectionBillFeeLine[], side: 'buy' | 'sell') {
  return feesForSide(components, side).reduce((s, f) => s + f.amount, 0);
}

interface Props {
  bills: InvestorCollectionBillSummary[];
  isDark: boolean;
}

/** Beleg-Nachweis (SSOT metadata) — getrennt vom saldenwirksamen Ledger (GoB). */
export function InvestorCollectionBillBelegSection({ bills, isDark }: Props) {
  if (!bills.length) return null;

  return (
    <section className="mt-8 border-t pt-6" aria-labelledby="cb-beleg-heading">
      <h3
        id="cb-beleg-heading"
        className={clsx('text-sm font-semibold mb-1', adminPrimary(isDark))}
      >
        Collection Bills (Beleg-Nachweis)
      </h3>
      <p className={clsx('text-sm mb-4 max-w-3xl', adminMuted(isDark))}>
        Aufschlüsselung aus archiviertem <span className="font-mono">Document</span> Typ{' '}
        <span className="font-mono">investorCollectionBill</span> — <span className="font-medium">kein Ersatz</span> für
        Kontoauszugszeilen oben. Jede Zeile im Ledger (GoB) mit Betrag verändert den Saldo; die Belegpositionen dienen
        dem Abgleich mit dem PDF/Metadaten (Order-/Börsen-/Fremdkosten, Gesamtkaufkosten, Überweisungsbetrag).
      </p>

      <div className="space-y-4">
        {bills.map((bill) => (
          <BillCard key={bill.documentId} bill={bill} isDark={isDark} />
        ))}
      </div>
    </section>
  );
}

function BillCard({ bill, isDark }: { bill: InvestorCollectionBillSummary; isDark: boolean }) {
  const beleg = bill.documentNumber || bill.documentId;
  const buyFees = feesForSide(bill.feeComponents, 'buy');
  const sellFees = feesForSide(bill.feeComponents, 'sell');
  const buyFeeSum = sumFees(bill.feeComponents, 'buy');
  const sellFeeSum = sumFees(bill.feeComponents, 'sell');

  return (
    <div
      className={clsx(
        'rounded-lg border overflow-hidden',
        isDark ? 'border-slate-700 bg-slate-900/40' : 'border-gray-200 bg-gray-50/80',
      )}
    >
      <div className={clsx('px-4 py-3 flex flex-wrap items-baseline gap-x-4 gap-y-1 border-b', isDark ? 'border-slate-700' : 'border-gray-200')}>
        <span className={clsx('font-mono text-sm font-medium', adminBodyStrong(isDark))}>{beleg}</span>
        <span className={clsx('text-xs', adminMuted(isDark))}>{formatDateTime(bill.createdAt)}</span>
        {bill.tradeNumber != null && (
          <span className={clsx('text-xs', adminMuted(isDark))}>Trade #{bill.tradeNumber}</span>
        )}
      </div>

      <div className="px-4 py-3 grid md:grid-cols-2 gap-6">
        <FeeBlock title="Buy Fees (Kauf)" fees={buyFees} feeSum={buyFeeSum} isDark={isDark} />
        <FeeBlock title="Sell Fees (Verkauf)" fees={sellFees} feeSum={sellFeeSum} isDark={isDark} />
      </div>

      <div
        className={clsx(
          'px-4 py-3 grid grid-cols-2 sm:grid-cols-3 lg:grid-cols-5 gap-3 text-sm border-t',
          isDark ? 'border-slate-700 bg-slate-950/30' : 'border-gray-200 bg-white/60',
        )}
      >
        <SummaryCell label="Gesamtkaufkosten" value={bill.totalBuyCost} isDark={isDark} />
        {bill.buy.costBasisPerShare != null && bill.buy.costBasisPerShare > 0 && (
          <SummaryCell
            label="Einstand / Bezug (pro Stück)"
            value={bill.buy.costBasisPerShare}
            isDark={isDark}
          />
        )}
        <SummaryCell label="Netto-Verkauf" value={bill.netSellAmount} isDark={isDark} />
        {bill.sell.netSellPricePerShare != null && bill.sell.netSellPricePerShare > 0 && (
          <SummaryCell
            label="Verkauf netto (pro Stück)"
            value={bill.sell.netSellPricePerShare}
            isDark={isDark}
          />
        )}
        <SummaryCell label="Provision" value={bill.commission} isDark={isDark} />
        <SummaryCell label="Überweisungsbetrag" value={bill.transferAmount} isDark={isDark} highlight />
      </div>
    </div>
  );
}

function FeeBlock({
  title,
  fees,
  feeSum,
  isDark,
}: {
  title: string;
  fees: InvestorCollectionBillFeeLine[];
  feeSum: number;
  isDark: boolean;
}) {
  return (
    <div>
      <p className={clsx('text-xs font-medium uppercase tracking-wide mb-2', adminMuted(isDark))}>{title}</p>
      {fees.length === 0 ? (
        <p className={clsx('text-sm', adminSoft(isDark))}>—</p>
      ) : (
        <table className="w-full text-sm">
          <tbody className={adminTableBodyDivide(isDark)}>
            {fees.map((f) => (
              <tr key={`${f.side}-${f.key}`}>
                <td className={clsx('py-1 pr-2', adminSoft(isDark))}>{feeLabel(f.key)}</td>
                <td className={clsx('py-1 text-right tabular-nums font-medium', adminPrimary(isDark))}>
                  {formatCurrency(f.amount)}
                </td>
              </tr>
            ))}
            <tr className={clsx(isDark ? 'border-t border-slate-700' : 'border-t border-gray-200')}>
              <td className={clsx('py-1.5 pr-2 font-medium', adminBodyStrong(isDark))}>Summe</td>
              <td className={clsx('py-1.5 text-right tabular-nums font-semibold', adminPrimary(isDark))}>
                {formatCurrency(feeSum)}
              </td>
            </tr>
          </tbody>
        </table>
      )}
    </div>
  );
}

function SummaryCell({
  label,
  value,
  isDark,
  highlight,
}: {
  label: string;
  value: number;
  isDark: boolean;
  highlight?: boolean;
}) {
  return (
    <div>
      <p className={clsx('text-xs mb-0.5', adminMuted(isDark))}>{label}</p>
      <p
        className={clsx(
          'tabular-nums font-semibold',
          highlight
            ? isDark
              ? 'text-emerald-400'
              : 'text-green-700'
            : adminPrimary(isDark),
        )}
      >
        {formatCurrency(value)}
      </p>
    </div>
  );
}
