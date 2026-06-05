import type { ReactNode } from 'react';
import clsx from 'clsx';
import { Card, Badge } from '../../../components/ui';
import { adminHeadline, adminIconField } from '../../../utils/adminThemeClasses';

interface ConfigurationSectionCollapsibleProps {
  title: string;
  icon?: ReactNode;
  expanded: boolean;
  onToggle: () => void;
  /** Keeps section open while a parameter in this section is being edited */
  forceExpanded?: boolean;
  pendingCount?: number;
  isDark: boolean;
  children: ReactNode;
}

export function ConfigurationSectionCollapsible({
  title,
  icon,
  expanded,
  onToggle,
  forceExpanded = false,
  pendingCount = 0,
  isDark,
  children,
}: ConfigurationSectionCollapsibleProps) {
  const isOpen = expanded || forceExpanded;

  return (
    <Card padding="none" className="overflow-hidden">
      <button
        type="button"
        onClick={onToggle}
        disabled={forceExpanded}
        aria-expanded={isOpen}
        aria-controls={`config-section-${title.replace(/\s+/g, '-')}`}
        className={clsx(
          'w-full flex items-center justify-between gap-3 px-4 py-3 text-left transition-colors',
          forceExpanded
            ? 'cursor-default'
            : isDark
              ? 'hover:bg-slate-600/40'
              : 'hover:bg-gray-50',
        )}
      >
        <div className="flex items-center gap-2 min-w-0">
          {icon}
          <span className={clsx('text-md font-semibold truncate', adminHeadline(isDark))}>
            {title}
          </span>
          {pendingCount > 0 && (
            <Badge variant="info" size="sm">
              {pendingCount} ausstehend
            </Badge>
          )}
        </div>
        <svg
          className={clsx(
            'w-5 h-5 shrink-0 transition-transform',
            isOpen && 'rotate-180',
            adminIconField(isDark),
          )}
          fill="none"
          stroke="currentColor"
          viewBox="0 0 24 24"
          aria-hidden
        >
          <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M19 9l-7 7-7-7" />
        </svg>
      </button>

      {isOpen && (
        <div
          id={`config-section-${title.replace(/\s+/g, '-')}`}
          className="px-4 pb-4"
        >
          {children}
        </div>
      )}
    </Card>
  );
}
