import type { ReactNode } from 'react';
import clsx from 'clsx';
import { useTheme } from '../../context/ThemeContext';
import {
  ticketPriorityChipClasses,
  ticketStatusChipClasses,
} from '../../utils/ticketBadgeVariants';

interface TicketStatusBadgeProps {
  status: string;
  children: ReactNode;
  className?: string;
}

interface TicketPriorityBadgeProps {
  priority: string;
  children: ReactNode;
  className?: string;
}

export function TicketStatusBadge({ status, children, className }: TicketStatusBadgeProps) {
  const { theme } = useTheme();
  const isDark = theme === 'dark';
  return (
    <span
      className={clsx(ticketStatusChipClasses(status, isDark), className)}
      data-ticket-chip="status"
    >
      {children}
    </span>
  );
}

export function TicketPriorityBadge({ priority, children, className }: TicketPriorityBadgeProps) {
  const { theme } = useTheme();
  const isDark = theme === 'dark';
  return (
    <span
      className={clsx(ticketPriorityChipClasses(priority, isDark), className)}
      data-ticket-chip="priority"
    >
      {children}
    </span>
  );
}
