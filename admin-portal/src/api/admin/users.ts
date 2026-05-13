import { cloudFunction } from '../parse';
import type { AdminUser, UserDetailsResponse } from './types';

/** Search users */
export async function searchUsers(params: {
  query?: string;
  status?: string;
  role?: string;
  limit?: number;
  skip?: number;
  sortBy?: string;
  sortOrder?: 'asc' | 'desc';
}): Promise<{ users: AdminUser[]; total: number }> {
  return cloudFunction('searchUsers', params);
}

/** Get user details with wallet, trades, investments */
export async function getUserDetails(userId: string): Promise<UserDetailsResponse> {
  const result = await cloudFunction<UserDetailsResponse>('getUserDetails', { userId });
  if (result.user) {
    result.user.objectId = result.user.objectId || (result.user as unknown as { id: string }).id;
  }
  return result;
}

/** Audit: Admin öffnet Kundensicht (Lesemodus); gleiche Berechtigung wie getUserDetails. */
export async function logAdminCustomerView(params: {
  targetUserId: string;
  viewContext?: string;
  reason?: string;
}): Promise<{ success: boolean }> {
  return cloudFunction('logAdminCustomerView', params);
}

/** Update user status */
export async function updateUserStatus(
  userId: string,
  status: string,
  reason: string,
): Promise<{ success: boolean }> {
  return cloudFunction('updateUserStatus', { userId, status, reason });
}

/** Force password reset for user */
export async function forcePasswordReset(
  userId: string,
  reason: string,
): Promise<{ success: boolean; message: string }> {
  return cloudFunction('forcePasswordReset', { userId, reason });
}

export async function requestUserWalletActionModeChange(
  userId: string,
  newMode: 'disabled' | 'deposit_only' | 'withdrawal_only' | 'deposit_and_withdrawal',
  reason: string,
): Promise<{ success: boolean; requiresApproval: boolean; fourEyesRequestId?: string; message: string }> {
  return cloudFunction('requestUserWalletActionModeChange', { userId, newMode, reason });
}
