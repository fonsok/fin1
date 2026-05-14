import clsx from 'clsx';
import { Button } from './Button';

import { adminBorderChromeDeep, adminLabel, adminStatTitle } from '../../utils/adminThemeClasses';
type PaginationBarProps = {
  page: number;
  pageSize: number;
  total: number;
  itemLabel: string;
  isDark?: boolean;
  onPageChange: (nextPage: number) => void;
};

export function PaginationBar({
  page,
  pageSize,
  total,
  itemLabel,
  isDark = false,
  onPageChange,
}: PaginationBarProps): JSX.Element {
  const totalPages = Math.max(1, Math.ceil(total / pageSize));
  const currentPage = Math.min(page + 1, totalPages);
  const canGoPrev = page > 0;
  const canGoNext = page + 1 < totalPages;
  const from = page * pageSize + 1;
  const to = Math.min((page + 1) * pageSize, total);

  return (
    <div className={clsx('px-6 py-4 border-t flex items-center justify-between', adminBorderChromeDeep(isDark))}>
      <p className={clsx('text-sm', adminStatTitle(isDark))}>
        Zeige {from} bis {to} von {total} {itemLabel}
      </p>
      <div className="flex items-center gap-2">
        <Button variant="secondary" size="sm" disabled={!canGoPrev} onClick={() => onPageChange(0)}>
          |&lt;&lt;
        </Button>
        <Button variant="secondary" size="sm" disabled={!canGoPrev} onClick={() => onPageChange(Math.max(0, page - 1))}>
          Zurück
        </Button>
        <span className={clsx('text-sm px-2', adminLabel(isDark))}>
          Seite {currentPage} / {totalPages}
        </span>
        <Button variant="secondary" size="sm" disabled={!canGoNext} onClick={() => onPageChange(Math.min(totalPages - 1, page + 1))}>
          Weiter &gt;&gt;
        </Button>
        <Button variant="secondary" size="sm" disabled={!canGoNext} onClick={() => onPageChange(totalPages - 1)}>
          &gt;&gt;|
        </Button>
      </div>
    </div>
  );
}
