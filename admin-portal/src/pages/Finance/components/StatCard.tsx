import clsx from 'clsx';
import { Card } from '../../../components/ui';
import { useTheme } from '../../../context/ThemeContext';

interface StatCardProps {
  title: string;
  value: string;
  subtitle: string;
  icon: string;
  trend?: string;
}

export function StatCard({ title, value, subtitle, icon, trend }: StatCardProps): JSX.Element {
  const { theme } = useTheme();
  const isDark = theme === 'dark';

  return (
    <Card className="p-6">
      <div className="flex items-start justify-between">
        <div>
          <p className={clsx('text-sm font-medium', isDark ? 'text-slate-400' : 'text-gray-500')}>{title}</p>
          <p className={clsx('text-2xl font-bold mt-1', isDark ? 'text-slate-100' : 'text-gray-900')}>{value}</p>
          <p className={clsx('text-sm mt-1', isDark ? 'text-slate-500' : 'text-gray-400')}>{subtitle}</p>
        </div>
        <div className="flex flex-col items-end">
          <span className="text-2xl">{icon}</span>
          {trend && (
            <span
              className={clsx('text-xs font-medium mt-2', isDark ? 'text-emerald-400' : 'text-green-600')}
            >
              {trend}
            </span>
          )}
        </div>
      </div>
    </Card>
  );
}
