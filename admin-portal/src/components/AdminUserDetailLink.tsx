import { Link } from 'react-router-dom';
import clsx from 'clsx';
import { useTheme } from '../context/ThemeContext';

export function AdminUserDetailLink({
  userId,
  label,
  className,
  isDark: isDarkOverride,
}: {
  userId?: string | null;
  label?: string | null;
  className?: string;
  isDark?: boolean;
}): JSX.Element {
  const { theme } = useTheme();
  const isDark = isDarkOverride ?? theme === 'dark';
  const text = label?.trim() || userId?.trim() || '—';
  const id = userId?.trim();

  if (!id) {
    return <span className={className}>{text}</span>;
  }

  return (
    <Link
      to={`/users/${id}`}
      className={clsx(
        'font-medium hover:underline',
        isDark ? 'text-sky-400 hover:text-sky-300' : 'text-fin1-primary hover:text-fin1-secondary',
        className,
      )}
      title={`Benutzer-Details: ${text}`}
    >
      {text}
    </Link>
  );
}
