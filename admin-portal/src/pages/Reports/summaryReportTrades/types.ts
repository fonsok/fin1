export interface SummaryReportPartialSellInvestorRealization {
  investmentId: string;
  investmentNumber: string;
  investorId: string;
  investorName: string;
  sellQuantity: number;
  sellAmount: number;
  grossProfit: number;
  commission: number;
  netProfit: number;
  investorPayout: number;
}

export interface SummaryReportPartialSellEvent {
  eventIndex: number;
  isFinalExit: boolean;
  traderSellQuantity: number;
  traderSellQuantityCumulative: number;
  traderSellAmount: number;
  traderSellPrice: number;
  traderSellVolumeProgress: number;
  sellFraction: number;
  poolSellQuantity: number;
  poolSellQuantityCumulative: number;
  poolSellAmount: number;
  investorRealizations: SummaryReportPartialSellInvestorRealization[];
  traderSellBeleg: SummaryReportTradeBelegLink | null;
  poolMirrorSellBeleg: SummaryReportTradeBelegLink | null;
  investorPartialSellBelege: SummaryReportTradeBelegLink[];
}

export interface SummaryReportPoolParticipation {
  investmentId: string;
  investmentNumber: string;
  investorId: string;
  investorName: string;
  investorEmail: string;
  ownershipPercentage: number;
  investmentStatus?: string;
  investmentCapital?: number;
  poolPieces?: number;
  activeInvestmentAtBid?: number;
  investmentResidual?: number;
  allocatedAmount: number;
  profitShare: number;
  commissionAmount: number;
  isSettled: boolean;
}

export type SummaryReportBelegVisibility = 'customer' | 'internal';

export type SummaryReportBelegBillKind =
  | 'execution_sell'
  | 'pool_mirror_execution'
  | 'fees'
  | 'credit_note'
  | 'full_settlement'
  | 'partial_sell';

export interface SummaryReportTradeBelegLink {
  documentId: string;
  documentNumber: string;
  documentType: string;
  executionType: string;
  label: string;
  investmentId?: string;
  investorId?: string;
  createdAt?: string;
  visibility?: SummaryReportBelegVisibility;
  billKind?: SummaryReportBelegBillKind;
}

export interface SummaryReportTraderBelege {
  buy: SummaryReportTradeBelegLink | null;
  sells: SummaryReportTradeBelegLink[];
  creditNote: SummaryReportTradeBelegLink | null;
}

export interface SummaryReportPoolBelege {
  traderExecution: {
    buy: SummaryReportTradeBelegLink | null;
    sells: SummaryReportTradeBelegLink[];
  };
  investorFullSettlement: SummaryReportTradeBelegLink[];
  investorPartialSells: SummaryReportTradeBelegLink[];
}

export interface SummaryReportTradeEconomics {
  tradeId: string;
  tradeNumber: number;
  symbol: string;
  description?: string;
  status: string;
  traderId: string;
  wkn?: string | null;
  isin?: string | null;
  wknOrIsin?: string | null;
  underlyingAsset?: string | null;
  issuer?: string | null;
  optionDirection?: string | null;
  strikePrice?: number | null;
  buyQuantity: number;
  soldQuantity: number;
  sellVolumeProgress: number;
  /** Bid / nomineller Kurs pro Stück (ohne Gebühren im Stückpreis). */
  buyPrice: number;
  /** Ask / nomineller Verkaufskurs pro Stück. */
  sellPrice: number;
  buyAmount: number;
  sellAmount: number;
  profit: number;
  bidPricePerShare?: number | null;
  buyFeesTotal?: number;
  totalBuyCost?: number;
  costBasisPerShare?: number | null;
  askPricePerShare?: number | null;
  sellFeesTotal?: number;
  netSellAmount?: number;
  netSellPricePerShare?: number | null;
  poolCapitalAllocated?: number;
  poolReservedCapitalTotal?: number;
  poolResidualTotal?: number;
  poolInvestorCount?: number;
  impliedBuyQuantityFromPool?: number | null;
  createdAt: string;
  completedAt?: string | null;
}

export type SummaryReportTradeLegKind = 'trader' | 'mirror_pool' | 'standalone';

export interface SummaryReportTradeRow {
  tradeId: string;
  tradeNumber: number;
  symbol: string;
  traderId: string;
  traderName: string;
  buyAmount: number;
  sellAmount: number;
  returnPercentage: number;
  profit: number;
  status: string;
  investorIds: string[];
  createdAt: string;
  legKind: SummaryReportTradeLegKind;
  pairExecutionId?: string | null;
  poolTradeId?: string | null;
  traderTrade?: SummaryReportTradeEconomics | null;
  poolMirrorTrade?: SummaryReportTradeEconomics | null;
  linkedTraderTrade?: SummaryReportTradeEconomics | null;
  poolParticipations: SummaryReportPoolParticipation[];
  /** @deprecated Nutze traderBelege / poolBelege — nur noch Kompatibilität. */
  poolExecutionBelege?: {
    buy: SummaryReportTradeBelegLink | null;
    sell: SummaryReportTradeBelegLink | null;
  };
  traderBelege?: SummaryReportTraderBelege | null;
  poolBelege?: SummaryReportPoolBelege | null;
  partialSellEvents?: SummaryReportPartialSellEvent[];
  hasPoolDetails: boolean;
}

export function fallbackTraderFromRow(trade: SummaryReportTradeRow): SummaryReportTradeEconomics {
  return {
    tradeId: trade.tradeId,
    tradeNumber: trade.tradeNumber,
    symbol: trade.symbol,
    status: trade.status,
    traderId: trade.traderId,
    buyQuantity: 0,
    soldQuantity: 0,
    sellVolumeProgress: 0,
    buyPrice: 0,
    sellPrice: 0,
    buyAmount: trade.buyAmount,
    sellAmount: trade.sellAmount,
    profit: trade.profit,
    createdAt: trade.createdAt,
  };
}
