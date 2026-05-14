import { useState } from 'react';
import { useMutation } from '@tanstack/react-query';
import clsx from 'clsx';
import { cloudFunction } from '../../../api/admin';
import { Card, Button, Input } from '../../../components/ui';
import { useTheme } from '../../../context/ThemeContext';
import type { TwoFactorSetupResponse, TwoFactorEnableResponse } from '../types';

import { adminBodyStrong, adminMuted, adminPrimary, adminSoft, adminStrong, adminSurfacePanelMuted } from '../../../utils/adminThemeClasses';
interface TwoFactorSetupProps {
  onComplete: () => void;
}

type Step = 'start' | 'scan' | 'verify' | 'backup';

export function TwoFactorSetup({ onComplete }: TwoFactorSetupProps): JSX.Element {
  const { theme } = useTheme();
  const isDark = theme === 'dark';
  const [step, setStep] = useState<Step>('start');
  const [setupData, setSetupData] = useState<TwoFactorSetupResponse | null>(null);
  const [backupCodes, setBackupCodes] = useState<string[]>([]);
  const [verifyCode, setVerifyCode] = useState('');
  const [error, setError] = useState('');

  const setupMutation = useMutation({
    mutationFn: () => cloudFunction<TwoFactorSetupResponse>('setup2FA', {}),
    onSuccess: (data) => {
      setSetupData(data);
      setStep('scan');
      setError('');
    },
    onError: (err: Error) => {
      setError(err.message || 'Setup fehlgeschlagen');
    },
  });

  const enableMutation = useMutation({
    mutationFn: (code: string) => cloudFunction<TwoFactorEnableResponse>('enable2FA', { code }),
    onSuccess: (data) => {
      setBackupCodes(data.backupCodes);
      setStep('backup');
      setError('');
    },
    onError: (err: Error) => {
      setError(err.message || 'Verifizierung fehlgeschlagen');
    },
  });

  const handleVerify = (): void => {
    if (verifyCode.length !== 6) {
      setError('Bitte geben Sie einen 6-stelligen Code ein');
      return;
    }
    enableMutation.mutate(verifyCode);
  };

  const copyBackupCodes = (): void => {
    const text = backupCodes.join('\n');
    navigator.clipboard.writeText(text);
    alert('Backup-Codes in Zwischenablage kopiert');
  };

  const titleClass = clsx('text-xl font-semibold mb-2', adminPrimary(isDark));
  const bodyMuted = clsx(adminSoft(isDark));
  const infoBox = clsx(
    'rounded-lg p-4 mb-6 text-left',
    adminSurfacePanelMuted(isDark),
  );
  const listText = clsx('text-sm space-y-1', adminSoft(isDark));
  const listHeading = clsx('text-sm font-medium mb-2', adminStrong(isDark));

  return (
    <Card className="max-w-lg">
      <div className="p-6">
        {/* Step 1: Start */}
        {step === 'start' && (
          <div className="text-center">
            <div className="w-16 h-16 bg-fin1-light rounded-full flex items-center justify-center mx-auto mb-4">
              <span className="text-3xl">🔐</span>
            </div>
            <h2 className={titleClass}>2FA aktivieren</h2>
            <p className={clsx('mb-6', bodyMuted)}>
              Schützen Sie Ihr Konto mit Zwei-Faktor-Authentifizierung. Sie benötigen eine
              Authenticator-App auf Ihrem Smartphone.
            </p>
            <div className={infoBox}>
              <p className={listHeading}>Kompatible Apps:</p>
              <ul className={listText}>
                <li>• <strong>Authy</strong> (iOS, Android)</li>
                <li>• <strong>1Password</strong> (alle Plattformen)</li>
                <li>• <strong>Bitwarden</strong> (alle Plattformen)</li>
                <li>• <strong>FreeOTP</strong> (iOS, Android)</li>
                <li>• <strong>iOS Passwörter</strong> (ab iOS 15)</li>
                <li>• Jede TOTP-kompatible App</li>
              </ul>
            </div>
            {error && (
              <p className={clsx('text-sm mb-4', isDark ? 'text-red-400' : 'text-red-500')}>{error}</p>
            )}
            <Button onClick={() => setupMutation.mutate()} disabled={setupMutation.isPending} className="w-full">
              {setupMutation.isPending ? 'Wird vorbereitet...' : 'Setup starten'}
            </Button>
          </div>
        )}

        {/* Step 2: Scan QR Code */}
        {step === 'scan' && setupData && (
          <div className="text-center">
            <h2 className={titleClass}>QR-Code scannen</h2>
            <p className={clsx('mb-4', bodyMuted)}>
              Scannen Sie diesen QR-Code mit Ihrer Authenticator-App.
            </p>

            {setupData.qrCodeUrl ? (
              <div
                className={clsx(
                  'p-4 rounded-lg border inline-block mb-4',
                  isDark ? 'bg-white border-slate-500' : 'bg-white border-gray-200',
                )}
              >
                <img src={setupData.qrCodeUrl} alt="2FA QR Code" className="w-48 h-48" />
              </div>
            ) : (
              <div
                className={clsx(
                  'p-4 rounded-lg mb-4',
                  isDark ? 'bg-slate-900/70 border border-slate-600' : 'bg-gray-100',
                )}
              >
                <p className={clsx('text-sm mb-2', adminMuted(isDark))}>
                  QR-Code nicht verfügbar. Manueller Schlüssel:
                </p>
                <code
                  className={clsx(
                    'px-2 py-1 rounded text-sm font-mono break-all',
                    isDark ? 'bg-slate-950 text-slate-100' : 'bg-gray-200 text-gray-900',
                  )}
                >
                  {setupData.secret}
                </code>
              </div>
            )}

            <details className="text-left mb-4">
              <summary
                className={clsx('text-sm cursor-pointer', adminMuted(isDark))}
              >
                Manuelle Eingabe (falls QR-Scan nicht möglich)
              </summary>
              <div
                className={clsx(
                  'mt-2 p-3 rounded-lg',
                  adminSurfacePanelMuted(isDark),
                )}
              >
                <p className={clsx('text-xs mb-1', adminMuted(isDark))}>Geheimschlüssel:</p>
                <code className={clsx('text-sm font-mono break-all', adminBodyStrong(isDark))}>
                  {setupData.secret}
                </code>
                <p className={clsx('text-xs mt-2 mb-1', adminMuted(isDark))}>Konto:</p>
                <code className={clsx('text-sm', adminBodyStrong(isDark))}>FIN1 Admin</code>
              </div>
            </details>

            <Button onClick={() => setStep('verify')} className="w-full">
              Weiter
            </Button>
          </div>
        )}

        {/* Step 3: Verify Code */}
        {step === 'verify' && (
          <div className="text-center">
            <h2 className={titleClass}>Code verifizieren</h2>
            <p className={clsx('mb-6', bodyMuted)}>
              Geben Sie den 6-stelligen Code aus Ihrer Authenticator-App ein.
            </p>

            <Input
              type="text"
              inputMode="numeric"
              pattern="[0-9]*"
              maxLength={6}
              value={verifyCode}
              onChange={(e) => setVerifyCode(e.target.value.replace(/\D/g, ''))}
              placeholder="000000"
              className="text-center text-2xl font-mono tracking-widest mb-4"
              autoFocus
            />

            {error && (
              <p className={clsx('text-sm mb-4', isDark ? 'text-red-400' : 'text-red-500')}>{error}</p>
            )}

            <div className="flex gap-3">
              <Button variant="ghost" onClick={() => setStep('scan')}>
                Zurück
              </Button>
              <Button
                onClick={handleVerify}
                disabled={verifyCode.length !== 6 || enableMutation.isPending}
                className="flex-1"
              >
                {enableMutation.isPending ? 'Wird verifiziert...' : 'Aktivieren'}
              </Button>
            </div>
          </div>
        )}

        {/* Step 4: Backup Codes */}
        {step === 'backup' && (
          <div>
            <div className="text-center mb-6">
              <div
                className={clsx(
                  'w-16 h-16 rounded-full flex items-center justify-center mx-auto mb-4',
                  isDark ? 'bg-green-900/50' : 'bg-green-100',
                )}
              >
                <span className="text-3xl">✅</span>
              </div>
              <h2 className={titleClass}>2FA aktiviert!</h2>
              <p className={bodyMuted}>
                Speichern Sie diese Backup-Codes an einem sicheren Ort. Sie benötigen sie,
                falls Sie keinen Zugriff auf Ihre Authenticator-App haben.
              </p>
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
                {backupCodes.map((code, i) => (
                  <code
                    key={i}
                    className={clsx(
                      'px-3 py-2 rounded border text-center font-mono text-sm',
                      isDark ? 'bg-slate-900 border-slate-600 text-slate-100' : 'bg-white border-gray-200 text-gray-900',
                    )}
                  >
                    {code}
                  </code>
                ))}
              </div>
            </div>

            <div className="flex gap-3">
              <Button variant="ghost" onClick={copyBackupCodes}>
                Kopieren
              </Button>
              <Button onClick={onComplete} className="flex-1">
                Fertig
              </Button>
            </div>
          </div>
        )}
      </div>
    </Card>
  );
}
