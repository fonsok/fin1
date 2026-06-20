import { useEffect, useMemo, useState } from 'react';
import clsx from 'clsx';
import { Card, CardHeader, AccountStatementEntryBadge } from '../../../components/ui';
import { formatDateTime, formatCurrency } from '../../../utils/format';
import { useTheme } from '../../../context/ThemeContext';
import { listRowStripeClasses } from '../../../utils/tableStriping';
import type { AccountStatementData, AccountStatementEntryItem, InvestorCollectionBillSummary } from '../../../api/admin';
import { InvestorCollectionBillBelegSection } from './InvestorCollectionBillBelegSection';

import { adminBodyStrong, adminEmphasisSoft, adminGlyphFaint, adminMonoHint, adminMuted, adminPrimary, adminSoft, adminTableBodyDivide } from '../../../utils/adminThemeClasses';
import { orientInvestorStatementsForAdminPortal } from '../utils/orientInvestorStatementsForAdminPortal';
type StatementViewMode = 'customer' | 'ledger';

interface Props {
  data: AccountStatementData;
  ledgerData?: AccountStatementData | null;
  userRole: string;
  /** Investor Ledger: Beleg-Aufschlüsselung (getrennt vom saldenwirksamen Kontoauszug). */
  investorCollectionBills?: InvestorCollectionBillSummary[] | null;
}

const ENTRY_TYPE_LABELS: Record<string, string> = {
  deposit: 'Einzahlung',
  withdrawal: 'Auszahlung',
  investment_activate: 'Investment aktiviert',
  investment_return: 'Überweisungsbetrag (Investment)',
  investment_refund: 'Investment Erstattung',
  investment_profit: 'Gewinnausschüttung',
  commission_debit: 'Provision (Abzug)',
  commission_credit: 'Provisionsgutschrift',
  residual_return: 'Restbetrag Investment',
  trade_buy: 'Wertpapierkauf',
  trade_sell: 'Wertpapierverkauf',
  trading_fees: 'Handelsgebühren',
  app_service_charge: 'App-Servicegebühr',
  investment_escrow_reserve: 'Kundenguthaben reserviert',
  investment_escrow_deploy: 'Reserviert → PoolTrade',
  investment_escrow_deployResidualToAvailable: 'Rest nach Zuteilung (verfügbar)',
  investment_escrow_reserveCapitalTradeSplit: 'Kapital-Split (Reservierung)',
  investment_escrow_releaseReserve: 'Reservierung aufgelöst',
  investment_escrow_releaseReservedComplete: 'Reservierung freigegeben',
  investment_escrow_releaseTradingComplete: 'PoolTrade-Bindung aufgelöst',
  investment_escrow_releaseTradingRefund: 'PoolTrade-Rückerstattung',
  investment_escrow_release: 'Reservierung aufgelöst',
};

function entryLabel(type: string): string {
  return ENTRY_TYPE_LABELS[type] || type;
}

export function AccountStatementCard({ data, ledgerData, userRole, investorCollectionBills }: Props) {
  const { theme } = useTheme();
  const isDark = theme === 'dark';
  const isInvestor = String(userRole).toLowerCase() === 'investor';
  const canShowLedger = Boolean(ledgerData && ledgerData.entries.length > 0);

  const investorViews = useMemo(() => {
    if (!isInvestor || !ledgerData) return null;
    return orientInvestorStatementsForAdminPortal(userRole, data, ledgerData);
  }, [isInvestor, userRole, data, ledgerData]);

  const [viewMode, setViewMode] = useState<StatementViewMode>('customer');
  const activeData = useMemo(() => {
    if (investorViews?.customerStatement && investorViews.ledgerStatement) {
      return viewMode === 'ledger' ? investorViews.ledgerStatement : investorViews.customerStatement;
    }
    return viewMode === 'ledger' && ledgerData ? ledgerData : data;
  }, [viewMode, ledgerData, data, investorViews]);

  const investorRowsLookLikeGoB = isInvestor && activeData.entries.some((e) => e.entryType === 'investment_activate');
  const [expanded, setExpanded] = useState(() => activeData.entries.length <= 10);

  useEffect(() => {
    setExpanded(data.entries.length <= 10);
  }, [data, ledgerData]);

  const visibleEntries = expanded ? activeData.entries : activeData.entries.slice(-5);
  const hasHidden = !expanded && activeData.entries.length > 5;

  return (
    <Card>
      <CardHeader title={userRole === 'trader' ? 'Account Balance & Kontoauszug' : 'Cash Balance & Kontoauszug'} />

      {canShowLedger && (
        <div className="mb-4 flex flex-wrap items-center gap-2">
          <span className={clsx('text-xs font-medium uppercase tracking-wide', adminMuted(isDark))}>Ansicht</span>
          <div className={clsx('inline-flex rounded-lg p-0.5', isDark ? 'bg-slate-800' : 'bg-gray-100')}>
            <ViewModeButton
              label={userRole === 'investor' ? 'Kundensicht (wie App)' : 'Kundensicht (netto)'}
              active={viewMode === 'customer'}
              isDark={isDark}
              onClick={() => setViewMode('customer')}
            />
            <ViewModeButton
              label="Ledger (GoB)"
              active={viewMode === 'ledger'}
              isDark={isDark}
              onClick={() => setViewMode('ledger')}
            />
          </div>
        </div>
      )}

      {viewMode === 'ledger' && userRole === 'trader' && (
        <p className={clsx('mb-4 text-sm rounded-md px-3 py-2', isDark ? 'bg-slate-800/80 text-slate-200' : 'bg-slate-100 text-slate-800')}>
          Rohbuchungen aus <span className="font-mono">AccountStatement</span> — Handelsgebühren getrennt nach{' '}
          <span className="font-medium">Kauf</span> und <span className="font-medium">Verkauf</span> (aus Trade-Orders abgeleitet, falls nur eine Sammelzeile gebucht wurde).
          Entspricht nicht der App-Kundensicht (netto).
        </p>
      )}

      {isInvestor && viewMode === 'ledger' && (
        <p className={clsx('mb-4 text-sm rounded-md px-3 py-2', isDark ? 'bg-slate-800/80 text-slate-200' : 'bg-slate-100 text-slate-800')}>
          Parse-<span className="font-mono">AccountStatement</span> (inkl. <span className="font-medium">investment_activate</span>, <span className="font-medium">Provision</span> usw.) plus AVA-Zeilen aus dem App-Ledger ohne Parse-Duplikat:{' '}
          <span className="font-mono">leg=reserve</span> für Investments <span className="font-medium">ohne</span> Aktivierungszeile (sonst Doppel-Soll zu{' '}
          <span className="font-medium">investment_activate</span>) sowie <span className="font-mono">appServiceCharge</span> (App-Servicegebühr brutto auf AVA). Wie in der Kundensicht sind{' '}
          <span className="font-mono">tradeSettlementPoolRelease</span> / <span className="font-mono">tradeSettlementProfitRelease</span> ausgeblendet (Duplikat von{' '}
          <span className="font-medium">investment_return</span>). Liegt ein archivierter Collection Bill vor, werden gebuchte Sammel-<span className="font-mono">trading_fees</span> desselben Trades durch <span className="font-medium">Einzelzeilen</span> laut Beleg ersetzt: <span className="font-medium">Kaufgebühren</span> (Order-/Börsen-/Fremdkosten) zeitlich am <span className="font-mono">investment_activate</span>,{' '}
          <span className="font-medium">Verkaufsgebühren</span> nach der letzten <span className="font-mono">residual_return</span> (sonst <span className="font-mono">investment_return</span> / <span className="font-mono">trade_sell</span>) — so können Aktivierung und Abschluss <span className="font-medium">Tage auseinanderliegen</span>. Ohne Beleg bleibt die Trader-Logik (Gebühren aus Order-Math). Gesamtkaufkosten / Überweisungsbetrag stehen{' '}
          <span className="font-medium">unten im Beleg-Nachweis</span>.
        </p>
      )}

      {isInvestor && viewMode === 'customer' && investorRowsLookLikeGoB && (
        <p className={clsx('mb-4 text-sm rounded-md px-3 py-2', isDark ? 'bg-amber-950/40 text-amber-200' : 'bg-amber-50 text-amber-900')}>
          <span className="font-medium">Hinweis:</span> In der Kundensicht erscheinen Zeilen wie „Investment aktiviert“ — das entspricht üblicherweise der Rohbuchung (GoB), nicht der App-Merge-Ansicht.
          Bitte Parse Cloud <span className="font-mono">getUserDetails</span> / <span className="font-mono">loadAccountStatementAndWalletControls</span> prüfen (Investor-Zweig) und Browser-Cache leeren.
        </p>
      )}

      {isInvestor && viewMode === 'customer' && !investorRowsLookLikeGoB && (
        <p className={clsx('mb-4 text-sm', adminMuted(isDark))}>
          Gleiche Merge-Logik wie Cloud <span className="font-mono">getAccountStatement</span> (Investor):{' '}
          <span className="font-mono">AccountStatement</span> plus relevante AVA-Escrow-Zeilen aus dem App-Ledger; interne Zeilen wie{' '}
          <span className="font-medium">investment_activate</span> entfallen. Zusätzlich werden die rein buchhalterischen AVA-Splits{' '}
          <span className="font-mono">tradeSettlementPoolRelease</span> / <span className="font-mono">tradeSettlementProfitRelease</span> ausgeblendet — sie spiegeln nur die Aufteilung der bereits sichtbaren{' '}
          <span className="font-medium">investment_return</span>-Zeile.
        </p>
      )}

      {viewMode === 'customer' && userRole === 'trader' && (
        <p className={clsx('mb-4 text-sm', adminMuted(isDark))}>
          Kundensicht: ein Netto-Betrag pro Kauf/Verkauf; Gebühren auf dem Beleg. Provisionsgutschriften bleiben eigene Zeilen.
        </p>
      )}

      {activeData.timelineTruncated && (
        <p className={clsx('mb-4 text-sm rounded-md px-3 py-2', isDark ? 'bg-amber-950/40 text-amber-200' : 'bg-amber-50 text-amber-900')}>
          Ältere Buchungen können fehlen (Server-Limit). App-Kontoauszug und Admin-Zahlen basieren auf den geladenen Zeilen.
        </p>
      )}

      {/* Summary boxes */}
      <div className="grid grid-cols-2 md:grid-cols-5 gap-4 mb-6">
        <SummaryBox label="Anfangssaldo" value={formatCurrency(activeData.initialBalance)} isDark={isDark} />
        <SummaryBox label="Gutschriften" value={formatCurrency(activeData.totalCredits)} isDark={isDark} color="green" />
        <SummaryBox label="Belastungen" value={formatCurrency(activeData.totalDebits)} isDark={isDark} color="red" />
        <SummaryBox label="Nettoveränderung" value={formatCurrency(activeData.netChange)} isDark={isDark} color={activeData.netChange >= 0 ? 'green' : 'red'} />
        <SummaryBox label="Aktueller Saldo" value={formatCurrency(activeData.closingBalance)} isDark={isDark} color="blue" highlight />
      </div>

      {/* Statement table */}
      {activeData.entries.length > 0 ? (
        <>
          {hasHidden && (
            <button
              onClick={() => setExpanded(true)}
              className={clsx(
                'mb-3 text-sm font-medium px-3 py-1.5 rounded-md transition-colors',
                isDark ? 'text-blue-400 hover:bg-slate-800' : 'text-blue-600 hover:bg-blue-50',
              )}
            >
              Alle {activeData.entries.length} Einträge anzeigen
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
              <tbody className={adminTableBodyDivide(isDark)}>
                {/* Opening balance row */}
                <tr className={clsx(isDark ? 'bg-slate-900/40' : 'bg-gray-50')}>
                  <td className={clsx('px-3 py-2', adminMuted(isDark))} colSpan={5}>
                    <span className="italic">Anfangssaldo</span>
                  </td>
                  <td className={clsx('px-3 py-2 text-right font-medium tabular-nums', adminBodyStrong(isDark))}>
                    {formatCurrency(activeData.initialBalance)}
                  </td>
                  <td />
                </tr>
                {visibleEntries.map((entry, idx) => (
                  <StatementRow key={entry.objectId} entry={entry} idx={idx} isDark={isDark} />
                ))}
              </tbody>
            </table>
          </div>
          {expanded && activeData.entries.length > 10 && (
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
        <p className={clsx('text-sm py-4', adminMuted(isDark))}>
          Keine Kontoauszugseinträge vorhanden.
        </p>
      )}

      {isInvestor && viewMode === 'ledger' && investorCollectionBills && investorCollectionBills.length > 0 && (
        <InvestorCollectionBillBelegSection bills={investorCollectionBills} isDark={isDark} />
      )}

    </Card>
  );
}

function StatementRow({ entry, idx, isDark }: { entry: AccountStatementEntryItem; idx: number; isDark: boolean }) {
  const isDebit = entry.amount < 0;
  const amountColor = isDebit
    ? (isDark ? 'text-red-400' : 'text-red-600')
    : (isDark ? 'text-emerald-400' : 'text-green-600');
  const belegRef = entry.referenceDocumentNumber || entry.referenceDocumentId || '\u2014';

  return (
    <tr className={listRowStripeClasses(isDark, idx, { hover: true })}>
      <td className={clsx('px-3 py-2 whitespace-nowrap text-xs', adminSoft(isDark))}>
        {formatDateTime(entry.createdAt)}
      </td>
      <td className={clsx('px-3 py-2', adminEmphasisSoft(isDark))}>
        <div>{entry.description}</div>
        {entry.tradeNumber != null && (
          <div className={clsx('text-xs', adminMuted(isDark))}>
            Trade #{entry.tradeNumber}
          </div>
        )}
      </td>
      <td className="px-3 py-2">
        <AccountStatementEntryBadge entryType={entry.entryType}>
          {entryLabel(entry.entryType)}
        </AccountStatementEntryBadge>
      </td>
      <td className={clsx('px-3 py-2 text-right tabular-nums font-medium', isDebit ? amountColor : adminGlyphFaint(isDark))}>
        {isDebit ? formatCurrency(Math.abs(entry.amount)) : '\u2014'}
      </td>
      <td className={clsx('px-3 py-2 text-right tabular-nums font-medium', !isDebit ? amountColor : adminGlyphFaint(isDark))}>
        {!isDebit ? formatCurrency(entry.amount) : '\u2014'}
      </td>
      <td className={clsx('px-3 py-2 text-right tabular-nums font-medium', adminPrimary(isDark))}>
        {formatCurrency(entry.balanceAfter)}
      </td>
      <td className={clsx('px-3 py-2 text-xs font-mono', adminMuted(isDark))}>
        {belegRef}
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
  const bgClasses = clsx(
    highlight
      ? isDark
        ? 'bg-blue-950/40 border border-blue-700/50 ring-1 ring-blue-700/30'
        : 'bg-blue-50 border border-blue-200'
      : isDark
        ? 'bg-slate-900/60 border border-slate-700'
        : 'bg-gray-50 border border-gray-200',
  );

  return (
    <div className={clsx('text-center p-3 rounded-lg', bgClasses)}>
      <p className={clsx('text-xs mb-1', adminMuted(isDark))}>{label}</p>
      <p className={clsx('text-lg font-bold tabular-nums', color ? colorClasses[color] : (adminPrimary(isDark)))}>
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
        adminMonoHint(isDark),
      )}
    >
      {children}
    </th>
  );
}

function ViewModeButton({
  label,
  active,
  isDark,
  onClick,
}: {
  label: string;
  active: boolean;
  isDark: boolean;
  onClick: () => void;
}) {
  return (
    <button
      type="button"
      onClick={onClick}
      className={clsx(
        'px-3 py-1.5 text-xs font-medium rounded-md transition-colors',
        active
          ? isDark
            ? 'bg-slate-700 text-white shadow-sm ring-2 ring-sky-400 ring-offset-2 ring-offset-slate-900'
            : 'bg-white text-gray-900 shadow-sm ring-2 ring-fin1-primary ring-offset-2 ring-offset-white'
          : isDark
            ? 'text-slate-300 hover:text-white'
            : 'text-gray-600 hover:text-gray-900',
      )}
    >
      {label}
    </button>
  );
}
