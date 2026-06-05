import { cloudFunction } from '../parse';
import type { AdminListSearchHealth } from './types';

/** MongoDB text/prefix index health for Summary Report list search. */
export async function getAdminListSearchHealth(): Promise<AdminListSearchHealth> {
  return cloudFunction('getAdminListSearchHealth');
}
