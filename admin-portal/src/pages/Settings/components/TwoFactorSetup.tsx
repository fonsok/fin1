import { useState } from 'react';
import { useMutation } from '@tanstack/react-query';
import { cloudFunction } from '../../../api/admin';
import { Card, Button, Input } from '../../../components/ui';
import type { TwoFactorSetupResponse, TwoFactorEnableResponse } from '../types';

interface TwoFactorSetupProps {
  onComplete: () => void;
}

type Step = 'start' | 'scan' | 'verify' | 'backup';

export function TwoFactorSetup({ onComplete }: TwoFactorSetupProps): JSX.Element {
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

  return (
    <Card className="max-w-lg">
      <div className="p-6">
        {/* Step 1: Start */}
        {step === 'start' && (
          <div className="text-center">
            <div className="w-16 h-16 bg-fin1-light rounded-full flex items-center justify-center mx-auto mb-4">
              <span className="text-3xl">🔐</span>
            </div>
            <h2 className="text-xl font-semibold mb-2">2FA aktivieren</h2>
            <p className="text-gray-600 mb-6">
              Schützen Sie Ihr Konto mit Zwei-Faktor-Authentifizierung. Sie benötigen eine
              Authenticator-App auf Ihrem Smartphone.
            </p>
            <div className="bg-gray-50 rounded-lg p-4 mb-6 text-left">
              <p className="text-sm font-medium text-gray-700 mb-2">Kompatible Apps:</p>
              <ul className="text-sm text-gray-600 space-y-1">
                <li>• <strong>Authy</strong> (iOS, Android)</li>
                <li>• <strong>1Password</strong> (alle Plattformen)</li>
                <li>• <strong>Bitwarden</strong> (alle Plattformen)</li>
                <li>• <strong>FreeOTP</strong> (iOS, Android)</li>
                <li>• <strong>iOS Passwörter</strong> (ab iOS 15)</li>
                <li>• Jede TOTP-kompatible App</li>
              </ul>
            </div>
            {error && <p className="text-red-500 text-sm mb-4">{error}</p>}
            <Button onClick={() => setupMutation.mutate()} disabled={setupMutation.isPending} className="w-full">
              {setupMutation.isPending ? 'Wird vorbereitet...' : 'Setup starten'}
            </Button>
          </div>
        )}

        {/* Step 2: Scan QR Code */}
        {step === 'scan' && setupData && (
          <div className="text-center">
            <h2 className="text-xl font-semibold mb-2">QR-Code scannen</h2>
            <p className="text-gray-600 mb-4">
              Scannen Sie diesen QR-Code mit Ihrer Authenticator-App.
            </p>

            {setupData.qrCodeUrl ? (
              <div className="bg-white p-4 rounded-lg border border-gray-200 inline-block mb-4">
                <img src={setupData.qrCodeUrl} alt="2FA QR Code" className="w-48 h-48" />
              </div>
            ) : (
              <div className="bg-gray-100 p-4 rounded-lg mb-4">
                <p className="text-sm text-gray-500 mb-2">QR-Code nicht verfügbar. Manueller Schlüssel:</p>
                <code className="bg-gray-200 px-2 py-1 rounded text-sm font-mono break-all">
                  {setupData.secret}
                </code>
              </div>
            )}

            <details className="text-left mb-4">
              <summary className="text-sm text-gray-500 cursor-pointer">
                Manuelle Eingabe (falls QR-Scan nicht möglich)
              </summary>
              <div className="mt-2 p-3 bg-gray-50 rounded-lg">
                <p className="text-xs text-gray-500 mb-1">Geheimschlüssel:</p>
                <code className="text-sm font-mono break-all">{setupData.secret}</code>
                <p className="text-xs text-gray-500 mt-2 mb-1">Konto:</p>
                <code className="text-sm">FIN1 Admin</code>
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
            <h2 className="text-xl font-semibold mb-2">Code verifizieren</h2>
            <p className="text-gray-600 mb-6">
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

            {error && <p className="text-red-500 text-sm mb-4">{error}</p>}

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
              <div className="w-16 h-16 bg-green-100 rounded-full flex items-center justify-center mx-auto mb-4">
                <span className="text-3xl">✅</span>
              </div>
              <h2 className="text-xl font-semibold mb-2">2FA aktiviert!</h2>
              <p className="text-gray-600">
                Speichern Sie diese Backup-Codes an einem sicheren Ort. Sie benötigen sie,
                falls Sie keinen Zugriff auf Ihre Authenticator-App haben.
              </p>
            </div>

            <div className="bg-amber-50 border border-amber-200 rounded-lg p-4 mb-4">
              <p className="text-amber-800 text-sm font-medium mb-2">
                ⚠️ Diese Codes werden nur einmal angezeigt!
              </p>
              <div className="grid grid-cols-2 gap-2">
                {backupCodes.map((code, i) => (
                  <code key={i} className="bg-white px-3 py-2 rounded border text-center font-mono text-sm">
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
