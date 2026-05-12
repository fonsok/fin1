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
  return (
    <div className="flex border-b border-gray-200 overflow-x-auto">
      {tabs.map((tab) => (
        <button
          key={tab.id}
          onClick={() => onSelect(tab.id)}
          className={`flex items-center gap-2 px-5 py-3 text-sm font-medium border-b-2 transition-colors whitespace-nowrap ${
            activeTab === tab.id
              ? 'border-fin1-primary text-fin1-primary'
              : 'border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300'
          }`}
        >
          <span>{tab.icon}</span>
          <span>{tab.label}</span>
          {tab.count > 0 && (
            <span className={`ml-1 px-2 py-0.5 text-xs font-semibold rounded-full ${
              activeTab === tab.id
                ? 'bg-fin1-primary text-white'
                : tab.id === 'pending' && tab.count > 0
                  ? 'bg-amber-100 text-amber-800'
                  : 'bg-gray-100 text-gray-600'
            }`}>
              {tab.count}
            </span>
          )}
        </button>
      ))}
    </div>
  );
}
