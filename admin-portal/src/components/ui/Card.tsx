import React from 'react';
import clsx from 'clsx';
import { useTheme } from '../../context/ThemeContext';

interface CardProps extends React.HTMLAttributes<HTMLDivElement> {
  children: React.ReactNode;
  className?: string;
  padding?: 'none' | 'sm' | 'md' | 'lg';
}

export function Card({ children, className, padding = 'md', ...props }: CardProps) {
  const { theme } = useTheme();

  const paddingStyles = {
    none: '',
    sm: 'p-4',
    md: 'p-6',
    lg: 'p-8',
  };

  const baseClasses = clsx(
    theme === 'dark'
      ? 'fin1-card bg-slate-700/90 rounded-xl shadow-sm border border-slate-600 text-slate-100'
      : 'fin1-card bg-white rounded-xl shadow-sm border border-gray-100 text-gray-900',
  );

  return (
    <div
      className={clsx(baseClasses, paddingStyles[padding], className)}
      {...props}
    >
      {children}
    </div>
  );
}

interface CardHeaderProps {
  title: string;
  subtitle?: string;
  action?: React.ReactNode;
}

export function CardHeader({ title, subtitle, action }: CardHeaderProps) {
  const { theme } = useTheme();
  const isDark = theme === 'dark';

  return (
    <div className="flex items-center justify-between mb-4">
      <div>
        <h3
          className={clsx(
            'text-lg font-semibold',
            isDark ? 'text-slate-100' : 'text-gray-900',
          )}
        >
          {title}
        </h3>
        {subtitle && (
          <p
            className={clsx(
              'text-sm mt-0.5',
              isDark ? 'text-slate-400' : 'text-gray-500',
            )}
          >
            {subtitle}
          </p>
        )}
      </div>
      {action && <div>{action}</div>}
    </div>
  );
}
