import { cloudFunction } from '../parse';

/** Get pending 4-eyes approvals */
export async function getPendingApprovals(): Promise<{ requests: unknown[] }> {
  return cloudFunction('getPendingApprovals');
}

/** Approve 4-eyes request */
export async function approveRequest(
  requestId: string,
  notes?: string,
): Promise<{ success: boolean }> {
  return cloudFunction('approveRequest', { requestId, notes });
}

/** Reject 4-eyes request */
export async function rejectRequest(
  requestId: string,
  reason: string,
): Promise<{ success: boolean }> {
  return cloudFunction('rejectRequest', { requestId, reason });
}
