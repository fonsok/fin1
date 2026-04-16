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
  includeArchived?: boolean;
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

// ============================================================================
// Export Backup (Backend)
// ============================================================================

export interface LegalDocumentsBackupPayload {
  exportedAt: string;
  version: string;
  note: string;
  /** Server-set when export hit a row limit (full or active export may be incomplete). */
  warnings?: string[];
  documents: Array<{
    objectId: string;
    version: string;
    language: string;
    documentType: string;
    effectiveDate: string;
    isActive: boolean;
    documentHash: string | null;
    sections: unknown[];
    createdAt: string;
    updatedAt: string;
  }>;
}

/**
 * Export full AGB/Rechtstexte backup from backend (all TermsContent versions).
 */
export async function exportLegalDocumentsBackup(): Promise<LegalDocumentsBackupPayload> {
  return cloudFunction<LegalDocumentsBackupPayload>('exportLegalDocumentsBackup');
}

/**
 * Export only active TermsContent versions (optionally filtered).
 */
export async function exportActiveLegalDocumentsBackup(params?: {
  documentType?: string;
  language?: string;
}): Promise<LegalDocumentsBackupPayload & { filter?: unknown }> {
  return cloudFunction('exportActiveLegalDocumentsBackup', params ?? {});
}

// ============================================================================
// Legal Branding (Backend)
// ============================================================================

export interface LegalBranding {
  appName: string;
  platformName: string;
  updatedAt: string | null;
  updatedBy: string | null;
}

export async function getLegalBranding(): Promise<LegalBranding> {
  return cloudFunction<LegalBranding>('getLegalBranding');
}

/**
 * @deprecated Server-side blocked. Use `requestConfigurationChange` with `parameterName: "legalAppName"` (4-eyes).
 */
export async function updateLegalBranding(params: {
  appName: string;
  platformName?: string;
  reason?: string;
}): Promise<{ success: boolean; appName: string; platformName: string }> {
  return cloudFunction('updateLegalBranding', params as Record<string, unknown>);
}

// ============================================================================
// DEV Maintenance (Legal Docs)
// ============================================================================

export async function devResetLegalDocumentsBaseline(params: {
  targetVersion?: string;
  effectiveDate?: string;
  dryRun?: boolean;
}): Promise<{
  dryRun: boolean;
  targetVersion: string;
  effectiveDate: string;
  activeFound: number;
  clonesPlanned: number;
  activatedCount: number;
  deletedCount: number;
}> {
  return cloudFunction('devResetLegalDocumentsBaseline', params as Record<string, unknown>);
}

// ============================================================================
// Import / Restore Backup (Backend)
// ============================================================================

export interface ImportLegalDocumentsBackupResult {
  dryRun: boolean;
  archivedCount: number;
  importedCount: number;
  fixedActiveConflicts: number;
  warnings: string[];
}

export async function importLegalDocumentsBackup(params: {
  backup: unknown;
  archiveExisting?: boolean;
  dryRun?: boolean;
}): Promise<ImportLegalDocumentsBackupResult> {
  return cloudFunction<ImportLegalDocumentsBackupResult>('importLegalDocumentsBackup', params as Record<string, unknown>);
}

export interface ImportActiveLegalDocumentsBackupResult {
  dryRun: boolean;
  createdCount: number;
  activatedCount: number;
  warnings: string[];
}

/**
 * Import a (typically active-only) backup as NEW versions and activate them.
 * Does not archive existing history.
 */
export async function importActiveLegalDocumentsBackup(params: {
  backup: unknown;
  dryRun?: boolean;
}): Promise<ImportActiveLegalDocumentsBackupResult> {
  return cloudFunction<ImportActiveLegalDocumentsBackupResult>('importActiveLegalDocumentsBackup', params as Record<string, unknown>);
}
