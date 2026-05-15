import React from 'react';
import clsx from 'clsx';
import { useTheme } from '../../context/ThemeContext';

interface BadgeProps {
  children: React.ReactNode;
  variant?: 'success' | 'warning' | 'danger' | 'info' | 'neutral';
  size?: 'sm' | 'md';
  className?: string;
}

type VariantKey = NonNullable<BadgeProps['variant']>;

/** Module-scope maps avoid new objects on every Badge render. */
const BADGE_VARIANTS_LIGHT: Record<VariantKey, string> = {
  success: 'bg-green-100 text-green-800',
  warning: 'bg-amber-100 text-amber-800',
  danger: 'bg-red-100 text-red-800',
  info: 'bg-blue-100 text-blue-800',
  neutral: clsx('bg-gray-100 text-gray-800'),
};

/** Translucent chips: bg /20, border /70; !text-* beats table td color inheritance */
const BADGE_VARIANTS_DARK: Record<VariantKey, string> = {
  success: 'bg-emerald-500/20 !text-emerald-100 border border-emerald-400/70',
  warning: 'bg-amber-500/20 !text-amber-100 border border-amber-400/70',
  danger: 'bg-red-500/20 !text-red-100 border border-red-400/70',
  info: 'bg-blue-500/20 !text-blue-100 border border-blue-400/70',
  neutral: 'bg-slate-500/20 !text-slate-200 border border-slate-400/70',
};

const BADGE_SIZES: Record<NonNullable<BadgeProps['size']>, string> = {
  sm: 'px-2 py-0.5 text-xs',
  md: 'px-2.5 py-1 text-sm',
};

export function Badge({
  children,
  variant = 'neutral',
  size = 'sm',
  className,
}: BadgeProps) {
  const { theme } = useTheme();
  const isDark = theme === 'dark';
  const variantClasses = isDark ? BADGE_VARIANTS_DARK : BADGE_VARIANTS_LIGHT;

  return (
    <span
      className={clsx(
        'inline-flex items-center font-medium rounded-full',
        variantClasses[variant],
        BADGE_SIZES[size],
        className,
      )}
    >
      {children}
    </span>
  );
}

/**
 * Helper to get badge variant from status string
 */
export function getStatusVariant(status: string): 'success' | 'warning' | 'danger' | 'info' | 'neutral' {
  const statusMap: Record<string, 'success' | 'warning' | 'danger' | 'info' | 'neutral'> = {
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
  };

  return statusMap[status.toLowerCase()] || 'neutral';
}
