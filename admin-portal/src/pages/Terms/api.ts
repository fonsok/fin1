import { cloudFunction } from '../../api/parse';
import type {
  TermsContentListItem,
  TermsContentFull,
  CreateTermsContentRequest,
} from './types';

/**
 * List TermsContent versions (optional filters: documentType, language).
 */
export async function listTermsContent(params?: {
  documentType?: string;
  language?: string;
}): Promise<TermsContentListItem[]> {
  const result = await cloudFunction<TermsContentListItem[]>('listTermsContent', params ?? {});
  return Array.isArray(result) ? result : [];
}

/**
 * Get full TermsContent by objectId (for editing/cloning).
 */
export async function getTermsContent(objectId: string): Promise<TermsContentFull> {
  return cloudFunction<TermsContentFull>('getTermsContent', { objectId });
}

/**
 * Create a new TermsContent version (append-only). Use setActiveTermsContent to make it live.
 */
export async function createTermsContent(data: CreateTermsContentRequest): Promise<TermsContentListItem> {
  return cloudFunction<TermsContentListItem>('createTermsContent', {
    ...data,
    effectiveDate: data.effectiveDate || new Date().toISOString().slice(0, 10),
  } as Record<string, unknown>);
}

/**
 * Set a TermsContent version as active for its documentType+language.
 */
export async function setActiveTermsContent(objectId: string): Promise<{
  success: boolean;
  objectId: string;
  version: string;
  language: string;
  documentType: string;
}> {
  return cloudFunction('setActiveTermsContent', { objectId });
}
