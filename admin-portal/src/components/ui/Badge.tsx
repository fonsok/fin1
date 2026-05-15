import React from 'react';
import clsx from 'clsx';
import { useTheme } from '../../context/ThemeContext';
import { chipVariantClasses, type ChipVariant } from '../../utils/chipVariants';

interface BadgeProps {
  children: React.ReactNode;
  variant?: ChipVariant;
  size?: 'sm' | 'md';
  className?: string;
}

export function Badge({
  children,
  variant = 'neutral',
  size = 'sm',
  className,
}: BadgeProps) {
  const { theme } = useTheme();
  const isDark = theme === 'dark';

  return (
    <span
      className={clsx(chipVariantClasses(variant, isDark, size), className)}
      data-portal-chip="standard"
    >
      {children}
    </span>
  );
}

/**
 * Helper to get badge variant from status string
 */
export function getStatusVariant(status: string): ChipVariant {
  const statusMap: Record<string, ChipVariant> = {
    active: 'success',
    verified: 'success',
    approved: 'success',
    resolved: 'success',
    pending: 'warning',
    in_progress: 'warning',
    in_review: 'warning',
    open: 'warning',
    suspended: 'danger',
    locked: 'danger',
    rejected: 'danger',
    failed: 'danger',
    critical: 'danger',
    high: 'danger',
    medium: 'warning',
    low: 'info',
    closed: 'neutral',
    deleted: 'neutral',
    not_started: 'neutral',
    reviewed: 'success',
    done: 'success',
    completed: 'success',
  };

  return statusMap[status.toLowerCase()] || 'neutral';
}
