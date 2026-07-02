import { useState, type ReactNode } from 'react';
import clsx from 'clsx';
import { Card } from './Card';
import { adminHeadline, adminIconField } from '../../utils/adminThemeClasses';

interface AdminCollapsibleCardProps {
  title: string;
  isDark: boolean;
  panelId: string;
  defaultExpanded?: boolean;
  badges?: ReactNode;
  collapsedSummary?: ReactNode;
  children: ReactNode;
}

export function AdminCollapsibleCard({
  title,
  isDark,
  panelId,
  defaultExpanded = false,
  badges,
  collapsedSummary,
  children,
}: AdminCollapsibleCardProps) {
  const [expanded, setExpanded] = useState(defaultExpanded);

  return (
    <Card padding="none" className="overflow-hidden">
      <button
        type="button"
        onClick={() => setExpanded((open) => !open)}
        aria-expanded={expanded}
        aria-controls={panelId}
        className={clsx(
          'w-full flex items-center justify-between gap-3 px-4 py-3 text-left transition-colors',
          isDark ? 'hover:bg-slate-600/40' : 'hover:bg-gray-50',
        )}
      >
        <div className="flex flex-col gap-1 min-w-0 flex-1">
          <div className="flex flex-wrap items-center gap-2">
            <span className={clsx('text-md font-semibold truncate', adminHeadline(isDark))}>
              {title}
            </span>
            {badges}
          </div>
          {!expanded && collapsedSummary && (
            <div className="text-sm truncate">{collapsedSummary}</div>
          )}
        </div>
        <svg
          className={clsx(
            'w-5 h-5 shrink-0 transition-transform',
            expanded && 'rotate-180',
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

      {expanded && (
        <div id={panelId} className="px-4 pb-4 space-y-4 border-t border-inherit">
          {children}
        </div>
      )}
    </Card>
  );
}
