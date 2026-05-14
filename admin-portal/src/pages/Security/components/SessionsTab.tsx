import clsx from 'clsx';
import { Card, Button } from '../../../components/ui';
import { SortableTh, type SortOrder } from '../../../components/table/SortableTh';
import { useTheme } from '../../../context/ThemeContext';
import { formatDateTime } from '../../../utils/format';
import {
  listRowStripeClasses,
  tableBodyDivideClasses,
  tableTheadSurfaceClasses,
} from '../../../utils/tableStriping';
import type { ActiveSession } from '../types';

import { adminMuted, adminPrimary } from '../../../utils/adminThemeClasses';
interface SessionsTabProps {
  sessions: ActiveSession[];
  onTerminate: (sessionId: string) => void;
  isTerminating: boolean;
  sortBy: string;
  sortOrder: SortOrder;
  onSort: (field: string) => void;
}

export function SessionsTab({
  sessions,
  onTerminate,
  isTerminating,
  sortBy,
  sortOrder,
  onSort,
}: SessionsTabProps): JSX.Element {
  const { theme } = useTheme();
  const isDark = theme === 'dark';
  const thClass = clsx('px-4 py-3 text-xs font-medium uppercase', adminMuted(isDark));

  return (
    <Card>
      <div className="overflow-x-auto">
        <table className="w-full">
          <thead className={tableTheadSurfaceClasses(isDark)}>
            <tr>
              <th className={clsx(thClass, 'text-left')}>Benutzer</th>
              <th className={clsx(thClass, 'text-left')}>IP-Adresse</th>
              <th className={clsx(thClass, 'text-left')}>Gerät</th>
              <SortableTh
                label="Angemeldet seit"
                field="createdAt"
                sortBy={sortBy}
                sortOrder={sortOrder}
                onSort={onSort}
                className={clsx(thClass, 'text-left')}
              />
              <th className={clsx(thClass, 'text-left')}>Letzte Aktivität</th>
              <th className={clsx(thClass, 'text-left')}>Aktionen</th>
            </tr>
          </thead>
          <tbody className={tableBodyDivideClasses(isDark)}>
            {sessions.map((session, index) => (
              <tr key={session.objectId} className={listRowStripeClasses(isDark, index)}>
                <td className={clsx('px-4 py-3 font-medium', adminPrimary(isDark))}>
                  {session.email}
                </td>
                <td className={clsx('px-4 py-3 font-mono text-sm', adminMuted(isDark))}>
                  {session.ipAddress}
                </td>
                <td className={clsx('px-4 py-3', adminMuted(isDark))}>
                  {session.device}
                </td>
                <td className={clsx('px-4 py-3', adminMuted(isDark))}>
                  {formatDateTime(session.createdAt)}
                </td>
                <td className={clsx('px-4 py-3', adminMuted(isDark))}>
                  {formatDateTime(session.lastActivity)}
                </td>
                <td className="px-4 py-3">
                  <Button
                    variant="ghost"
                    size="sm"
                    onClick={() => onTerminate(session.objectId)}
                    disabled={isTerminating}
                  >
                    Beenden
                  </Button>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </Card>
  );
}
