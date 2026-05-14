import clsx from 'clsx';
import { Badge, Card } from '../../../components/ui';
import type { DatabaseStatus } from '../types';

import { adminProse } from '../../../utils/adminThemeClasses';
type Props = {
  isDark: boolean;
  databases: DatabaseStatus[];
};

export function SystemDatabasesCard({ isDark, databases }: Props) {
  return (
    <Card>
      <h3 className="text-md font-semibold mb-4 flex items-center gap-2">
        <svg className="w-5 h-5 text-fin1-primary" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M4 7v10c0 2.21 3.582 4 8 4s8-1.79 8-4V7M4 7c0 2.21 3.582 4 8 4s8-1.79 8-4M4 7c0-2.21 3.582-4 8-4s8 1.79 8 4m0 5c0 2.21-3.582 4-8 4s-8-1.79-8-4" />
        </svg>
        Datenbanken
      </h3>

      <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
        {databases.map((db) => (
          <div
            key={db.name}
            className={clsx(
              'p-4 rounded-lg border',
              db.connected
                ? (isDark ? 'bg-emerald-950/25 border-emerald-700' : 'bg-green-50 border-green-200')
                : (isDark ? 'bg-red-950/25 border-red-700' : 'bg-red-50 border-red-200'),
            )}
          >
            <div className="flex items-center justify-between">
              <div className="flex items-center gap-3">
                <div className={clsx('w-3 h-3 rounded-full', db.connected ? 'bg-green-500' : 'bg-red-500')} />
                <span className="font-medium">{db.name}</span>
              </div>
              <Badge variant={db.connected ? 'success' : 'danger'}>
                {db.connected ? 'Verbunden' : 'Getrennt'}
              </Badge>
            </div>
            {db.version && (
              <p className={clsx('text-sm mt-2', adminProse(isDark))}>
                Version: {db.version}
              </p>
            )}
            {db.collections !== undefined && (
              <p className={clsx('text-sm', adminProse(isDark))}>
                Collections: {db.collections}
              </p>
            )}
          </div>
        ))}
      </div>
    </Card>
  );
}
