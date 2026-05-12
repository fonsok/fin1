import { cloudFunction } from '../parse';
import type {
  CleanupDuplicateInvestmentSplitsResult,
  DevResetTradingTestDataResult,
  SystemHealth,
} from './types';

/** Get system health status */
export async function getSystemHealth(): Promise<SystemHealth> {
  return cloudFunction('getSystemHealth');
}

export async function devResetTradingTestData(params: {
  dryRun: boolean;
  scope?: 'all' | 'sinceHours' | 'testUsers';
  sinceHours?: number;
}): Promise<DevResetTradingTestDataResult> {
  return cloudFunction('devResetTradingTestData', params);
}

export async function cleanupDuplicateInvestmentSplits(params?: {
  dryRun?: boolean;
  scanLimit?: number;
}): Promise<CleanupDuplicateInvestmentSplitsResult> {
  return cloudFunction('cleanupDuplicateInvestmentSplits', params || {});
}
