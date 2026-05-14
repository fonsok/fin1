import clsx from 'clsx';
import { useTheme } from '../../../context/ThemeContext';

export function DetailRow({
  label,
  value,
  mono = false,
}: {
  label: string;
  value: string;
  mono?: boolean;
}) {
  const { theme } = useTheme();
  const isDark = theme === 'dark';

  return (
    <div className="flex justify-between gap-4">
      <dt className={clsx('text-sm', isDark ? 'text-slate-400' : 'text-gray-500')}>{label}</dt>
      <dd
        className={clsx(
          'text-sm text-right',
          isDark ? 'text-slate-100' : 'text-gray-900',
          mono && 'font-mono',
        )}
      >
        {value}
      </dd>
    </div>
  );
}

export function StatBox({
  label,
  value,
  color = 'gray',
}: {
  label: string;
  value: string;
  color?: 'gray' | 'green' | 'blue' | 'red';
}) {
  const { theme } = useTheme();
  const isDark = theme === 'dark';

  if (isDark) {
    const surface = {
      gray: 'bg-slate-800/90 border-slate-600',
      green: 'bg-emerald-950/50 border-emerald-600/70',
      blue: 'bg-sky-950/45 border-sky-600/70',
      red: 'bg-red-950/45 border-red-800/70',
    } as const;
    const valueTone = {
      gray: 'text-slate-50',
      green: 'text-emerald-300',
      blue: 'text-sky-300',
      red: 'text-red-300',
    } as const;

    return (
      <div
        className={clsx(
          'text-center p-3 rounded-lg border',
          surface[color],
        )}
      >
        <p className="text-xs font-medium text-slate-400">{label}</p>
        <p className={clsx('text-lg font-bold mt-0.5', valueTone[color])}>{value}</p>
      </div>
    );
  }

  const colorClasses = {
    gray: 'bg-gray-50 text-gray-900',
    green: 'bg-green-50 text-green-800',
    blue: 'bg-blue-50 text-blue-800',
    red: 'bg-red-50 text-red-800',
  };

  const labelClasses = {
    gray: 'text-gray-600',
    green: 'text-green-700',
    blue: 'text-blue-700',
    red: 'text-red-700',
  };

  return (
    <div className={clsx('text-center p-3 rounded-lg', colorClasses[color])}>
      <p className={clsx('text-xs', labelClasses[color])}>{label}</p>
      <p className="text-lg font-bold mt-0.5">{value}</p>
    </div>
  );
}
