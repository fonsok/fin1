import React from 'react';
import clsx from 'clsx';

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
  const variants = {
    success: 'bg-green-100 text-green-800',
    warning: 'bg-amber-100 text-amber-800',
    danger: 'bg-red-100 text-red-800',
    info: 'bg-blue-100 text-blue-800',
    neutral: 'bg-gray-100 text-gray-800',
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
