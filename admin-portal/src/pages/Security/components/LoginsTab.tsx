import clsx from 'clsx';
import { Card } from '../../../components/ui';
import { SortableTh, type SortOrder } from '../../../components/table/SortableTh';
import { useTheme } from '../../../context/ThemeContext';
import { formatDateTime } from '../../../utils/format';
import { listRowStripeClasses, tableBodyDivideClasses, tableTheadSurfaceClasses } from '../../../utils/tableStriping';
import type { FailedLogin } from '../types';

import { adminMuted, adminPrimary } from '../../../utils/adminThemeClasses';
interface LoginsTabProps {
  failedLogins: FailedLogin[];
  sortBy: string;
  sortOrder: SortOrder;
  onSort: (field: string) => void;
}

export function LoginsTab({ failedLogins, sortBy, sortOrder, onSort }: LoginsTabProps): JSX.Element {
  const { theme } = useTheme();
  const isDark = theme === 'dark';
  const thClass = clsx('px-4 py-3 text-xs font-medium uppercase', adminMuted(isDark));

  return (
    <Card>
      <div className="overflow-x-auto">
        <table className="w-full">
          <thead className={tableTheadSurfaceClasses(isDark)}>
            <tr>
              <th className={clsx(thClass, 'text-left')}>E-Mail</th>
              <th className={clsx(thClass, 'text-left')}>IP-Adresse</th>
              <th className={clsx(thClass, 'text-left')}>Gerät</th>
              <th className={clsx(thClass, 'text-left')}>Grund</th>
              <SortableTh
                label="Zeitpunkt"
                field="createdAt"
                sortBy={sortBy}
                sortOrder={sortOrder}
                onSort={onSort}
                className={clsx(thClass, 'text-left')}
              />
            </tr>
          </thead>
          <tbody className={tableBodyDivideClasses(isDark)}>
            {failedLogins.map((login, index) => (
              <tr key={login.objectId} className={listRowStripeClasses(isDark, index)}>
                <td className={clsx('px-4 py-3 font-medium', adminPrimary(isDark))}>
                  {login.email}
                </td>
                <td className={clsx('px-4 py-3 font-mono text-sm', adminMuted(isDark))}>
                  {login.ipAddress}
                </td>
                <td className={clsx('px-4 py-3 text-sm truncate max-w-[200px]', adminMuted(isDark))}>
                  {login.userAgent}
                </td>
                <td className={clsx('px-4 py-3', adminMuted(isDark))}>
                  {login.reason}
                </td>
                <td className={clsx('px-4 py-3', adminMuted(isDark))}>
                  {formatDateTime(login.timestamp)}
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </Card>
  );
}
