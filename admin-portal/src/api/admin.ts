/**
 * Admin API — barrel re-exports.
 * Implementation is split under `api/admin/*.ts` (types, dashboard, users, tickets, …).
 */
export { cloudFunction } from './parse';

export * from './admin/types';
export * from './admin/dashboard';
export * from './admin/users';
export * from './admin/tickets';
export * from './admin/compliance';
export * from './admin/audit';
export * from './admin/approvals';
export * from './admin/configuration';
export * from './admin/system';
export * from './admin/kyb';
export * from './admin/documents';
