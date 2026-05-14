import { useState } from 'react';
import clsx from 'clsx';
import { useAuth } from '../../context/AuthContext';
import { useTheme } from '../../context/ThemeContext';
import { Card, Badge } from '../../components/ui';
import { TwoFactorSetup } from './components/TwoFactorSetup';
import { TwoFactorStatusCard } from './components/TwoFactorStatus';
import { formatDateTime } from '../../utils/format';

import { adminLabel, adminMuted, adminPrimary } from '../../utils/adminThemeClasses';
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
        <h1 className={clsx('text-2xl font-bold', adminPrimary(isDark))}>Einstellungen</h1>
        <p className={clsx('mt-1', adminMuted(isDark))}>Konto- und Sicherheitseinstellungen</p>
      </div>

      {/* Profile Card */}
      <Card>
        <div className="p-6">
          <h2 className={clsx('text-lg font-semibold mb-4', adminPrimary(isDark))}>Profil</h2>
          <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
            <div>
              <p className={clsx('text-sm', adminMuted(isDark))}>E-Mail</p>
              <p className={clsx('font-medium', adminPrimary(isDark))}>{user?.email || '-'}</p>
            </div>
            <div>
              <p className={clsx('text-sm', adminMuted(isDark))}>Rolle</p>
              <div className="flex items-center gap-2 mt-1">
                <Badge variant="info">{user?.role || '-'}</Badge>
              </div>
            </div>
            <div>
              <p className={clsx('text-sm', adminMuted(isDark))}>Konto erstellt</p>
              <p className={clsx('font-medium', adminPrimary(isDark))}>{user?.createdAt ? formatDateTime(user.createdAt) : '-'}</p>
            </div>
            <div>
              <p className={clsx('text-sm', adminMuted(isDark))}>Letzter Login</p>
              <p className={clsx('font-medium', adminPrimary(isDark))}>{user?.lastLogin ? formatDateTime(user.lastLogin) : '-'}</p>
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
          <h2 className={clsx('text-lg font-semibold mb-4', adminPrimary(isDark))}>Aktuelle Session</h2>
          <div className={clsx('rounded-lg p-4', isDark ? 'bg-slate-900/40 border border-slate-700' : 'bg-gray-50')}>
            <div className="grid grid-cols-1 md:grid-cols-2 gap-4 text-sm">
              <div>
                <p className={clsx(adminMuted(isDark))}>Browser</p>
                <p className={clsx('font-medium', adminPrimary(isDark))}>{getBrowserInfo()}</p>
              </div>
              <div>
                <p className={clsx(adminMuted(isDark))}>Session-ID</p>
                <p className={clsx('font-mono text-xs truncate', adminLabel(isDark))}>{getSessionPreview()}</p>
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
