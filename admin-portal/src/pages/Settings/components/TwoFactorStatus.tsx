import { useState } from 'react';
import { useMutation, useQueryClient } from '@tanstack/react-query';
import { cloudFunction } from '../../../api/admin';
import { Card, Button, Badge, Input } from '../../../components/ui';
import { formatDateTime } from '../../../utils/format';

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
                <h3 className="font-semibold text-gray-900">Zwei-Faktor-Authentifizierung</h3>
                <p className="text-sm text-gray-500">
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
              <div className="bg-gray-50 rounded-lg p-4">
                <div className="grid grid-cols-2 gap-4 text-sm">
                  <div>
                    <p className="text-gray-500">Aktiviert seit</p>
                    <p className="font-medium">{enabledAt ? formatDateTime(enabledAt) : '-'}</p>
                  </div>
                  <div>
                    <p className="text-gray-500">Backup-Codes übrig</p>
                    <p className={`font-medium ${(backupCodesRemaining || 0) <= 2 ? 'text-red-600' : ''}`}>
                      {backupCodesRemaining ?? '-'} von 8
                    </p>
                  </div>
                </div>
              </div>

              {(backupCodesRemaining || 0) <= 2 && (
                <div className="bg-amber-50 border border-amber-200 rounded-lg p-3">
                  <p className="text-amber-800 text-sm">
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
              <p className="text-gray-600 text-sm mb-4">
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
      <div className="bg-white rounded-xl shadow-xl max-w-md w-full mx-4 p-6">
        <h2 className="text-xl font-semibold mb-2">2FA deaktivieren</h2>
        <p className="text-gray-600 text-sm mb-4">
          Geben Sie Ihr Passwort und einen aktuellen 2FA-Code ein, um die
          Zwei-Faktor-Authentifizierung zu deaktivieren.
        </p>

        <div className="space-y-4">
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">Passwort</label>
            <Input
              type="password"
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              placeholder="Ihr Passwort"
            />
          </div>
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">2FA-Code</label>
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

          {error && <p className="text-red-500 text-sm">{error}</p>}

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
      <div className="bg-white rounded-xl shadow-xl max-w-md w-full mx-4 p-6">
        {newCodes.length === 0 ? (
          <>
            <h2 className="text-xl font-semibold mb-2">Neue Backup-Codes generieren</h2>
            <p className="text-gray-600 text-sm mb-4">
              Geben Sie einen aktuellen 2FA-Code ein. Alle bisherigen Backup-Codes werden ungültig.
            </p>

            <div className="space-y-4">
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">2FA-Code</label>
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

              {error && <p className="text-red-500 text-sm">{error}</p>}

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
              <div className="w-12 h-12 bg-green-100 rounded-full flex items-center justify-center mx-auto mb-3">
                <span className="text-2xl">✅</span>
              </div>
              <h2 className="text-xl font-semibold">Neue Backup-Codes</h2>
            </div>

            <div className="bg-amber-50 border border-amber-200 rounded-lg p-4 mb-4">
              <p className="text-amber-800 text-sm font-medium mb-2">
                ⚠️ Diese Codes werden nur einmal angezeigt!
              </p>
              <div className="grid grid-cols-2 gap-2">
                {newCodes.map((c, i) => (
                  <code key={i} className="bg-white px-3 py-2 rounded border text-center font-mono text-sm">
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
