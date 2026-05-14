import clsx from 'clsx';
import { useTheme } from '../../../context/ThemeContext';

interface TabItem<T extends string> {
  id: T;
  label: string;
  count: number;
  icon: string;
}

interface ApprovalsTabsProps<T extends string> {
  activeTab: T;
  tabs: TabItem<T>[];
  onSelect: (tab: T) => void;
}

export function ApprovalsTabs<T extends string>({
  activeTab,
  tabs,
  onSelect,
}: ApprovalsTabsProps<T>) {
  const { theme } = useTheme();
  const isDark = theme === 'dark';

  const inactiveTab = clsx(
    'border-transparent transition-colors',
    isDark
      ? 'text-slate-400 hover:text-slate-200 hover:border-slate-500'
      : 'text-gray-500 hover:text-gray-700 hover:border-gray-300',
  );

  return (
    <div
      className={clsx(
        'flex border-b overflow-x-auto',
        isDark ? 'border-slate-600' : 'border-gray-200',
      )}
    >
      {tabs.map((tab) => (
        <button
          key={tab.id}
          type="button"
          onClick={() => onSelect(tab.id)}
          className={clsx(
            'flex items-center gap-2 px-5 py-3 text-sm font-medium border-b-2 whitespace-nowrap',
            activeTab === tab.id ? 'border-fin1-primary text-fin1-primary' : inactiveTab,
          )}
        >
          <span>{tab.icon}</span>
          <span>{tab.label}</span>
          {tab.count > 0 && (
            <span
              className={clsx(
                'ml-1 px-2 py-0.5 text-xs font-semibold rounded-full',
                activeTab === tab.id
                  ? 'bg-fin1-primary text-white'
                  : tab.id === 'pending' && tab.count > 0
                    ? isDark
                      ? 'bg-amber-900/50 text-amber-200'
                      : 'bg-amber-100 text-amber-800'
                    : isDark
                      ? 'bg-slate-600 text-slate-200'
                      : 'bg-gray-100 text-gray-600',
              )}
            >
              {tab.count}
            </span>
          )}
        </button>
      ))}
    </div>
  );
}
