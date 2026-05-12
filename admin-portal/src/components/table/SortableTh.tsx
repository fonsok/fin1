import clsx from 'clsx';

export type SortOrder = 'asc' | 'desc';

/**
 * Cycle server list sort: first click sets field (desc); same field toggles asc/desc.
 */
export function nextSortState(
  field: string,
  currentField: string,
  currentOrder: SortOrder,
): { sortBy: string; sortOrder: SortOrder } {
  if (currentField !== field) {
    return { sortBy: field, sortOrder: 'desc' };
  }
  return { sortBy: field, sortOrder: currentOrder === 'desc' ? 'asc' : 'desc' };
}

interface SortableThProps {
  label: string;
  field: string;
  sortBy: string;
  sortOrder: SortOrder;
  onSort: (field: string) => void;
  align?: 'left' | 'right' | 'center';
  className?: string;
  buttonClassName?: string;
}

interface SortChipProps {
  label: string;
  field: string;
  sortBy: string;
  sortOrder: SortOrder;
  onSort: (field: string) => void;
  isDark?: boolean;
}

/** Compact sort control for toolbars (e.g. card lists). */
export function SortChip({
  label,
  field,
  sortBy,
  sortOrder,
  onSort,
  isDark,
}: SortChipProps): JSX.Element {
  const active = sortBy === field;
  return (
    <button
      type="button"
      onClick={() => onSort(field)}
      className={clsx(
        'px-2.5 py-1 text-xs font-medium rounded-md border transition-colors',
        active
          ? 'border-fin1-primary bg-fin1-primary text-white'
          : isDark
            ? 'border-slate-600 text-slate-300 hover:bg-slate-800'
            : 'border-gray-200 text-gray-600 hover:bg-gray-50',
      )}
    >
      {label}
      {active ? (sortOrder === 'asc' ? ' ↑' : ' ↓') : ''}
    </button>
  );
}

export function SortableTh({
  label,
  field,
  sortBy,
  sortOrder,
  onSort,
  align = 'left',
  className,
  buttonClassName,
}: SortableThProps): JSX.Element {
  const active = sortBy === field;
  const alignClass =
    align === 'right' ? 'text-right' : align === 'center' ? 'text-center' : 'text-left';

  return (
    <th className={clsx('text-xs font-medium uppercase tracking-wider', alignClass, className)}>
      <button
        type="button"
        onClick={() => onSort(field)}
        className={clsx(
          'inline-flex items-center gap-0.5 max-w-full hover:underline focus:outline-none focus:ring-2 focus:ring-fin1-primary rounded',
          active ? 'text-fin1-primary font-semibold' : '',
          buttonClassName,
        )}
      >
        <span className="truncate">{label}</span>
        <span className="flex-shrink-0 opacity-70" aria-hidden>
          {active ? (sortOrder === 'asc' ? '↑' : '↓') : '↕'}
        </span>
      </button>
    </th>
  );
}
