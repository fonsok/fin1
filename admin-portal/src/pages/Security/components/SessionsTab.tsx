import { Card, Button } from '../../../components/ui';
import { formatDateTime } from '../../../utils/format';
import type { ActiveSession } from '../types';

interface SessionsTabProps {
  sessions: ActiveSession[];
  onTerminate: (sessionId: string) => void;
  isTerminating: boolean;
}

export function SessionsTab({ sessions, onTerminate, isTerminating }: SessionsTabProps): JSX.Element {
  return (
    <Card>
      <div className="overflow-x-auto">
        <table className="w-full">
          <thead className="bg-gray-50">
            <tr>
              <th className="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase">Benutzer</th>
              <th className="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase">IP-Adresse</th>
              <th className="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase">Gerät</th>
              <th className="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase">Angemeldet seit</th>
              <th className="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase">Letzte Aktivität</th>
              <th className="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase">Aktionen</th>
            </tr>
          </thead>
          <tbody className="divide-y divide-gray-100">
            {sessions.map((session) => (
              <tr key={session.objectId} className="hover:bg-gray-50">
                <td className="px-4 py-3 font-medium text-gray-900">{session.email}</td>
                <td className="px-4 py-3 text-gray-500 font-mono text-sm">{session.ipAddress}</td>
                <td className="px-4 py-3 text-gray-500">{session.device}</td>
                <td className="px-4 py-3 text-gray-500">{formatDateTime(session.createdAt)}</td>
                <td className="px-4 py-3 text-gray-500">{formatDateTime(session.lastActivity)}</td>
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
