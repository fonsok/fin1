import { Card } from '../../../components/ui/Card';
import { Badge } from '../../../components/ui/Badge';
import { Button } from '../../../components/ui/Button';
import clsx from 'clsx';
import { useTheme } from '../../../context/ThemeContext';
import type { ResponseTemplate, TemplateCategory } from '../types';

import { adminCaption, adminMuted, adminPrimary, adminProse } from '../../../utils/adminThemeClasses';
import { templateShortcutChipClasses } from '../../../utils/chipVariants';
interface TemplateListProps {
  templates: ResponseTemplate[];
  categories: TemplateCategory[];
  onEdit: (template: ResponseTemplate) => void;
  onDelete: (templateId: string) => void;
}

export function TemplateList({ templates, categories, onEdit, onDelete }: TemplateListProps) {
  const { theme } = useTheme();
  const isDark = theme === 'dark';

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
        <div className={clsx('text-5xl mb-4', adminCaption(isDark))}>📝</div>
        <h3 className={clsx('text-lg font-medium', adminPrimary(isDark))}>
          Keine Templates gefunden
        </h3>
        <p className={clsx('mt-2', adminMuted(isDark))}>
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
                    adminPrimary(isDark),
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
                    templateShortcutChipClasses(parsed.shortcut || 'none', isDark)
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
                  adminMuted(isDark),
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

              <p className={clsx('text-sm line-clamp-2', adminProse(isDark))}>{template.body}</p>

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
                    <span className={clsx('text-xs', adminCaption(isDark))}>
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
