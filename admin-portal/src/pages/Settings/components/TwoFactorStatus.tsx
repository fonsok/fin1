import { useState } from 'react';
import { useMutation, useQueryClient } from '@tanstack/react-query';
import clsx from 'clsx';
import { cloudFunction } from '../../../api/admin';
import { Card, Button, Badge, Input } from '../../../components/ui';
import { useTheme } from '../../../context/ThemeContext';
import { formatDateTime } from '../../../utils/format';

import { adminMuted, adminPrimary, adminSoft, adminStrong, adminSurfacePanelMuted } from '../../../utils/adminThemeClasses';
interface TwoFactorStatusProps {
  enabled: boolean;
  enabledAt?: string;
  backupCodesRemaining?: number;
  onSetupClick: () => void;
}

export function TwoFactorStatusCard({
  enabled,
  enabledAt,
  backupCodesRemaining,
  onSetupClick,
}: TwoFactorStatusProps): JSX.Element {
  const { theme } = useTheme();
  const isDark = theme === 'dark';
  const [showDisableModal, setShowDisableModal] = useState(false);
  const [showRegenerateModal, setShowRegenerateModal] = useState(false);

  return (
    <>
      <Card>
        <div className="p-6">
          <div className="flex items-center justify-between mb-4">
            <div className="flex items-center gap-3">
              <div className="w-10 h-10 bg-fin1-light rounded-lg flex items-center justify-center">
                <span className="text-xl">🔐</span>
              </div>
              <div>
                <h3 className={clsx('font-semibold', adminPrimary(isDark))}>
                  Zwei-Faktor-Authentifizierung
                </h3>
                <p className={clsx('text-sm', adminMuted(isDark))}>
                  {enabled ? 'Zusätzlicher Schutz ist aktiv' : 'Nicht aktiviert'}
                </p>
              </div>
            </div>
            <Badge variant={enabled ? 'success' : 'warning'}>
              {enabled ? 'Aktiv' : 'Inaktiv'}
            </Badge>
          </div>

          {enabled ? (
            <div className="space-y-4">
              <div
                className={clsx(
                  'rounded-lg p-4',
                  adminSurfacePanelMuted(isDark),
                )}
              >
                <div className="grid grid-cols-2 gap-4 text-sm">
                  <div>
                    <p className={clsx(adminMuted(isDark))}>Aktiviert seit</p>
                    <p className={clsx('font-medium', adminPrimary(isDark))}>
                      {enabledAt ? formatDateTime(enabledAt) : '-'}
                    </p>
                  </div>
                  <div>
                    <p className={clsx(adminMuted(isDark))}>Backup-Codes übrig</p>
                    <p
                      className={clsx(
                        'font-medium',
                        adminPrimary(isDark),
                        (backupCodesRemaining || 0) <= 2 && 'text-red-600',
                      )}
                    >
                      {backupCodesRemaining ?? '-'} von 8
                    </p>
                  </div>
                </div>
              </div>

              {(backupCodesRemaining || 0) <= 2 && (
                <div
                  className={clsx(
                    'rounded-lg border p-3',
                    isDark ? 'bg-amber-950/40 border-amber-800' : 'bg-amber-50 border-amber-200',
                  )}
                >
                  <p className={clsx('text-sm', isDark ? 'text-amber-200' : 'text-amber-800')}>
                    ⚠️ Sie haben nur noch wenige Backup-Codes. Generieren Sie neue, bevor alle aufgebraucht sind.
                  </p>
                </div>
              )}

              <div className="flex gap-3">
                <Button variant="ghost" onClick={() => setShowRegenerateModal(true)}>
                  Neue Backup-Codes
                </Button>
                <Button variant="danger" onClick={() => setShowDisableModal(true)}>
                  2FA deaktivieren
                </Button>
              </div>
            </div>
          ) : (
            <div>
              <p className={clsx('text-sm mb-4', adminSoft(isDark))}>
                Aktivieren Sie 2FA für zusätzlichen Schutz. Bei jedem Login müssen Sie dann
                einen Code aus Ihrer Authenticator-App eingeben.
              </p>
              <Button onClick={onSetupClick}>2FA aktivieren</Button>
            </div>
          )}
        </div>
      </Card>

      {showDisableModal && (
        <DisableModal onClose={() => setShowDisableModal(false)} />
      )}

      {showRegenerateModal && (
        <RegenerateModal onClose={() => setShowRegenerateModal(false)} />
      )}
    </>
  );
}

function DisableModal({ onClose }: { onClose: () => void }): JSX.Element {
  const { theme } = useTheme();
  const isDark = theme === 'dark';
  const [code, setCode] = useState('');
  const [password, setPassword] = useState('');
  const [error, setError] = useState('');
  const queryClient = useQueryClient();

  const mutation = useMutation({
    mutationFn: () => cloudFunction('disable2FA', { code, password }),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['currentUser'] });
      onClose();
    },
    onError: (err: Error) => {
      setError(err.message || 'Deaktivierung fehlgeschlagen');
    },
  });

  return (
    <div className="fixed inset-0 bg-black/50 flex items-center justify-center z-50">
      <div
        className={clsx(
          'rounded-xl shadow-xl max-w-md w-full mx-4 p-6 border',
          isDark ? 'bg-slate-800 border-slate-600 text-slate-100' : 'bg-white border-gray-100 text-gray-900',
        )}
      >
        <h2 className={clsx('text-xl font-semibold mb-2', adminPrimary(isDark))}>
          2FA deaktivieren
        </h2>
        <p className={clsx('text-sm mb-4', adminSoft(isDark))}>
          Geben Sie Ihr Passwort und einen aktuellen 2FA-Code ein, um die
          Zwei-Faktor-Authentifizierung zu deaktivieren.
        </p>

        <div className="space-y-4">
          <div>
            <label className={clsx('block text-sm font-medium mb-1', adminStrong(isDark))}>
              Passwort
            </label>
            <Input
              type="password"
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              placeholder="Ihr Passwort"
            />
          </div>
          <div>
            <label className={clsx('block text-sm font-medium mb-1', adminStrong(isDark))}>
              2FA-Code
            </label>
            <Input
              type="text"
              inputMode="numeric"
              maxLength={6}
              value={code}
              onChange={(e) => setCode(e.target.value.replace(/\D/g, ''))}
              placeholder="000000"
              className="font-mono"
            />
          </div>

          {error && <p className={clsx('text-sm', isDark ? 'text-red-400' : 'text-red-500')}>{error}</p>}

          <div className="flex gap-3 pt-2">
            <Button variant="ghost" onClick={onClose}>Abbrechen</Button>
            <Button
              variant="danger"
              onClick={() => mutation.mutate()}
              disabled={!password || code.length !== 6 || mutation.isPending}
              className="flex-1"
            >
              {mutation.isPending ? 'Wird deaktiviert...' : 'Deaktivieren'}
            </Button>
          </div>
        </div>
      </div>
    </div>
  );
}

function RegenerateModal({ onClose }: { onClose: () => void }): JSX.Element {
  const { theme } = useTheme();
  const isDark = theme === 'dark';
  const [code, setCode] = useState('');
  const [newCodes, setNewCodes] = useState<string[]>([]);
  const [error, setError] = useState('');
  const queryClient = useQueryClient();

  const mutation = useMutation({
    mutationFn: () => cloudFunction<{ backupCodes: string[] }>('regenerateBackupCodes', { code }),
    onSuccess: (data) => {
      setNewCodes(data.backupCodes);
      queryClient.invalidateQueries({ queryKey: ['currentUser'] });
    },
    onError: (err: Error) => {
      setError(err.message || 'Generierung fehlgeschlagen');
    },
  });

  const copyBackupCodes = (): void => {
    navigator.clipboard.writeText(newCodes.join('\n'));
    alert('Backup-Codes in Zwischenablage kopiert');
  };

  return (
    <div className="fixed inset-0 bg-black/50 flex items-center justify-center z-50">
      <div
        className={clsx(
          'rounded-xl shadow-xl max-w-md w-full mx-4 p-6 border',
          isDark ? 'bg-slate-800 border-slate-600 text-slate-100' : 'bg-white border-gray-100 text-gray-900',
        )}
      >
        {newCodes.length === 0 ? (
          <>
            <h2 className={clsx('text-xl font-semibold mb-2', adminPrimary(isDark))}>
              Neue Backup-Codes generieren
            </h2>
            <p className={clsx('text-sm mb-4', adminSoft(isDark))}>
              Geben Sie einen aktuellen 2FA-Code ein. Alle bisherigen Backup-Codes werden ungültig.
            </p>

            <div className="space-y-4">
              <div>
                <label className={clsx('block text-sm font-medium mb-1', adminStrong(isDark))}>
                  2FA-Code
                </label>
                <Input
                  type="text"
                  inputMode="numeric"
                  maxLength={6}
                  value={code}
                  onChange={(e) => setCode(e.target.value.replace(/\D/g, ''))}
                  placeholder="000000"
                  className="font-mono"
                  autoFocus
                />
              </div>

              {error && <p className={clsx('text-sm', isDark ? 'text-red-400' : 'text-red-500')}>{error}</p>}

              <div className="flex gap-3 pt-2">
                <Button variant="ghost" onClick={onClose}>Abbrechen</Button>
                <Button
                  onClick={() => mutation.mutate()}
                  disabled={code.length !== 6 || mutation.isPending}
                  className="flex-1"
                >
                  {mutation.isPending ? 'Wird generiert...' : 'Codes generieren'}
                </Button>
              </div>
            </div>
          </>
        ) : (
          <>
            <div className="text-center mb-4">
              <div
                className={clsx(
                  'w-12 h-12 rounded-full flex items-center justify-center mx-auto mb-3',
                  isDark ? 'bg-green-900/50' : 'bg-green-100',
                )}
              >
                <span className="text-2xl">✅</span>
              </div>
              <h2 className={clsx('text-xl font-semibold', adminPrimary(isDark))}>
                Neue Backup-Codes
              </h2>
            </div>

            <div
              className={clsx(
                'rounded-lg border p-4 mb-4',
                isDark ? 'bg-amber-950/40 border-amber-800' : 'bg-amber-50 border-amber-200',
              )}
            >
              <p className={clsx('text-sm font-medium mb-2', isDark ? 'text-amber-200' : 'text-amber-800')}>
                ⚠️ Diese Codes werden nur einmal angezeigt!
              </p>
              <div className="grid grid-cols-2 gap-2">
                {newCodes.map((c, i) => (
                  <code
                    key={i}
                    className={clsx(
                      'px-3 py-2 rounded border text-center font-mono text-sm',
                      isDark ? 'bg-slate-900 border-slate-600 text-slate-100' : 'bg-white border-gray-200 text-gray-900',
                    )}
                  >
                    {c}
                  </code>
                ))}
              </div>
            </div>

            <div className="flex gap-3">
              <Button variant="ghost" onClick={copyBackupCodes}>Kopieren</Button>
              <Button onClick={onClose} className="flex-1">Fertig</Button>
            </div>
          </>
        )}
      </div>
    </div>
  );
}
