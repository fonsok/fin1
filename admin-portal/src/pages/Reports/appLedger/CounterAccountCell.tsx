import clsx from 'clsx';
import type { CounterAccountDisplaySegment } from './counterAccountLabel';
import { adminCaption } from '../../../utils/adminThemeClasses';

interface CounterAccountCellProps {
  segments: CounterAccountDisplaySegment[];
  isDark: boolean;
}

export function CounterAccountCell({ segments, isDark }: CounterAccountCellProps): JSX.Element {
  if (segments.length === 0) {
    return <>-</>;
  }

  return (
    <>
      {segments.map((seg, index) => (
        <span key={`${seg.internalCode}-${index}`}>
          {index > 0 ? ', ' : null}
          {seg.hasCatalogEntry ? (
            <>
              {seg.primaryLabel}{' '}
              <span className={clsx('text-xs font-mono', adminCaption(isDark))}>
                ({seg.internalCode})
              </span>
            </>
          ) : (
            <span className="font-mono">{seg.internalCode}</span>
          )}
        </span>
      ))}
    </>
  );
}
