import { Card } from '../../../components/ui';
import { formatDateTime } from '../../../utils/format';
import type { FailedLogin } from '../types';

interface LoginsTabProps {
  failedLogins: FailedLogin[];
}

export function LoginsTab({ failedLogins }: LoginsTabProps): JSX.Element {
  return (
    <Card>
      <div className="overflow-x-auto">
        <table className="w-full">
          <thead className="bg-gray-50">
            <tr>
              <th className="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase">E-Mail</th>
              <th className="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase">IP-Adresse</th>
              <th className="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase">Gerät</th>
              <th className="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase">Grund</th>
              <th className="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase">Zeitpunkt</th>
            </tr>
          </thead>
          <tbody className="divide-y divide-gray-100">
            {failedLogins.map((login) => (
              <tr key={login.objectId} className="hover:bg-gray-50">
                <td className="px-4 py-3 font-medium text-gray-900">{login.email}</td>
                <td className="px-4 py-3 text-gray-500 font-mono text-sm">{login.ipAddress}</td>
                <td className="px-4 py-3 text-gray-500 text-sm truncate max-w-[200px]">{login.userAgent}</td>
                <td className="px-4 py-3 text-gray-500">{login.reason}</td>
                <td className="px-4 py-3 text-gray-500">{formatDateTime(login.timestamp)}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </Card>
  );
}
