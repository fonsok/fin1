import type { ReactNode } from 'react';
import clsx from 'clsx';
import { useTheme } from '../../context/ThemeContext';
import {
  complianceEventTypeChipClasses,
  complianceSeverityChipClasses,
} from '../../utils/complianceBadgeVariants';

interface ComplianceSeverityBadgeProps {
  severity: string;
  children: ReactNode;
  className?: string;
}

interface ComplianceEventTypeBadgeProps {
  eventType: string;
  children: ReactNode;
  className?: string;
}

export function ComplianceSeverityBadge({
  severity,
  children,
  className,
}: ComplianceSeverityBadgeProps) {
  const { theme } = useTheme();
  const isDark = theme === 'dark';

  return (
    <span
      className={clsx(complianceSeverityChipClasses(severity, isDark), className)}
      data-portal-chip="compliance-severity"
    >
      {children}
    </span>
  );
}

export function ComplianceEventTypeBadge({
  eventType,
  children,
  className,
}: ComplianceEventTypeBadgeProps) {
  const { theme } = useTheme();
  const isDark = theme === 'dark';

  return (
    <span
      className={clsx(complianceEventTypeChipClasses(eventType, isDark), className)}
      data-portal-chip="compliance-event-type"
    >
      {children}
    </span>
  );
}
