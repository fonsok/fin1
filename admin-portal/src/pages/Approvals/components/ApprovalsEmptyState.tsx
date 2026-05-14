import clsx from 'clsx';
import { useTheme } from '../../../context/ThemeContext';

import { adminCaption, adminEmptyIcon, adminProse } from '../../../utils/adminThemeClasses';
interface ApprovalsEmptyStateProps {
  icon: 'check-circle' | 'document' | 'archive';
  message: string;
  description: string;
}

export function ApprovalsEmptyState({ icon, message, description }: ApprovalsEmptyStateProps) {
  const { theme } = useTheme();
  const isDark = theme === 'dark';

  const icons: Record<ApprovalsEmptyStateProps['icon'], JSX.Element> = {
    'check-circle': (
      <svg
        className={clsx('w-12 h-12 mx-auto mb-4', isDark ? 'text-emerald-500/80' : 'text-green-300')}
        fill="none"
        stroke="currentColor"
        viewBox="0 0 24 24"
      >
        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z" />
      </svg>
    ),
    'document': (
      <svg
        className={clsx('w-12 h-12 mx-auto mb-4', adminEmptyIcon(isDark))}
        fill="none"
        stroke="currentColor"
        viewBox="0 0 24 24"
      >
        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z" />
      </svg>
    ),
    'archive': (
      <svg
        className={clsx('w-12 h-12 mx-auto mb-4', adminEmptyIcon(isDark))}
        fill="none"
        stroke="currentColor"
        viewBox="0 0 24 24"
      >
        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M5 8h14M5 8a2 2 0 110-4h14a2 2 0 110 4M5 8v10a2 2 0 002 2h10a2 2 0 002-2V8m-9 4h4" />
      </svg>
    ),
  };

  return (
    <div className="p-8 text-center">
      {icons[icon]}
      <p className={clsx('font-medium', adminProse(isDark))}>{message}</p>
      <p className={clsx('text-sm mt-1', adminCaption(isDark))}>{description}</p>
    </div>
  );
}
