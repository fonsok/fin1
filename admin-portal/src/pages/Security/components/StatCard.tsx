import clsx from 'clsx';
import { Card } from '../../../components/ui';
import { useTheme } from '../../../context/ThemeContext';
import { adminCaption, adminStatTitle } from '../../../utils/adminThemeClasses';

type Variant = 'default' | 'success' | 'warning' | 'error';

interface StatCardProps {
  title: string;
  value: string;
  subtitle: string;
  variant?: Variant;
}

const STAT_CARD_SURFACE_LIGHT: Record<Variant, string> = {
  default: 'bg-white',
  success: 'bg-green-50 border-green-200',
  warning: 'bg-amber-50 border-amber-200',
  error: 'bg-red-50 border-red-200',
};

const STAT_CARD_SURFACE_DARK: Record<Variant, string> = {
  default: 'bg-slate-700/60 border-slate-600',
  success: 'bg-emerald-900/25 border-emerald-700/40',
  warning: 'bg-amber-900/25 border-amber-700/40',
  error: 'bg-red-900/25 border-red-700/40',
};

const STAT_CARD_VALUE_LIGHT: Record<Variant, string> = {
  default: clsx('text-gray-900'),
  success: 'text-green-700',
  warning: 'text-amber-700',
  error: 'text-red-700',
};

const STAT_CARD_VALUE_DARK: Record<Variant, string> = {
  default: 'text-slate-100',
  success: 'text-emerald-400',
  warning: 'text-amber-300',
  error: 'text-red-300',
};

export function StatCard({ title, value, subtitle, variant = 'default' }: StatCardProps): JSX.Element {
  const { theme } = useTheme();
  const isDark = theme === 'dark';
  const surface = isDark ? STAT_CARD_SURFACE_DARK : STAT_CARD_SURFACE_LIGHT;
  const valueTone = isDark ? STAT_CARD_VALUE_DARK : STAT_CARD_VALUE_LIGHT;

  return (
    <Card className={clsx('p-4', surface[variant])}>
      <p className={clsx('text-sm font-medium', adminStatTitle(isDark))}>{title}</p>
      <p className={clsx('text-2xl font-bold mt-1', valueTone[variant])}>{value}</p>
      <p className={clsx('text-xs mt-1', adminCaption(isDark))}>{subtitle}</p>
    </Card>
  );
}
