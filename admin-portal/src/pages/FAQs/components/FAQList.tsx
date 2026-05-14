import { Card } from '../../../components/ui/Card';
import { Badge } from '../../../components/ui/Badge';
import { Button } from '../../../components/ui/Button';
import clsx from 'clsx';
import { useTheme } from '../../../context/ThemeContext';
import type { FAQ, FAQCategory } from '../types';

import { adminCaption, adminMuted, adminPrimary } from '../../../utils/adminThemeClasses';
interface FAQListProps {
  faqs: FAQ[];
  categories: FAQCategory[];
  onEdit: (faq: FAQ) => void;
  onDelete: (objectId: string) => void;
}

export function FAQList({ faqs, categories, onEdit, onDelete }: FAQListProps) {
  const { theme } = useTheme();
  const isDark = theme === 'dark';

  const getCategoryLabels = (faq: FAQ) => {
    const ids = faq.categoryIds && faq.categoryIds.length > 0 ? faq.categoryIds : [faq.categoryId];
    const labels = ids
      .map((id) => {
        const cat = categories.find((c) => c.objectId === id);
        if (!cat) return null;
        return cat.displayName || cat.title || cat.slug;
      })
      .filter((label): label is string => Boolean(label));

    return labels.length > 0 ? labels.join(', ') : faq.categoryId;
  };

  if (faqs.length === 0) {
    return (
      <Card className="p-12 text-center">
        <div className={clsx('text-5xl mb-4', adminCaption(isDark))}>❓</div>
        <h3 className={clsx('text-lg font-medium', adminPrimary(isDark))}>
          Keine FAQs gefunden
        </h3>
        <p className={clsx('mt-2', adminMuted(isDark))}>
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
                <h3 className={clsx('font-medium', adminPrimary(isDark))}>{faq.question}</h3>
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

              <div
                className={clsx(
                  'flex items-center gap-3 text-sm mb-2',
                  adminMuted(isDark),
                )}
              >
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

              <p className={clsx('text-sm line-clamp-3', isDark ? 'text-slate-200' : 'text-gray-600')}>
                {faq.answer}
              </p>

              {/* Optional EN: canonical questionEn/answerEn; legacy De-suffixed fields until DB migrated */}
              {(
                faq.questionEn?.trim() ||
                faq.answerEn?.trim() ||
                faq.questionDe?.trim() ||
                faq.answerDe?.trim()
              ) ? (
                <div className="mt-2">
                  <Badge variant="neutral" className="text-xs">
                    🇬🇧 EN verfügbar
                  </Badge>
                </div>
              ) : (
                <div className="mt-2">
                  <Badge variant="neutral" className={clsx('text-xs', isDark && 'opacity-80')}>
                    🇬🇧 EN fehlt
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
