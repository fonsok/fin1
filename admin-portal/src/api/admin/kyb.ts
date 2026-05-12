import { cloudFunction } from '../parse';
import type { KybSubmission, KybSubmissionDetail } from './types';

export async function getCompanyKybSubmissions(params: {
  status?: string;
  limit?: number;
  skip?: number;
  sortBy?: string;
  sortOrder?: 'asc' | 'desc';
}): Promise<{ submissions: KybSubmission[]; total: number }> {
  return cloudFunction('getCompanyKybSubmissions', params);
}

export async function getCompanyKybSubmissionDetail(userId: string): Promise<KybSubmissionDetail> {
  return cloudFunction('getCompanyKybSubmissionDetail', { userId });
}

export async function reviewCompanyKyb(
  userId: string,
  decision: 'approved' | 'rejected' | 'more_info_requested',
  notes?: string,
): Promise<{ success: boolean; decision: string; message: string }> {
  return cloudFunction('reviewCompanyKyb', { userId, decision, notes });
}

export async function resetCompanyKyb(
  userId: string,
  notes?: string,
): Promise<{ success: boolean; message: string }> {
  return cloudFunction('resetCompanyKyb', { userId, notes });
}
