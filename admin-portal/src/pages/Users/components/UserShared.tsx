import clsx from 'clsx';
import { useTheme } from '../../../context/ThemeContext';
import { adminMuted, adminPrimary } from '../../../utils/adminThemeClasses';

type StatColor = 'gray' | 'green' | 'blue' | 'red';

const STAT_BOX_DARK_SURFACE: Record<StatColor, string> = {
  gray: 'bg-slate-800/90 border-slate-600',
  green: 'bg-emerald-950/50 border-emerald-600/70',
  blue: 'bg-sky-950/45 border-sky-600/70',
  red: 'bg-red-950/45 border-red-800/70',
};

const STAT_BOX_DARK_VALUE: Record<StatColor, string> = {
  gray: 'text-slate-50',
  green: 'text-emerald-300',
  blue: 'text-sky-300',
  red: 'text-red-300',
};

const STAT_BOX_LIGHT_SURFACE: Record<StatColor, string> = {
  gray: clsx('bg-gray-50 text-gray-900'),
  green: clsx('bg-green-50 text-green-800'),
  blue: clsx('bg-blue-50 text-blue-800'),
  red: clsx('bg-red-50 text-red-800'),
};

const STAT_BOX_LIGHT_LABEL: Record<StatColor, string> = {
  gray: clsx('text-gray-600'),
  green: clsx('text-green-700'),
  blue: clsx('text-blue-700'),
  red: clsx('text-red-700'),
};

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
      <dt className={clsx('text-sm', adminMuted(isDark))}>{label}</dt>
      <dd
        className={clsx(
          'text-sm text-right',
          adminPrimary(isDark),
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
  color?: StatColor;
}) {
  const { theme } = useTheme();
  const isDark = theme === 'dark';

  if (isDark) {
    return (
      <div
        className={clsx(
          'text-center p-3 rounded-lg border',
          STAT_BOX_DARK_SURFACE[color],
        )}
      >
        <p className="text-xs font-medium text-slate-400">{label}</p>
        <p className={clsx('text-lg font-bold mt-0.5', STAT_BOX_DARK_VALUE[color])}>{value}</p>
      </div>
    );
  }

  return (
    <div className={clsx('text-center p-3 rounded-lg', STAT_BOX_LIGHT_SURFACE[color])}>
      <p className={clsx('text-xs', STAT_BOX_LIGHT_LABEL[color])}>{label}</p>
      <p className="text-lg font-bold mt-0.5">{value}</p>
    </div>
  );
}
