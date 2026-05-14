import clsx from 'clsx';
import { Card } from '../../../components/ui';
import { useTheme } from '../../../context/ThemeContext';
import { adminCaption, adminMuted, adminPrimary } from '../../../utils/adminThemeClasses';

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
          <p className={clsx('text-sm font-medium', adminMuted(isDark))}>{title}</p>
          <p className={clsx('text-2xl font-bold mt-1', adminPrimary(isDark))}>{value}</p>
          <p className={clsx('text-sm mt-1', adminCaption(isDark))}>{subtitle}</p>
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
