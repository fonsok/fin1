import type { ReactNode } from 'react';
import clsx from 'clsx';
import { useTheme } from '../../context/ThemeContext';
import { auditLogTypeChipClasses } from '../../utils/auditLogBadgeVariants';

interface AuditLogTypeBadgeProps {
  logType: string;
  children: ReactNode;
  className?: string;
}

export function AuditLogTypeBadge({ logType, children, className }: AuditLogTypeBadgeProps) {
  const { theme } = useTheme();
  const isDark = theme === 'dark';

  return (
    <span
      className={clsx(auditLogTypeChipClasses(logType, isDark), className)}
      data-portal-chip="audit-type"
    >
      {children}
    </span>
  );
}
