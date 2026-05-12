import { cloudFunction } from '../parse';
import type { DashboardStats, Permissions } from './types';

/** Get admin dashboard statistics */
export async function getAdminDashboard(): Promise<DashboardStats> {
  return cloudFunction<DashboardStats>('getAdminDashboard');
}

/** Get current user's permissions */
export async function getMyPermissions(): Promise<Permissions> {
  return cloudFunction<Permissions>('getMyPermissions');
}
