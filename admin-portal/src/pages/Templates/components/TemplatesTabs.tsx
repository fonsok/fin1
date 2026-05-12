import { Badge } from '../../../components/ui/Badge';

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
  return (
    <div className="border-b border-gray-200">
      <nav className="flex space-x-8">
        <button
          className={`py-4 px-1 border-b-2 font-medium text-sm ${
            activeTab === 'response'
              ? 'border-fin1-primary text-fin1-primary'
              : 'border-transparent text-gray-500 hover:text-gray-700'
          }`}
          onClick={() => onChangeTab('response')}
        >
          Textbausteine
          <Badge variant="neutral" className="ml-2">
            {responseCount}
          </Badge>
        </button>
        <button
          className={`py-4 px-1 border-b-2 font-medium text-sm ${
            activeTab === 'email'
              ? 'border-fin1-primary text-fin1-primary'
              : 'border-transparent text-gray-500 hover:text-gray-700'
          }`}
          onClick={() => onChangeTab('email')}
        >
          E-Mail Vorlagen
          <Badge variant="neutral" className="ml-2">
            {emailCount}
          </Badge>
        </button>
        <button
          className={`py-4 px-1 border-b-2 font-medium text-sm ${
            activeTab === 'stats'
              ? 'border-fin1-primary text-fin1-primary'
              : 'border-transparent text-gray-500 hover:text-gray-700'
          }`}
          onClick={() => onChangeTab('stats')}
        >
          Statistiken
        </button>
      </nav>
    </div>
  );
}
