import { Card } from '../../../components/ui/Card';
import { Badge } from '../../../components/ui/Badge';
import { Button } from '../../../components/ui/Button';
import type { FAQ, FAQCategory } from '../types';

interface FAQListProps {
  faqs: FAQ[];
  categories: FAQCategory[];
  onEdit: (faq: FAQ) => void;
  onDelete: (objectId: string) => void;
}

export function FAQList({ faqs, categories, onEdit, onDelete }: FAQListProps) {
  const getCategoryLabels = (faq: FAQ) => {
    const ids = faq.categoryIds && faq.categoryIds.length > 0 ? faq.categoryIds : [faq.categoryId];
    const labels = ids
      .map((id) => {
        const cat = categories.find((c) => c.objectId === id);
        if (!cat) return null;
        return `${cat.icon || '📁'} ${cat.displayName || cat.title || cat.slug}`;
      })
      .filter((label): label is string => Boolean(label));

    return labels.length > 0 ? labels.join(', ') : faq.categoryId;
  };

  if (faqs.length === 0) {
    return (
      <Card className="p-12 text-center">
        <div className="text-gray-400 text-5xl mb-4">❓</div>
        <h3 className="text-lg font-medium text-gray-900">Keine FAQs gefunden</h3>
        <p className="text-gray-500 mt-2">
          Erstellen Sie eine neue FAQ oder ändern Sie die Filterkriterien.
        </p>
      </Card>
    );
  }

  return (
    <div className="space-y-3">
      {faqs.map((faq) => (
        <Card key={faq.objectId} className="p-4 hover:shadow-md transition-shadow">
          <div className="flex items-start justify-between gap-4">
            {/* Content */}
            <div className="flex-1 min-w-0">
              <div className="flex items-center gap-2 mb-1">
                <h3 className="font-medium text-gray-900">{faq.question}</h3>
                {faq.isPublished && (
                  <Badge variant="info" className="text-xs">
                    Veröffentlicht
                  </Badge>
                )}
                {!faq.isPublished && (
                  <Badge variant="neutral" className="text-xs">
                    Entwurf
                  </Badge>
                )}
                {faq.isPublic && (
                  <Badge variant="info" className="text-xs">
                    Öffentlich
                  </Badge>
                )}
              </div>

              <div className="flex items-center gap-3 text-sm text-gray-500 mb-2">
                <span>{getCategoryLabels(faq)}</span>
                <span>•</span>
                <span>Sortierung: {faq.sortOrder}</span>
                {faq.source && (
                  <>
                    <span>•</span>
                    <span>{faq.source}</span>
                  </>
                )}
              </div>

              <p className="text-sm text-gray-600 line-clamp-3">{faq.answer}</p>

              {/* German translation indicator */}
              {faq.questionDe || faq.answerDe ? (
                <div className="mt-2">
                  <Badge variant="neutral" className="text-xs">
                    🇩🇪 DE verfügbar
                  </Badge>
                </div>
              ) : (
                <div className="mt-2">
                  <Badge variant="neutral" className="text-xs opacity-50">
                    🇩🇪 DE fehlt
                  </Badge>
                </div>
              )}
            </div>

            {/* Actions */}
            <div className="flex gap-2 flex-shrink-0">
              <Button variant="secondary" size="sm" onClick={() => onEdit(faq)}>
                Bearbeiten
              </Button>
              <Button variant="danger" size="sm" onClick={() => onDelete(faq.objectId)}>
                Löschen
              </Button>
            </div>
          </div>
        </Card>
      ))}
    </div>
  );
}
