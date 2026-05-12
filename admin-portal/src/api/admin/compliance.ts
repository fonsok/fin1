import { cloudFunction } from '../parse';
import type { ComplianceEvent } from './types';

/** Get compliance events */
export async function getComplianceEvents(params: {
  eventType?: string;
  severity?: string;
  reviewed?: boolean;
  limit?: number;
  skip?: number;
  sortBy?: string;
  sortOrder?: 'asc' | 'desc';
}): Promise<{ events: ComplianceEvent[]; total: number }> {
  return cloudFunction('getComplianceEvents', params);
}

/** Review compliance event */
export async function reviewComplianceEvent(
  eventId: string,
  notes: string,
): Promise<{ success: boolean }> {
  return cloudFunction('reviewComplianceEvent', { eventId, notes });
}
