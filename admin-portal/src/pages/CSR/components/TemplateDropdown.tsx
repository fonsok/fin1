import { useMemo } from 'react';
import { getCategoryIcon } from '../templates';
import { sortByTitleDe } from '../../Templates/utils/templateDisplayOrder';

// ============================================================================
// TemplateDropdown Component
// ============================================================================
// Reusable dropdown component for selecting text templates (Textbausteine)
// in ticket creation forms.

interface BaseTemplate {
  id: string;
  title: string;
  category: string;
  body?: string;
}

interface TemplateDropdownProps<T extends BaseTemplate> {
  /** Dropdown title displayed in header */
  title: string;
  /** Array of templates to display */
  templates: T[];
  /** Whether templates are currently loading */
  isLoading?: boolean;
  /** Error message if loading failed */
  error?: string | null;
  /** Callback when a template is selected */
  onSelect: (template: T) => void;
  /** Callback to close the dropdown */
  onClose: () => void;
  /** Whether to show description preview (for description templates) */
  showBodyPreview?: boolean;
  /** Custom width class (default: w-72) */
  widthClass?: string;
}

export function TemplateDropdown<T extends BaseTemplate>({
  title,
  templates,
  isLoading = false,
  error = null,
  onSelect,
  onClose,
  showBodyPreview = false,
  widthClass = 'w-72',
}: TemplateDropdownProps<T>): JSX.Element {
  const sortedTemplates = useMemo(() => sortByTitleDe(templates), [templates]);

  const handleSelect = (template: T): void => {
    onSelect(template);
    onClose();
  };

  return (
    <div
      className={`absolute right-0 mt-1 ${widthClass} bg-white border border-gray-200 rounded-lg shadow-lg z-20 max-h-64 overflow-auto`}
    >
      {/* Header */}
      <div className="p-2 border-b border-gray-100 bg-gray-50 sticky top-0">
        <span className="text-xs font-medium text-gray-500">{title}</span>
      </div>

      {/* Loading State */}
      {isLoading && (
        <div className="p-4 text-center text-sm text-gray-500">Lade Vorlagen...</div>
      )}

      {/* Error State */}
      {error && <div className="p-4 text-center text-sm text-red-500">{error}</div>}

      {/* Empty State */}
      {!isLoading && !error && sortedTemplates.length === 0 && (
        <div className="p-4 text-center text-sm text-gray-500">
          Keine Vorlagen verfügbar.
        </div>
      )}

      {/* Template List */}
      {sortedTemplates.map((template) => (
        <button
          key={template.id}
          type="button"
          onClick={() => handleSelect(template)}
          className="w-full px-3 py-2 text-left hover:bg-gray-50 border-b border-gray-100 last:border-b-0 transition-colors"
        >
          {showBodyPreview ? (
            // Description template with body preview
            <div className="flex items-start gap-2">
              <span className="text-lg flex-shrink-0">{getCategoryIcon(template.category)}</span>
              <div className="flex-1 min-w-0">
                <p className="font-medium text-sm text-gray-900">{template.title}</p>
                {template.body && (
                  <p className="text-xs text-gray-500 truncate mt-0.5">
                    {template.body.slice(0, 80)}...
                  </p>
                )}
              </div>
            </div>
          ) : (
            // Subject template - compact view
            <div className="flex items-center gap-2">
              <span className="text-base">{getCategoryIcon(template.category)}</span>
              <span className="font-medium text-sm text-gray-900">{template.title}</span>
            </div>
          )}
        </button>
      ))}
    </div>
  );
}

// ============================================================================
// TemplateButton Component
// ============================================================================
// Button that triggers the template dropdown

interface TemplateButtonProps {
  onClick: () => void;
  label?: string;
}

export function TemplateButton({
  onClick,
  label = 'Textbaustein',
}: TemplateButtonProps): JSX.Element {
  return (
    <button
      type="button"
      onClick={onClick}
      className="text-sm text-fin1-primary hover:text-fin1-secondary flex items-center gap-1 transition-colors"
    >
      <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
        <path
          strokeLinecap="round"
          strokeLinejoin="round"
          strokeWidth={2}
          d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z"
        />
      </svg>
      {label}
    </button>
  );
}
