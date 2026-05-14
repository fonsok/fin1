import { useMemo } from 'react';
import clsx from 'clsx';
import { useTheme } from '../../../context/ThemeContext';
import { getCategoryIcon } from '../templates';
import { sortByTitleDe } from '../../Templates/utils/templateDisplayOrder';

// ============================================================================
// TemplateDropdown Component
// ============================================================================
// Reusable dropdown component for selecting text templates (Textbausteine)
// in ticket creation forms.

import { adminMuted, adminPrimary, adminStatTitle } from '../../../utils/adminThemeClasses';
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
  const { theme } = useTheme();
  const isDark = theme === 'dark';
  const sortedTemplates = useMemo(() => sortByTitleDe(templates), [templates]);

  const handleSelect = (template: T): void => {
    onSelect(template);
    onClose();
  };

  return (
    <div
      className={clsx(
        `absolute right-0 mt-1 ${widthClass} rounded-lg shadow-lg z-20 max-h-64 overflow-auto border`,
        isDark ? 'bg-slate-900 border-slate-600' : 'bg-white border-gray-200',
      )}
    >
      {/* Header */}
      <div
        className={clsx(
          'p-2 border-b sticky top-0',
          isDark ? 'border-slate-700 bg-slate-800/95' : 'border-gray-100 bg-gray-50',
        )}
      >
        <span className={clsx('text-xs font-medium', adminStatTitle(isDark))}>{title}</span>
      </div>

      {/* Loading State */}
      {isLoading && (
        <div className={clsx('p-4 text-center text-sm', adminMuted(isDark))}>
          Lade Vorlagen...
        </div>
      )}

      {/* Error State */}
      {error && (
        <div className={clsx('p-4 text-center text-sm', isDark ? 'text-red-300' : 'text-red-500')}>{error}</div>
      )}

      {/* Empty State */}
      {!isLoading && !error && sortedTemplates.length === 0 && (
        <div className={clsx('p-4 text-center text-sm', adminMuted(isDark))}>
          Keine Vorlagen verfügbar.
        </div>
      )}

      {/* Template List */}
      {sortedTemplates.map((template) => (
        <button
          key={template.id}
          type="button"
          onClick={() => handleSelect(template)}
          className={clsx(
            'w-full px-3 py-2 text-left border-b last:border-b-0 transition-colors',
            isDark
              ? 'border-slate-700 hover:bg-slate-800/80'
              : 'border-gray-100 hover:bg-gray-50',
          )}
        >
          {showBodyPreview ? (
            // Description template with body preview
            <div className="flex items-start gap-2">
              <span className="text-lg flex-shrink-0">{getCategoryIcon(template.category)}</span>
              <div className="flex-1 min-w-0">
                <p className={clsx('font-medium text-sm', adminPrimary(isDark))}>
                  {template.title}
                </p>
                {template.body && (
                  <p className={clsx('text-xs truncate mt-0.5', adminMuted(isDark))}>
                    {template.body.slice(0, 80)}...
                  </p>
                )}
              </div>
            </div>
          ) : (
            // Subject template - compact view
            <div className="flex items-center gap-2">
              <span className="text-base">{getCategoryIcon(template.category)}</span>
              <span className={clsx('font-medium text-sm', adminPrimary(isDark))}>
                {template.title}
              </span>
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
