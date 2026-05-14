import clsx from 'clsx';
import type { ReactNode } from 'react';
import { Card } from '../../../components/ui';
import { formatDateTime } from '../../../utils/format';
import {
  listRowStripeClasses,
  tableBodyDivideClasses,
  tableHeaderCellTextClasses,
  tableTheadSurfaceClasses,
} from '../../../utils/tableStriping';
import type { ServiceStatus } from '../types';

import { adminMuted, adminPrimary, adminSoft } from '../../../utils/adminThemeClasses';
type Props = {
  isDark: boolean;
  services: ServiceStatus[];
  renderStatusBadge: (status: ServiceStatus['status']) => ReactNode;
};

export function SystemServicesCard({ isDark, services, renderStatusBadge }: Props) {
  return (
    <Card>
      <h3 className="text-md font-semibold mb-4 flex items-center gap-2">
        <svg className="w-5 h-5 text-fin1-primary" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M5 12h14M5 12a2 2 0 01-2-2V6a2 2 0 012-2h14a2 2 0 012 2v4a2 2 0 01-2 2M5 12a2 2 0 00-2 2v4a2 2 0 002 2h14a2 2 0 002-2v-4a2 2 0 00-2-2m-2-4h.01M17 16h.01" />
        </svg>
        Services
      </h3>

      <div className="overflow-x-auto">
        <table className="w-full">
          <thead className={tableTheadSurfaceClasses(isDark)}>
            <tr>
              <th className={clsx('px-4 py-3 text-left text-xs font-medium uppercase', tableHeaderCellTextClasses(isDark))}>Service</th>
              <th className={clsx('px-4 py-3 text-left text-xs font-medium uppercase', tableHeaderCellTextClasses(isDark))}>Status</th>
              <th className={clsx('px-4 py-3 text-left text-xs font-medium uppercase', tableHeaderCellTextClasses(isDark))}>Antwortzeit</th>
              <th className={clsx('px-4 py-3 text-left text-xs font-medium uppercase', tableHeaderCellTextClasses(isDark))}>Letzte Pruefung</th>
            </tr>
          </thead>
          <tbody className={tableBodyDivideClasses(isDark)}>
            {services.map((service, index) => (
              <tr key={service.name} className={listRowStripeClasses(isDark, index)}>
                <td className="px-4 py-3">
                  <span className={clsx('font-medium', adminPrimary(isDark))}>
                    {service.name}
                  </span>
                </td>
                <td className="px-4 py-3">{renderStatusBadge(service.status)}</td>
                <td className={clsx('px-4 py-3 text-sm', adminSoft(isDark))}>
                  {service.responseTime ? `${service.responseTime}ms` : '-'}
                </td>
                <td className={clsx('px-4 py-3 text-sm', adminMuted(isDark))}>
                  {formatDateTime(service.lastCheck)}
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </Card>
  );
}
