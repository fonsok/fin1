import { useState } from 'react';
import { useAuth } from '../../context/AuthContext';
import { Card, Badge } from '../../components/ui';
import { TwoFactorSetup } from './components/TwoFactorSetup';
import { TwoFactorStatusCard } from './components/TwoFactorStatus';
import { formatDateTime } from '../../utils/format';

export function SettingsPage(): JSX.Element {
  const { user, refreshUser } = useAuth();
  const [showSetup, setShowSetup] = useState(false);

  const handleSetupComplete = (): void => {
    setShowSetup(false);
    refreshUser?.();
  };

  const twoFactorEnabled = user?.twoFactorEnabled ?? false;
  const twoFactorEnabledAt = user?.twoFactorEnabledAt;
  const backupCodesRemaining = user?.twoFactorBackupCodesCount;

  return (
    <div className="space-y-6">
      {/* Header */}
      <div>
        <h1 className="text-2xl font-bold text-gray-900">Einstellungen</h1>
        <p className="text-gray-500 mt-1">Konto- und Sicherheitseinstellungen</p>
      </div>

      {/* Profile Card */}
      <Card>
        <div className="p-6">
          <h2 className="text-lg font-semibold mb-4">Profil</h2>
          <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
            <div>
              <p className="text-sm text-gray-500">E-Mail</p>
              <p className="font-medium">{user?.email || '-'}</p>
            </div>
            <div>
              <p className="text-sm text-gray-500">Rolle</p>
              <div className="flex items-center gap-2 mt-1">
                <Badge variant="info">{user?.role || '-'}</Badge>
              </div>
            </div>
            <div>
              <p className="text-sm text-gray-500">Konto erstellt</p>
              <p className="font-medium">{user?.createdAt ? formatDateTime(user.createdAt) : '-'}</p>
            </div>
            <div>
              <p className="text-sm text-gray-500">Letzter Login</p>
              <p className="font-medium">{user?.lastLogin ? formatDateTime(user.lastLogin) : '-'}</p>
            </div>
          </div>
        </div>
      </Card>

      {/* 2FA Section */}
      {showSetup ? (
        <TwoFactorSetup onComplete={handleSetupComplete} />
      ) : (
        <TwoFactorStatusCard
          enabled={twoFactorEnabled}
          enabledAt={twoFactorEnabledAt}
          backupCodesRemaining={backupCodesRemaining}
          onSetupClick={() => setShowSetup(true)}
        />
      )}

      {/* Session Info */}
      <Card>
        <div className="p-6">
          <h2 className="text-lg font-semibold mb-4">Aktuelle Session</h2>
          <div className="bg-gray-50 rounded-lg p-4">
            <div className="grid grid-cols-1 md:grid-cols-2 gap-4 text-sm">
              <div>
                <p className="text-gray-500">Browser</p>
                <p className="font-medium">{getBrowserInfo()}</p>
              </div>
              <div>
                <p className="text-gray-500">Session-ID</p>
                <p className="font-mono text-xs truncate">{getSessionPreview()}</p>
              </div>
            </div>
          </div>
        </div>
      </Card>
    </div>
  );
}

function getBrowserInfo(): string {
  const ua = navigator.userAgent;
  if (ua.includes('Chrome')) return 'Chrome';
  if (ua.includes('Firefox')) return 'Firefox';
  if (ua.includes('Safari')) return 'Safari';
  if (ua.includes('Edge')) return 'Edge';
  return 'Unbekannt';
}

function getSessionPreview(): string {
  const token = localStorage.getItem('sessionToken');
  if (!token) return '-';
  return `${token.substring(0, 8)}...${token.substring(token.length - 4)}`;
}
