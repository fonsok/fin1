import { useState, useMemo } from 'react';
import { Card } from '../../../components/ui/Card';
import { Badge } from '../../../components/ui/Badge';
import { Button } from '../../../components/ui/Button';
import clsx from 'clsx';
import { useTheme } from '../../../context/ThemeContext';
import { EmailTemplateEditor } from './EmailTemplateEditor';
import type { EmailTemplate } from '../types';
import { sortByDisplayNameDe } from '../utils/templateDisplayOrder';

interface EmailTemplateListProps {
  templates: EmailTemplate[];
  onRefresh: () => void;
}

export function EmailTemplateList({ templates, onRefresh }: EmailTemplateListProps) {
  const { theme } = useTheme();
  const isDark = theme === 'dark';
  const [editingTemplate, setEditingTemplate] = useState<EmailTemplate | null>(null);

  const sortedTemplates = useMemo(() => sortByDisplayNameDe(templates), [templates]);

  if (templates.length === 0) {
    return (
      <Card className="p-12 text-center">
        <div className="text-gray-400 text-5xl mb-4">✉️</div>
        <h3 className="text-lg font-medium text-gray-900">Keine E-Mail Vorlagen gefunden</h3>
        <p className="text-gray-500 mt-2">E-Mail Vorlagen werden vom System verwaltet.</p>
      </Card>
    );
  }

  return (
    <>
      <div className="grid gap-4 md:grid-cols-2">
        {sortedTemplates.map((template) => (
          <Card key={template.id} className="p-4 hover:shadow-md transition-shadow">
            <div className="flex items-start justify-between gap-4 mb-3">
              <div className="flex items-center gap-2">
                <span className="text-2xl">{template.icon || '✉️'}</span>
                <div>
                  <h3 className="font-medium text-gray-900">{template.displayName}</h3>
                  <span className="text-xs text-gray-500 font-mono">{template.type}</span>
                </div>
              </div>
              <Badge variant={template.isActive ? 'success' : 'neutral'}>
                {template.isActive ? 'Aktiv' : 'Inaktiv'}
              </Badge>
            </div>

              <div className={clsx('text-sm mb-3', isDark ? 'text-slate-200' : 'text-gray-600')}>
                <div className={clsx('font-medium mb-1', isDark ? 'text-slate-100' : 'text-gray-700')}>Betreff:</div>
                <div className={clsx('p-2 rounded text-sm', isDark ? 'bg-slate-900 border border-slate-600 text-slate-100' : 'bg-gray-50')}>
                  {template.subject}
                </div>
            </div>

            <div className={clsx('text-sm mb-3', isDark ? 'text-slate-200' : 'text-gray-600')}>
              <div className={clsx('font-medium mb-1', isDark ? 'text-slate-100' : 'text-gray-700')}>Platzhalter:</div>
              <div className="flex flex-wrap gap-1">
                {template.availablePlaceholders.map((p) => (
                  <span
                    key={p}
                    className={clsx(
                      'text-xs px-2 py-0.5 rounded font-mono',
                      isDark ? 'bg-slate-900 border border-slate-600 text-slate-100' : 'bg-blue-50 text-blue-600'
                    )}
                  >
                    {p}
                  </span>
                ))}
              </div>
            </div>

            <div className="flex justify-between items-center pt-3 border-t border-gray-100">
              <span className="text-xs text-gray-400">
                v{template.version}
                {template.updatedAt && ` • ${new Date(template.updatedAt).toLocaleDateString('de-DE')}`}
              </span>
              <Button variant="secondary" size="sm" onClick={() => setEditingTemplate(template)}>
                Bearbeiten
              </Button>
            </div>
          </Card>
        ))}
      </div>

      {/* Editor Modal */}
      {editingTemplate && (
        <EmailTemplateEditor
          template={editingTemplate}
          onSave={() => {
            setEditingTemplate(null);
            onRefresh();
          }}
          onClose={() => setEditingTemplate(null)}
        />
      )}
    </>
  );
}
