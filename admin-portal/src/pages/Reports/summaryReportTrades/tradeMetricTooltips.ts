import { formatCurrency } from '../../../utils/format';
import type { SummaryReportTradeRow } from './types';

export const TRADE_RETURN_HEADER_TOOLTIP =
  'Rendite in % = Gewinn ÷ Kaufvolumen × 100. Kaufvolumen ist buyOrder.totalAmount.';

export const TRADE_PROFIT_HEADER_TOOLTIP =
  'Gewinn = gebuchter Profit (calculatedProfit oder grossProfit), sonst Verkaufsvolumen − Kaufvolumen. Verkauf = Summe aller sellOrders.';

export function tradeReturnPercentage(trade: SummaryReportTradeRow): number {
  if (Number.isFinite(trade.returnPercentage)) return trade.returnPercentage;
  return trade.buyAmount > 0 ? (trade.profit / trade.buyAmount) * 100 : 0;
}

export function tradeReturnCellTooltip(trade: SummaryReportTradeRow): string {
  const pct = tradeReturnPercentage(trade);
  if (trade.buyAmount <= 0) {
    return 'Kein Kaufvolumen — Rendite 0 %.';
  }
  return `Rendite = ${formatCurrency(trade.profit)} ÷ ${formatCurrency(trade.buyAmount)} × 100 = ${pct.toFixed(2)} %`;
}

export function tradeProfitCellTooltip(trade: SummaryReportTradeRow): string {
  return `Gewinn = Verkauf ${formatCurrency(trade.sellAmount)} − Kauf ${formatCurrency(trade.buyAmount)} = ${formatCurrency(trade.profit)} (Priorität: calculatedProfit/grossProfit).`;
}
