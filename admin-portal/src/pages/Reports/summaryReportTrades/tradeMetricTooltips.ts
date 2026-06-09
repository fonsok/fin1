import { formatCurrency } from '../../../utils/format';
import type { SummaryReportTradeRow } from './types';

export const TRADE_RETURN_HEADER_TOOLTIP =
  'Rendite in % vom Backend-Snapshot (tradeLegEconomics / resolveLegReturnPercentage).';

export const TRADE_PROFIT_HEADER_TOOLTIP =
  'Gewinn vom Backend-Snapshot (Trader-Leg: totalBuyCost-Basis, P/L aus Domain-SSOT).';

/** List row: nur Backend-Feld returnPercentage — keine Frontend-Neuberechnung. */
export function tradeReturnPercentage(trade: SummaryReportTradeRow): number {
  return Number.isFinite(trade.returnPercentage) ? trade.returnPercentage : 0;
}

export function tradeReturnCellTooltip(trade: SummaryReportTradeRow): string {
  const pct = tradeReturnPercentage(trade);
  if (trade.buyAmount <= 0) {
    return `Rendite ${pct.toFixed(2)} % (Snapshot; kein Kaufvolumen in der Zeile).`;
  }
  return `Rendite ${pct.toFixed(2)} % — Snapshot-Feld returnPercentage (Kaufvolumen-Zeile: ${formatCurrency(trade.buyAmount)}).`;
}

export function tradeProfitCellTooltip(trade: SummaryReportTradeRow): string {
  return `Gewinn ${formatCurrency(trade.profit)} — Snapshot-Feld profit (Zeilen-Kaufvolumen: ${formatCurrency(trade.buyAmount)}).`;
}
