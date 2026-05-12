import { useCallback, useEffect, useMemo, useState } from 'react';
import { getResponseTemplates, getEmailTemplates, getTemplateCategories } from '../api';
import type { ResponseTemplate, EmailTemplate, TemplateCategory } from '../types';
import { sortByDisplayNameDe, sortByTitleDe } from '../utils/templateDisplayOrder';

export function useTemplatesData(categoryFilter: string, searchQuery: string) {
  const [templates, setTemplates] = useState<ResponseTemplate[]>([]);
  const [emailTemplates, setEmailTemplates] = useState<EmailTemplate[]>([]);
  const [categories, setCategories] = useState<TemplateCategory[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const loadData = useCallback(async () => {
    setLoading(true);
    setError(null);

    try {
      const [templatesData, emailData, categoriesData] = await Promise.all([
        getResponseTemplates('teamlead', true),
        getEmailTemplates(true),
        getTemplateCategories(),
      ]);

      setTemplates(sortByTitleDe(templatesData));
      setEmailTemplates(sortByDisplayNameDe(emailData));
      setCategories(sortByDisplayNameDe(categoriesData));
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Fehler beim Laden der Templates');
      console.error('Error loading templates:', err);
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    loadData();
  }, [loadData]);

  const filteredTemplates = useMemo(
    () =>
      sortByTitleDe(
        templates.filter((t) => {
          if (categoryFilter && t.category !== categoryFilter) return false;
          if (searchQuery) {
            const query = searchQuery.toLowerCase();
            return (
              t.title.toLowerCase().includes(query) ||
              t.body.toLowerCase().includes(query) ||
              (t.shortcut?.toLowerCase().includes(query) ?? false)
            );
          }
          return true;
        }),
      ),
    [templates, categoryFilter, searchQuery],
  );

  const uniqueCategories = useMemo(
    () =>
      sortByDisplayNameDe(
        categories.filter((cat, idx, arr) => arr.findIndex((c) => c.key === cat.key) === idx),
      ),
    [categories],
  );

  return {
    templates,
    setTemplates,
    emailTemplates,
    categories,
    loading,
    error,
    loadData,
    filteredTemplates,
    uniqueCategories,
  };
}
