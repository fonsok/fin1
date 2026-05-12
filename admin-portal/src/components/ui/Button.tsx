import React from 'react';
import clsx from 'clsx';
import { useTheme } from '../../context/ThemeContext';

interface ButtonProps extends React.ButtonHTMLAttributes<HTMLButtonElement> {
  variant?: 'primary' | 'secondary' | 'danger' | 'success' | 'warning' | 'ghost';
  size?: 'sm' | 'md' | 'lg';
  loading?: boolean;
  icon?: React.ReactNode;
}

export function Button({
  children,
  variant = 'primary',
  size = 'md',
  loading = false,
  icon,
  className,
  disabled,
  ...props
}: ButtonProps) {
  const { theme } = useTheme();
  const isDark = theme === 'dark';
  const baseStyles = 'inline-flex items-center justify-center font-medium rounded-lg transition-colors duration-200 focus:outline-none focus:ring-2 focus:ring-offset-2 disabled:opacity-50 disabled:cursor-not-allowed';

  const variants = {
    primary: 'bg-fin1-primary text-white hover:bg-fin1-secondary focus:ring-fin1-primary',
    secondary: isDark
      ? 'bg-slate-700 text-slate-100 border border-slate-500 hover:bg-slate-600 focus:ring-fin1-primary'
      : 'bg-white text-fin1-primary border border-fin1-primary hover:bg-fin1-light focus:ring-fin1-primary',
    danger: isDark
      ? 'bg-red-600/25 text-red-100 border border-red-500/35 hover:bg-red-600/38 focus:ring-red-500/40'
      : 'bg-red-500/14 text-red-800 border border-red-400/45 hover:bg-red-500/22 focus:ring-red-400/80',
    success: 'bg-fin1-success text-white hover:bg-emerald-600 focus:ring-fin1-success',
    warning: 'bg-amber-500 text-white hover:bg-amber-600 focus:ring-amber-500',
    ghost: isDark
      ? 'bg-transparent text-slate-200 hover:bg-slate-700/80 focus:ring-fin1-primary'
      : 'bg-transparent text-fin1-primary hover:bg-fin1-light focus:ring-fin1-primary',
  };

  const focusOffset = isDark ? 'focus:ring-offset-slate-800' : 'focus:ring-offset-white';

  const sizes = {
    sm: 'px-3 py-1.5 text-sm',
    md: 'px-4 py-2 text-sm',
    lg: 'px-6 py-3 text-base',
  };

  return (
    <button
      className={clsx(baseStyles, focusOffset, variants[variant], sizes[size], className)}
      disabled={disabled || loading}
      {...props}
    >
      {loading ? (
        <svg className="animate-spin -ml-1 mr-2 h-4 w-4" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
          <circle className="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="4"></circle>
          <path className="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
        </svg>
      ) : icon ? (
        <span className="mr-2">{icon}</span>
      ) : null}
      {children}
    </button>
  );
}
