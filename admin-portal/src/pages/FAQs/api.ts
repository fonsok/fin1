import { cloudFunction } from '../../api/parse';
import type {
  FAQ,
  FAQListResponse,
  FAQCategoriesResponse,
  CreateFAQRequest,
  UpdateFAQRequest,
  CreateFAQCategoryRequest,
} from './types';

// ============================================================================
// FAQs API
// ============================================================================

/**
 * Get all FAQs (admin context returns ALL regardless of visibility)
 */
export async function getFAQs(
  isPublic?: boolean,
  categorySlug?: string
): Promise<FAQListResponse> {
  const params: Record<string, unknown> = { context: 'admin' };
  if (isPublic !== undefined) params.isPublic = isPublic;
  if (categorySlug) params.categorySlug = categorySlug;

  return cloudFunction<FAQListResponse>('getFAQs', params);
}

/**
 * Get FAQ categories
 */
export async function getFAQCategories(location?: string): Promise<FAQCategoriesResponse> {
  const params: Record<string, unknown> = {};
  if (location) params.location = location;

  return cloudFunction<FAQCategoriesResponse>('getFAQCategories', params);
}

/**
 * Create a new FAQ (Admin only - requires Cloud Function)
 * Note: This would need to be added to the backend Cloud Functions
 */
export async function createFAQ(data: CreateFAQRequest): Promise<FAQ> {
  return cloudFunction<FAQ>('createFAQ', { ...data } as Record<string, unknown>);
}

/**
 * Update an existing FAQ (Admin only - requires Cloud Function)
 * Note: This would need to be added to the backend Cloud Functions
 */
export async function updateFAQ(objectId: string, updates: UpdateFAQRequest): Promise<FAQ> {
  return cloudFunction<FAQ>('updateFAQ', {
    objectId,
    ...updates,
  });
}

/**
 * Delete an FAQ (Admin only - requires Cloud Function)
 * Note: This would need to be added to the backend Cloud Functions
 */
export async function deleteFAQ(objectId: string): Promise<{ success: boolean; message: string }> {
  return cloudFunction('deleteFAQ', { objectId });
}

/**
 * Create a new FAQ category (Admin only)
 */
export async function createFAQCategory(data: CreateFAQCategoryRequest) {
  return cloudFunction('createFAQCategory', { ...data } as Record<string, unknown>);
}

// ============================================================================
// Export Backup (Backend)
// ============================================================================

export interface FAQBackupPayload {
  exportedAt: string;
  version: string;
  note: string;
  categories: unknown[];
  faqs: unknown[];
}

export interface FAQImportResult {
  success: boolean;
  dryRun: boolean;
  counts: {
    categoriesInput: number;
    categoriesCreated: number;
    categoriesUpdated: number;
    faqsInput: number;
    faqsCreated: number;
    faqsUpdated: number;
    faqsSkipped: number;
  };
  warnings: string[];
}

/**
 * Export full FAQ backup from backend (categories + faqs).
 */
export async function exportFAQBackup(): Promise<FAQBackupPayload> {
  return cloudFunction<FAQBackupPayload>('exportFAQBackup');
}

export async function importFAQBackup(params: {
  backup: FAQBackupPayload;
  dryRun: boolean;
}): Promise<FAQImportResult> {
  return cloudFunction<FAQImportResult>('importFAQBackup', params as Record<string, unknown>);
}

// ============================================================================
// DEV Maintenance (FAQs) — gated by ALLOW_FAQ_HARD_DELETE on server
// ============================================================================

export async function devResetFAQsBaseline(params: {
  dryRun?: boolean;
  deleteInactiveCategories?: boolean;
}): Promise<{
  dryRun: boolean;
  deleteInactiveCategories?: boolean;
  activeFound: number;
  inactiveFaqsPlanned?: number;
  clonesPlanned?: number;
  inactiveCategoriesPlanned?: number;
  clonesCreated?: number;
  deletedInactiveFaqs?: number;
  deletedInactiveCategories?: number;
}> {
  return cloudFunction('devResetFAQsBaseline', params as Record<string, unknown>);
}
