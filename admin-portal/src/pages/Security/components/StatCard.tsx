import clsx from 'clsx';
import { Card } from '../../../components/ui';
import { useTheme } from '../../../context/ThemeContext';

type Variant = 'default' | 'success' | 'warning' | 'error';

interface StatCardProps {
  title: string;
  value: string;
  subtitle: string;
  variant?: Variant;
}

export function StatCard({ title, value, subtitle, variant = 'default' }: StatCardProps): JSX.Element {
  const { theme } = useTheme();
  const isDark = theme === 'dark';

  const variantStyles: Record<Variant, string> = {
    default: isDark ? 'bg-slate-700/60 border-slate-600' : 'bg-white',
    success: isDark ? 'bg-emerald-900/25 border-emerald-700/40' : 'bg-green-50 border-green-200',
    warning: isDark ? 'bg-amber-900/25 border-amber-700/40' : 'bg-amber-50 border-amber-200',
    error: isDark ? 'bg-red-900/25 border-red-700/40' : 'bg-red-50 border-red-200',
  };

  const valueStyles: Record<Variant, string> = {
    default: clsx(isDark ? 'text-slate-100' : 'text-gray-900'),
    success: isDark ? 'text-emerald-400' : 'text-green-700',
    warning: isDark ? 'text-amber-300' : 'text-amber-700',
    error: isDark ? 'text-red-300' : 'text-red-700',
  };

  return (
    <Card className={clsx('p-4', variantStyles[variant])}>
      <p className={clsx('text-sm font-medium', isDark ? 'text-slate-300' : 'text-gray-500')}>{title}</p>
      <p className={clsx('text-2xl font-bold mt-1', valueStyles[variant])}>{value}</p>
      <p className={clsx('text-xs mt-1', isDark ? 'text-slate-400' : 'text-gray-400')}>{subtitle}</p>
    </Card>
  );
}
