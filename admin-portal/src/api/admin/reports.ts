import { cloudFunction } from '../parse';
import type { AdminListSearchHealth } from './types';
import type { SummaryReportPoolParticipation } from '../../pages/Reports/summaryReportTrades/types';

/** MongoDB text/prefix index health for Summary Report list search. */
export async function getAdminListSearchHealth(): Promise<AdminListSearchHealth> {
  return cloudFunction('getAdminListSearchHealth');
}

export interface SummaryReportParticipationsPageResponse {
  poolTradeId: string;
  items: SummaryReportPoolParticipation[];
  total: number;
  page: number;
  pageSize: number;
  aggregates: {
    totalCommission: number;
    totalProfitShare: number;
  };
}

export async function getSummaryReportTradeParticipationsPage(params: {
  poolTradeId: string;
  page?: number;
  pageSize?: number;
  costBasisPerShare?: number;
}): Promise<SummaryReportParticipationsPageResponse> {
  return cloudFunction<SummaryReportParticipationsPageResponse>(
    'getSummaryReportTradeParticipationsPage',
    params,
  );
}
