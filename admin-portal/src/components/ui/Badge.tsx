import React from 'react';
import clsx from 'clsx';
import { useTheme } from '../../context/ThemeContext';

interface BadgeProps {
  children: React.ReactNode;
  variant?: 'success' | 'warning' | 'danger' | 'info' | 'neutral';
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
  const variants = {
    success: isDark ? 'bg-emerald-600/30 text-emerald-100 border border-emerald-500/40' : 'bg-green-100 text-green-800',
    warning: isDark ? 'bg-amber-600/30 text-amber-100 border border-amber-500/40' : 'bg-amber-100 text-amber-800',
    danger: isDark ? 'bg-red-600/30 text-red-100 border border-red-500/40' : 'bg-red-100 text-red-800',
    info: isDark ? 'bg-blue-600/30 text-blue-100 border border-blue-500/40' : 'bg-blue-100 text-blue-800',
    neutral: isDark ? 'bg-slate-600/40 text-slate-100 border border-slate-500/40' : 'bg-gray-100 text-gray-800',
  };

  const sizes = {
    sm: 'px-2 py-0.5 text-xs',
    md: 'px-2.5 py-1 text-sm',
  };

  return (
    <span className={clsx(
      'inline-flex items-center font-medium rounded-full',
      variants[variant],
      sizes[size],
      className
    )}>
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
