import { cloudFunction } from '../../api/parse';
import type {
  ResponseTemplate,
  EmailTemplate,
  TemplateCategory,
  TemplateUsageStats,
  CreateTemplateRequest,
  UpdateTemplateRequest,
} from './types';

function normalizeResponseTemplate(template: Partial<ResponseTemplate> & { objectId?: string }): ResponseTemplate {
  return {
    ...template,
    id: template.id || template.objectId || '',
  } as ResponseTemplate;
}

// ============================================================================
// Response Templates API
// ============================================================================

/**
 * Get all response templates for a role
 */
export async function getResponseTemplates(
  role: string = 'teamlead',
  includeInactive: boolean = false
): Promise<ResponseTemplate[]> {
  return cloudFunction<ResponseTemplate[]>('getResponseTemplates', {
    role,
    includeInactive,
    language: 'de',
  });
}

/**
 * Get a single response template by ID
 */
export async function getResponseTemplate(templateId: string): Promise<ResponseTemplate> {
  const template = await cloudFunction<ResponseTemplate & { objectId?: string }>('getResponseTemplate', { templateId });
  return normalizeResponseTemplate(template);
}

/**
 * Create a new response template
 */
export async function createResponseTemplate(
  data: CreateTemplateRequest
): Promise<ResponseTemplate> {
  const template = await cloudFunction<ResponseTemplate & { objectId?: string }>('createResponseTemplate', { ...data });
  return normalizeResponseTemplate(template);
}

/**
 * Update an existing response template
 */
export async function updateResponseTemplate(
  templateId: string,
  updates: UpdateTemplateRequest
): Promise<ResponseTemplate> {
  const template = await cloudFunction<ResponseTemplate & { objectId?: string }>('updateResponseTemplate', {
    templateId,
    ...updates,
  });
  return normalizeResponseTemplate(template);
}

/**
 * Delete a response template (soft delete)
 */
export async function deleteResponseTemplate(
  templateId: string
): Promise<{ success: boolean; message: string }> {
  return cloudFunction('deleteResponseTemplate', { templateId });
}

// ============================================================================
// Email Templates API
// ============================================================================

/**
 * Get all email templates
 */
export async function getEmailTemplates(
  includeInactive: boolean = false
): Promise<EmailTemplate[]> {
  return cloudFunction<EmailTemplate[]>('getEmailTemplates', {
    includeInactive,
    language: 'de',
  });
}

/**
 * Get email template by type
 */
export async function getEmailTemplate(type: string): Promise<EmailTemplate> {
  return cloudFunction<EmailTemplate>('getEmailTemplate', { type, language: 'de' });
}

/**
 * Update an email template
 */
export async function updateEmailTemplate(
  templateId: string,
  updates: Partial<EmailTemplate>
): Promise<EmailTemplate> {
  return cloudFunction<EmailTemplate>('updateEmailTemplate', {
    templateId,
    ...updates,
  });
}

/**
 * Create a new email template
 */
export async function createEmailTemplate(data: {
  type: string;
  displayName: string;
  subject: string;
  bodyTemplate: string;
  availablePlaceholders?: string[];
  icon?: string;
  isActive?: boolean;
}): Promise<EmailTemplate> {
  return cloudFunction<EmailTemplate>('createEmailTemplate', data);
}

/**
 * Render an email template with values
 */
export async function renderEmailTemplate(
  type: string,
  values: Record<string, string>
): Promise<{ subject: string; body: string }> {
  return cloudFunction('renderEmailTemplate', { type, values, language: 'de' });
}

// ============================================================================
// Categories API
// ============================================================================

/**
 * Get all template categories
 */
export async function getTemplateCategories(): Promise<TemplateCategory[]> {
  return cloudFunction<TemplateCategory[]>('getTemplateCategories', { language: 'de' });
}

// ============================================================================
// Analytics API
// ============================================================================

/** Rolling window ending „now“, or explicit inclusive local-day range (ISO sent to Parse). */
export type GetTemplateUsageStatsParams =
  | { days: number }
  | { startDate: string; endDate: string };

/**
 * Get template usage statistics (rolling `days` or custom `startDate`/`endDate` ISO strings).
 */
export async function getTemplateUsageStats(
  params: GetTemplateUsageStatsParams | number = { days: 30 },
): Promise<TemplateUsageStats> {
  if (typeof params === 'number') {
    return cloudFunction<TemplateUsageStats>('getTemplateUsageStats', { days: params });
  }
  if ('startDate' in params && 'endDate' in params) {
    return cloudFunction<TemplateUsageStats>('getTemplateUsageStats', {
      startDate: params.startDate,
      endDate: params.endDate,
    });
  }
  return cloudFunction<TemplateUsageStats>('getTemplateUsageStats', { days: params.days });
}

// ============================================================================
// Seed API
// ============================================================================

interface SeedResult {
  categories?: { success: boolean; created: number; message?: string; error?: string };
  responseTemplates?: { success: boolean; created: number; message?: string; error?: string };
  emailTemplates?: { success: boolean; created: number; message?: string; error?: string };
}

/**
 * Seed CSR templates with default data
 */
export async function seedCSRTemplates(): Promise<SeedResult> {
  return cloudFunction<SeedResult>('seedCSRTemplates');
}

// ============================================================================
// Export Backup (Backend)
// ============================================================================

export interface CSRTemplatesBackupPayload {
  exportedAt: string;
  version: string;
  note: string;
  categories: unknown[];
  responseTemplates: unknown[];
  emailTemplates: unknown[];
}

/**
 * Export full CSR templates backup from backend (categories, response + email templates).
 */
export async function exportCSRTemplatesBackup(): Promise<CSRTemplatesBackupPayload> {
  return cloudFunction<CSRTemplatesBackupPayload>('exportCSRTemplatesBackup');
}

export interface BackfillCSRTemplateShortcutsResult {
  dryRun: boolean;
  activeTemplatesScanned?: number;
  candidateCount?: number;
  candidates?: Array<{
    objectId: string;
    templateKey: string;
    title: string;
    suggestedShortcut: string;
  }>;
  updatedCount?: number;
  updated?: Array<{
    objectId: string;
    templateKey: string;
    shortcut: string;
  }>;
}

export async function backfillCSRTemplateShortcuts(params: {
  dryRun: boolean;
}): Promise<BackfillCSRTemplateShortcutsResult> {
  return cloudFunction<BackfillCSRTemplateShortcutsResult>('backfillCSRTemplateShortcuts', params);
}
