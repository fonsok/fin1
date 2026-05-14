import clsx from 'clsx';
import { Badge } from '../../../components/ui/Badge';
import { useTheme } from '../../../context/ThemeContext';

import { adminBorderChrome } from '../../../utils/adminThemeClasses';
interface TemplatesTabsProps {
  activeTab: 'response' | 'email' | 'stats';
  responseCount: number;
  emailCount: number;
  onChangeTab: (tab: 'response' | 'email' | 'stats') => void;
}

export function TemplatesTabs({
  activeTab,
  responseCount,
  emailCount,
  onChangeTab,
}: TemplatesTabsProps) {
  const { theme } = useTheme();
  const isDark = theme === 'dark';

  const inactiveTab = clsx(
    isDark
      ? 'border-transparent text-slate-400 hover:text-slate-200'
      : 'border-transparent text-gray-500 hover:text-gray-700',
  );

  return (
    <div className={clsx('border-b', adminBorderChrome(isDark))}>
      <nav className="flex space-x-8">
        <button
          type="button"
          className={clsx(
            'py-4 px-1 border-b-2 font-medium text-sm',
            activeTab === 'response' ? 'border-fin1-primary text-fin1-primary' : inactiveTab,
          )}
          onClick={() => onChangeTab('response')}
        >
          Textbausteine
          <Badge variant="neutral" className="ml-2">
            {responseCount}
          </Badge>
        </button>
        <button
          type="button"
          className={clsx(
            'py-4 px-1 border-b-2 font-medium text-sm',
            activeTab === 'email' ? 'border-fin1-primary text-fin1-primary' : inactiveTab,
          )}
          onClick={() => onChangeTab('email')}
        >
          E-Mail Vorlagen
          <Badge variant="neutral" className="ml-2">
            {emailCount}
          </Badge>
        </button>
        <button
          type="button"
          className={clsx(
            'py-4 px-1 border-b-2 font-medium text-sm',
            activeTab === 'stats' ? 'border-fin1-primary text-fin1-primary' : inactiveTab,
          )}
          onClick={() => onChangeTab('stats')}
        >
          Statistiken
        </button>
      </nav>
    </div>
  );
}
