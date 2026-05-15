import type { ReactNode } from 'react';
import clsx from 'clsx';
import { useTheme } from '../../context/ThemeContext';
import { accountStatementEntryChipClasses } from '../../utils/accountStatementBadgeVariants';

interface AccountStatementEntryBadgeProps {
  entryType: string;
  children: ReactNode;
  className?: string;
}

export function AccountStatementEntryBadge({
  entryType,
  children,
  className,
}: AccountStatementEntryBadgeProps) {
  const { theme } = useTheme();
  const isDark = theme === 'dark';

  return (
    <span
      className={clsx(accountStatementEntryChipClasses(entryType, isDark), className)}
      data-portal-chip="statement-entry"
    >
      {children}
    </span>
  );
}
