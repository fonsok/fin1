import { cloudFunction } from '../parse';

/** Row shape returned by Cloud Function `searchDocuments` / `getDocumentByObjectId`. */
export interface DocumentSearchItem {
  objectId: string;
  userId: string;
  name: string;
  type: string;
  status: string;
  fileURL: string;
  size: number;
  uploadedAt: string | null;
  verifiedAt: string | null;
  documentNumber: string | null;
  accountingDocumentNumber: string | null;
  tradeId: string | null;
  investmentId: string | null;
  statementYear: number | null;
  statementMonth: number | null;
  statementRole: string | null;
  accountingSummaryText?: string | null;
}

export interface DocumentSearchResponse {
  items: DocumentSearchItem[];
  hasMore: boolean;
  total: number | null;
  limit: number;
  skip: number;
  sort: { sortBy: string; sortOrder: string };
}

export function hasDocumentSearchPredicate(params: Record<string, unknown>): boolean {
  const types = params.type;
  if (Array.isArray(types) && types.length > 0) return true;
  if (typeof types === 'string' && types.trim().length > 0) return true;
  if (String(params.userId || '').trim()) return true;
  if (String(params.investmentId || '').trim()) return true;
  if (String(params.tradeId || '').trim()) return true;
  if (String(params.documentNumber || '').trim()) return true;
  if (String(params.search || '').trim()) return true;
  if (String(params.dateFrom || '').trim() && String(params.dateTo || '').trim()) return true;
  return false;
}

export async function searchDocuments(
  params: Record<string, unknown>,
): Promise<DocumentSearchResponse> {
  return cloudFunction<DocumentSearchResponse>('searchDocuments', params);
}

export async function getDocumentByObjectId(objectId: string): Promise<DocumentSearchItem> {
  return cloudFunction<DocumentSearchItem>('getDocumentByObjectId', { objectId });
}

/** GoB: exakte `referenceDocumentNumber` aus Ledger-Metadaten (oder `objectId`). */
export async function getDocumentByLedgerReference(params: {
  objectId?: string;
  referenceDocumentNumber?: string;
}): Promise<DocumentSearchItem> {
  return cloudFunction<DocumentSearchItem>('getDocumentByLedgerReference', params);
}
