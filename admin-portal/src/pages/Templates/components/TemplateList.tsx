import { Card } from '../../../components/ui/Card';
import { Badge } from '../../../components/ui/Badge';
import { Button } from '../../../components/ui/Button';
import clsx from 'clsx';
import { useTheme } from '../../../context/ThemeContext';
import type { ResponseTemplate, TemplateCategory } from '../types';

interface TemplateListProps {
  templates: ResponseTemplate[];
  categories: TemplateCategory[];
  onEdit: (template: ResponseTemplate) => void;
  onDelete: (templateId: string) => void;
}

export function TemplateList({ templates, categories, onEdit, onDelete }: TemplateListProps) {
  const { theme } = useTheme();
  const isDark = theme === 'dark';

  const getShortcutToneClasses = (shortcut: string) => {
    const key = (shortcut || '').toLowerCase().replace(/^\//, '');

    // Semantic tones for common shortcut intents.
    // We keep strong contrast in dark mode (light text on saturated backgrounds).
    if (key.includes('close') || key.includes('resolved') || key.includes('done')) {
      return isDark
        ? '!bg-emerald-700 !text-slate-100 border border-emerald-500/60'
        : 'bg-emerald-100 text-emerald-800 border border-emerald-300';
    }
    if (key === 'hi' || key.includes('high') || key.includes('prio1') || key.includes('p1')) {
      return isDark
        ? '!bg-amber-700 !text-slate-100 border border-amber-500/60'
        : 'bg-amber-100 text-amber-800 border border-amber-300';
    }
    if (key.includes('med') || key.includes('medium') || key.includes('prio2') || key.includes('p2')) {
      return isDark
        ? '!bg-orange-700 !text-slate-100 border border-orange-500/60'
        : 'bg-orange-100 text-orange-800 border border-orange-300';
    }
    if (key.includes('low') || key.includes('lo') || key.includes('prio3') || key.includes('p3')) {
      return isDark
        ? '!bg-cyan-700 !text-slate-100 border border-cyan-500/60'
        : 'bg-cyan-100 text-cyan-800 border border-cyan-300';
    }
    if (key.includes('formal') || key.includes('official')) {
      return isDark
        ? '!bg-indigo-700 !text-slate-100 border border-indigo-500/60'
        : 'bg-indigo-100 text-indigo-800 border border-indigo-300';
    }
    if (key.includes('urgent') || key.includes('escalate') || key.includes('warn')) {
      return isDark
        ? '!bg-rose-700 !text-slate-100 border border-rose-500/60'
        : 'bg-rose-100 text-rose-800 border border-rose-300';
    }
    if (key.includes('friendly') || key.includes('greet')) {
      return isDark
        ? '!bg-sky-700 !text-slate-100 border border-sky-500/60'
        : 'bg-sky-100 text-sky-800 border border-sky-300';
    }

    return isDark
      ? '!bg-slate-800 !text-slate-100 border border-slate-500/70'
      : 'bg-gray-100 text-gray-700 border border-gray-300';
  };

  const getCategoryLabel = (key: string) => {
    const cat = categories.find((c) => c.key === key);
    return cat ? `${cat.icon} ${cat.displayName}` : key;
  };

  const parseTitleAndInlineShortcut = (title: string, explicitShortcut?: string) => {
    if (explicitShortcut && String(explicitShortcut).trim().length > 0) {
      return { cleanTitle: title, shortcut: String(explicitShortcut).replace(/^\//, '') };
    }

    // Support legacy style where shortcut is appended to title, e.g. "Problem gelöst /resolved"
    const m = String(title || '').match(/^(.*)\s\/([a-z0-9_-]+)$/i);
    if (!m) return { cleanTitle: title, shortcut: '' };

    return {
      cleanTitle: m[1].trim(),
      shortcut: m[2].trim(),
    };
  };

  if (templates.length === 0) {
    return (
      <Card className="p-12 text-center">
        <div className="text-gray-400 text-5xl mb-4">📝</div>
        <h3 className="text-lg font-medium text-gray-900">Keine Templates gefunden</h3>
        <p className="text-gray-500 mt-2">
          Erstellen Sie ein neues Template oder ändern Sie die Filterkriterien.
        </p>
      </Card>
    );
  }

  return (
    <div className="space-y-3">
      {templates.map((template) => {
        const parsed = parseTitleAndInlineShortcut(template.title, template.shortcut);
        return (
        <Card key={template.id} className="p-4 transition-shadow hover:shadow-md">
          <div className="flex items-start justify-between gap-4">
            {/* Content */}
            <div className="flex-1 min-w-0">
              <div className="flex flex-wrap items-center gap-2 mb-1">
                <h3
                  className={clsx(
                    'font-medium min-w-0 truncate',
                    isDark ? 'text-slate-100' : 'text-gray-900',
                  )}
                >
                  {parsed.cleanTitle}
                </h3>
                {template.isEmail && (
                  <Badge variant="info" className="text-xs">
                    ✉️ E-Mail
                  </Badge>
                )}
                <span
                  className={clsx(
                    'inline-flex items-center rounded-full px-2 py-0.5 text-xs font-mono font-medium',
                    getShortcutToneClasses(parsed.shortcut || 'none')
                  )}
                >
                  /{parsed.shortcut || 'kein-status'}
                </span>
                {!template.isDefault && (
                  <Badge variant="info" className="text-xs">
                    Custom
                  </Badge>
                )}
              </div>

              <div
                className={clsx(
                  'flex flex-wrap items-center gap-x-3 gap-y-1 text-sm mb-2',
                  isDark ? 'text-slate-400' : 'text-gray-500',
                )}
              >
                <span>{getCategoryLabel(template.category)}</span>
                <span>•</span>
                <span>{template.usageCount} Verwendungen</span>
                {template.version > 1 && (
                  <>
                    <span>•</span>
                    <span>v{template.version}</span>
                  </>
                )}
              </div>

              <p className={clsx('text-sm line-clamp-2', isDark ? 'text-slate-200' : 'text-gray-600')}>{template.body}</p>

              {/* Placeholders */}
              {template.placeholders.length > 0 && (
                <div className="flex flex-wrap gap-1 mt-2">
                  {template.placeholders.slice(0, 4).map((p) => (
                    <span
                      key={p}
                      className={clsx(
                        'text-xs px-2 py-0.5 rounded font-mono',
                        isDark ? 'bg-slate-900 border border-slate-600 text-slate-100' : 'bg-gray-100 text-gray-600'
                      )}
                    >
                      {p}
                    </span>
                  ))}
                  {template.placeholders.length > 4 && (
                    <span className="text-xs text-gray-400">
                      +{template.placeholders.length - 4} mehr
                    </span>
                  )}
                </div>
              )}
            </div>

            {/* Actions */}
            <div className="flex gap-2 flex-shrink-0">
              <Button variant="secondary" size="sm" onClick={() => onEdit(template)}>
                Bearbeiten
              </Button>
              {!template.isDefault && (
                <Button variant="danger" size="sm" onClick={() => onDelete(template.id)}>
                  Löschen
                </Button>
              )}
            </div>
          </div>
        </Card>
      );
      })}
    </div>
  );
}
