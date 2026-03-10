import { cloudFunction } from '../../api/parse';
import type {
  ResponseTemplate,
  EmailTemplate,
  TemplateCategory,
  TemplateUsageStats,
  CreateTemplateRequest,
  UpdateTemplateRequest,
} from './types';

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
  return cloudFunction<ResponseTemplate>('getResponseTemplate', { templateId });
}

/**
 * Create a new response template
 */
export async function createResponseTemplate(
  data: CreateTemplateRequest
): Promise<ResponseTemplate> {
  return cloudFunction<ResponseTemplate>('createResponseTemplate', { ...data });
}

/**
 * Update an existing response template
 */
export async function updateResponseTemplate(
  templateId: string,
  updates: UpdateTemplateRequest
): Promise<ResponseTemplate> {
  return cloudFunction<ResponseTemplate>('updateResponseTemplate', {
    templateId,
    ...updates,
  });
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

/**
 * Get template usage statistics
 */
export async function getTemplateUsageStats(days: number = 30): Promise<TemplateUsageStats> {
  return cloudFunction<TemplateUsageStats>('getTemplateUsageStats', { days });
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
