import { createResponseTemplate } from '../api';
import type { CreateTemplateRequest, ResponseTemplate } from '../types';

export function downloadJson(filename: string, payload: unknown) {
  const blob = new Blob([JSON.stringify(payload, null, 2)], { type: 'application/json' });
  const url = URL.createObjectURL(blob);
  const a = document.createElement('a');
  a.href = url;
  a.download = filename;
  a.click();
  URL.revokeObjectURL(url);
}

export function buildFilteredTemplatesExportPayload(
  templates: ResponseTemplate[],
  categoryFilter: string,
  searchQuery: string
) {
  return {
    exportedAt: new Date().toISOString(),
    version: '1.0',
    note: 'Filtered CSR response templates export',
    filter: {
      category: categoryFilter || 'all',
      searchQuery: searchQuery || '',
    },
    templates,
  };
}

export function getFilteredExportFilename(categoryFilter: string) {
  const categoryPart = categoryFilter || 'all';
  const timestamp = new Date().toISOString().slice(0, 19).replace(/[:T]/g, '-');
  return `csr-templates-filtered-${categoryPart}-${timestamp}.json`;
}

export async function importFilteredTemplatesAsNew(
  parsed: unknown
): Promise<{ created: number; failed: number }> {
  const list = Array.isArray((parsed as { templates?: unknown[] })?.templates)
    ? ((parsed as { templates: unknown[] }).templates as Array<Record<string, unknown>>)
    : [];

  if (!list.length) {
    throw new Error('Keine Templates im Import gefunden.');
  }

  let created = 0;
  let failed = 0;

  for (const t of list) {
    const basePayload: CreateTemplateRequest = {
      title: String(t.title || ''),
      titleDe: String(t.title || ''),
      categoryKey: String(t.category || ''),
      subject: t.subject ? String(t.subject) : undefined,
      subjectDe: t.subject ? String(t.subject) : undefined,
      body: String(t.body || ''),
      bodyDe: String(t.body || ''),
      isEmail: !!t.isEmail,
      placeholders: Array.isArray(t.placeholders) ? t.placeholders.map(String) : [],
      shortcut: t.shortcut ? String(t.shortcut) : undefined,
    };

    try {
      await createResponseTemplate(basePayload);
      created++;
    } catch {
      // Retry without shortcut if shortcut already exists
      try {
        const retryPayload: CreateTemplateRequest = {
          ...basePayload,
          shortcut: undefined,
        };
        await createResponseTemplate(retryPayload);
        created++;
      } catch {
        failed++;
      }
    }
  }

  return { created, failed };
}
