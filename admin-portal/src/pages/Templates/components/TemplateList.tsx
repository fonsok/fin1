import { Card } from '../../../components/ui/Card';
import { Badge } from '../../../components/ui/Badge';
import { Button } from '../../../components/ui/Button';
import type { ResponseTemplate, TemplateCategory } from '../types';

interface TemplateListProps {
  templates: ResponseTemplate[];
  categories: TemplateCategory[];
  onEdit: (template: ResponseTemplate) => void;
  onDelete: (templateId: string) => void;
}

export function TemplateList({ templates, categories, onEdit, onDelete }: TemplateListProps) {
  const getCategoryLabel = (key: string) => {
    const cat = categories.find((c) => c.key === key);
    return cat ? `${cat.icon} ${cat.displayName}` : key;
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
      {templates.map((template) => (
        <Card key={template.id} className="p-4 hover:shadow-md transition-shadow">
          <div className="flex items-start justify-between gap-4">
            {/* Content */}
            <div className="flex-1 min-w-0">
              <div className="flex items-center gap-2 mb-1">
                <h3 className="font-medium text-gray-900 truncate">{template.title}</h3>
                {template.isEmail && (
                  <Badge variant="info" className="text-xs">
                    ✉️ E-Mail
                  </Badge>
                )}
                {template.shortcut && (
                  <Badge variant="neutral" className="text-xs font-mono">
                    /{template.shortcut}
                  </Badge>
                )}
                {!template.isDefault && (
                  <Badge variant="info" className="text-xs">
                    Custom
                  </Badge>
                )}
              </div>

              <div className="flex items-center gap-3 text-sm text-gray-500 mb-2">
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

              <p className="text-sm text-gray-600 line-clamp-2">{template.body}</p>

              {/* Placeholders */}
              {template.placeholders.length > 0 && (
                <div className="flex flex-wrap gap-1 mt-2">
                  {template.placeholders.slice(0, 4).map((p) => (
                    <span
                      key={p}
                      className="text-xs bg-gray-100 text-gray-600 px-2 py-0.5 rounded font-mono"
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
      ))}
    </div>
  );
}
