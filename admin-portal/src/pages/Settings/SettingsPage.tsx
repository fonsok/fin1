import { useState } from 'react';
import clsx from 'clsx';
import { useAuth } from '../../context/AuthContext';
import { useTheme } from '../../context/ThemeContext';
import { Card, Badge } from '../../components/ui';
import { TwoFactorSetup } from './components/TwoFactorSetup';
import { TwoFactorStatusCard } from './components/TwoFactorStatus';
import { formatDateTime } from '../../utils/format';

export function SettingsPage(): JSX.Element {
  const { user, refreshUser } = useAuth();
  const { theme } = useTheme();
  const isDark = theme === 'dark';
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
        <h1 className={clsx('text-2xl font-bold', isDark ? 'text-slate-100' : 'text-gray-900')}>Einstellungen</h1>
        <p className={clsx('mt-1', isDark ? 'text-slate-400' : 'text-gray-500')}>Konto- und Sicherheitseinstellungen</p>
      </div>

      {/* Profile Card */}
      <Card>
        <div className="p-6">
          <h2 className={clsx('text-lg font-semibold mb-4', isDark ? 'text-slate-100' : 'text-gray-900')}>Profil</h2>
          <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
            <div>
              <p className={clsx('text-sm', isDark ? 'text-slate-400' : 'text-gray-500')}>E-Mail</p>
              <p className={clsx('font-medium', isDark ? 'text-slate-100' : 'text-gray-900')}>{user?.email || '-'}</p>
            </div>
            <div>
              <p className={clsx('text-sm', isDark ? 'text-slate-400' : 'text-gray-500')}>Rolle</p>
              <div className="flex items-center gap-2 mt-1">
                <Badge variant="info">{user?.role || '-'}</Badge>
              </div>
            </div>
            <div>
              <p className={clsx('text-sm', isDark ? 'text-slate-400' : 'text-gray-500')}>Konto erstellt</p>
              <p className={clsx('font-medium', isDark ? 'text-slate-100' : 'text-gray-900')}>{user?.createdAt ? formatDateTime(user.createdAt) : '-'}</p>
            </div>
            <div>
              <p className={clsx('text-sm', isDark ? 'text-slate-400' : 'text-gray-500')}>Letzter Login</p>
              <p className={clsx('font-medium', isDark ? 'text-slate-100' : 'text-gray-900')}>{user?.lastLogin ? formatDateTime(user.lastLogin) : '-'}</p>
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
          <h2 className={clsx('text-lg font-semibold mb-4', isDark ? 'text-slate-100' : 'text-gray-900')}>Aktuelle Session</h2>
          <div className={clsx('rounded-lg p-4', isDark ? 'bg-slate-900/40 border border-slate-700' : 'bg-gray-50')}>
            <div className="grid grid-cols-1 md:grid-cols-2 gap-4 text-sm">
              <div>
                <p className={clsx(isDark ? 'text-slate-400' : 'text-gray-500')}>Browser</p>
                <p className={clsx('font-medium', isDark ? 'text-slate-100' : 'text-gray-900')}>{getBrowserInfo()}</p>
              </div>
              <div>
                <p className={clsx(isDark ? 'text-slate-400' : 'text-gray-500')}>Session-ID</p>
                <p className={clsx('font-mono text-xs truncate', isDark ? 'text-slate-300' : 'text-gray-700')}>{getSessionPreview()}</p>
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
