import { cloudFunction } from '../parse';
import type { AuditLog } from './types';

/** Get audit logs */
export async function getAuditLogs(params: {
  logType?: string;
  action?: string;
  userId?: string;
  resourceType?: string;
  limit?: number;
  skip?: number;
  sortBy?: string;
  sortOrder?: 'asc' | 'desc';
}): Promise<{ logs: AuditLog[]; total: number }> {
  return cloudFunction('getAuditLogs', params);
}
