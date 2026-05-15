import React, { useState, useRef, useEffect } from 'react';
import clsx from 'clsx';
import { useAuth } from '../context/AuthContext';
import { useTheme } from '../context/ThemeContext';
import { Button, Card } from './ui';

import {
  adminCaption,
  adminGlyphFaint,
  adminInteractiveCaption,
  adminMuted,
  adminPrimary,
} from '../utils/adminThemeClasses';
import { loginFailureRawMessage, mapLoginErrorMessage } from '../utils/loginErrors';
type TwoFactorMode = 'totp' | 'backup';

export function TwoFactorVerify() {
  const { theme } = useTheme();
  const isDark = theme === 'dark';
  const { verify2FACode, logout, isLoading, user } = useAuth();
  const [mode, setMode] = useState<TwoFactorMode>('totp');
  const [code, setCode] = useState(['', '', '', '', '', '']);
  const [backupCode, setBackupCode] = useState('');
  const [error, setError] = useState('');
  const inputRefs = useRef<(HTMLInputElement | null)[]>([]);
  const backupInputRef = useRef<HTMLInputElement | null>(null);

  // Focus first relevant input on mount / mode switch
  useEffect(() => {
    if (mode === 'totp') {
      inputRefs.current[0]?.focus();
    } else {
      backupInputRef.current?.focus();
    }
  }, [mode]);

  const handleChange = (index: number, value: string) => {
    // Only allow digits
    if (value && !/^\d+$/.test(value)) return;

    const newCode = [...code];

    // Handle paste
    if (value.length > 1) {
      const digits = value.slice(0, 6).split('');
      digits.forEach((digit, i) => {
        if (index + i < 6) {
          newCode[index + i] = digit;
        }
      });
      setCode(newCode);

      // Focus appropriate input
      const nextIndex = Math.min(index + digits.length, 5);
      inputRefs.current[nextIndex]?.focus();
      return;
    }

    newCode[index] = value;
    setCode(newCode);

    // Auto-focus next input
    if (value && index < 5) {
      inputRefs.current[index + 1]?.focus();
    }
  };

  const handleKeyDown = (index: number, e: React.KeyboardEvent) => {
    if (e.key === 'Backspace' && !code[index] && index > 0) {
      inputRefs.current[index - 1]?.focus();
    }
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setError('');

    let payload: string;
    if (mode === 'totp') {
      const fullCode = code.join('');
      if (fullCode.length !== 6) {
        setError('Bitte geben Sie den vollständigen 6-stelligen Code ein');
        return;
      }
      payload = fullCode;
    } else {
      const normalized = backupCode.trim().toUpperCase();
      if (normalized.length !== 8 || !/^[A-Z0-9]{8}$/.test(normalized)) {
        setError('Backup-Code: genau 8 Zeichen (Buchstaben und Ziffern)');
        return;
      }
      payload = normalized;
    }

    try {
      await verify2FACode(payload);
    } catch (err) {
      setError(mapLoginErrorMessage(loginFailureRawMessage(err)));
      if (mode === 'totp') {
        setCode(['', '', '', '', '', '']);
        inputRefs.current[0]?.focus();
      } else {
        setBackupCode('');
        backupInputRef.current?.focus();
      }
    }
  };

  const handleCancel = async () => {
    await logout();
  };

  const digitInputClass = clsx(
    'w-12 h-14 text-center text-2xl font-semibold border-2 rounded-lg focus:border-fin1-primary focus:outline-none transition-colors',
    isDark
      ? 'bg-slate-900/80 border-slate-500 text-slate-100'
      : 'border-gray-200 text-gray-900',
  );

  const backupInputClass = clsx(
    'w-full h-14 text-center text-xl font-mono font-semibold tracking-widest border-2 rounded-lg focus:border-fin1-primary focus:outline-none transition-colors',
    isDark
      ? 'bg-slate-900/80 border-slate-500 text-slate-100 placeholder:text-slate-500'
      : 'border-gray-200 text-gray-900 placeholder:text-gray-400',
  );

  const modeInactive = adminInteractiveCaption(isDark);

  return (
    <div className="min-h-screen bg-gradient-to-br from-fin1-primary to-fin1-secondary flex items-center justify-center p-4">
      <div className="w-full max-w-md">
        {/* Logo */}
        <div className="text-center mb-8">
          <div className="inline-flex items-center justify-center w-16 h-16 bg-white rounded-2xl shadow-lg mb-4">
            <svg className="w-8 h-8 text-fin1-primary" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 15v2m-6 4h12a2 2 0 002-2v-6a2 2 0 00-2-2H6a2 2 0 00-2 2v6a2 2 0 002 2zm10-10V7a4 4 0 00-8 0v4h8z" />
            </svg>
          </div>
          <h1 className="text-2xl font-bold text-white">Zwei-Faktor-Authentifizierung</h1>
          <p className="text-fin1-light/80 mt-1">Zusätzliche Sicherheitsprüfung</p>
        </div>

        {/* 2FA Card */}
        <Card className="shadow-xl">
          <div className="text-center mb-6">
            <div className="w-12 h-12 bg-fin1-light rounded-full flex items-center justify-center mx-auto mb-4">
              <svg className="w-6 h-6 text-fin1-primary" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 18h.01M8 21h8a2 2 0 002-2V5a2 2 0 00-2-2H8a2 2 0 00-2 2v14a2 2 0 002 2z" />
              </svg>
            </div>
            <h2 className={clsx('text-lg font-semibold', adminPrimary(isDark))}>
              {mode === 'totp' ? 'Code eingeben' : 'Backup-Code eingeben'}
            </h2>
            <p className={clsx('text-sm mt-1', adminMuted(isDark))}>
              {mode === 'totp'
                ? 'Öffnen Sie Ihre Authenticator-App und geben Sie den 6-stelligen Code ein.'
                : 'Geben Sie einen Ihrer 8-stelligen Einmal-Backup-Codes ein (Großbuchstaben und Ziffern).'}
            </p>
          </div>

          <div className="flex justify-center gap-2 mb-4 text-sm">
            <button
              type="button"
              className={mode === 'totp' ? 'font-semibold text-fin1-primary' : modeInactive}
              onClick={() => { setMode('totp'); setError(''); }}
            >
              Authenticator (6 Ziffern)
            </button>
            <span className={clsx(adminGlyphFaint(isDark))}>|</span>
            <button
              type="button"
              className={mode === 'backup' ? 'font-semibold text-fin1-primary' : modeInactive}
              onClick={() => { setMode('backup'); setError(''); }}
            >
              Backup-Code (8 Zeichen)
            </button>
          </div>

          <form onSubmit={handleSubmit}>
            {mode === 'totp' ? (
            <div className="flex justify-center gap-2 mb-6">
              {code.map((digit, index) => (
                <input
                  key={index}
                  ref={(el) => (inputRefs.current[index] = el)}
                  type="text"
                  inputMode="numeric"
                  maxLength={6}
                  value={digit}
                  onChange={(e) => handleChange(index, e.target.value)}
                  onKeyDown={(e) => handleKeyDown(index, e)}
                  className={digitInputClass}
                />
              ))}
            </div>
            ) : (
            <div className="mb-6">
              <input
                ref={backupInputRef}
                type="text"
                inputMode="text"
                autoCapitalize="characters"
                autoCorrect="off"
                spellCheck={false}
                maxLength={8}
                value={backupCode}
                onChange={(e) => {
                  const v = e.target.value.toUpperCase().replace(/[^A-Z0-9]/g, '').slice(0, 8);
                  setBackupCode(v);
                }}
                className={backupInputClass}
                placeholder="XXXXXXXX"
                aria-label="Backup-Code"
              />
            </div>
            )}

            {error && (
              <div
                className={clsx(
                  'p-3 border rounded-lg mb-4',
                  isDark ? 'bg-red-950/40 border-red-800' : 'bg-red-50 border-red-200',
                )}
              >
                <p className={clsx('text-sm text-center', isDark ? 'text-red-300' : 'text-red-600')}>{error}</p>
              </div>
            )}

            <div className="space-y-3">
              <Button
                type="submit"
                className="w-full"
                size="lg"
                loading={isLoading}
                disabled={mode === 'totp' ? code.some(d => !d) : backupCode.length !== 8}
              >
                Verifizieren
              </Button>

              <Button
                type="button"
                variant="ghost"
                className="w-full"
                onClick={handleCancel}
              >
                Abbrechen
              </Button>
            </div>
          </form>

          {user && (
            <p className={clsx('text-xs text-center mt-6', adminCaption(isDark))}>
              Angemeldet als {user.email}
            </p>
          )}
        </Card>

        {/* Help text */}
        <div className="text-center mt-6">
          <p className="text-fin1-light/60 text-sm">
            Probleme mit der Anmeldung?{' '}
            <a href="mailto:support@fin1.de" className="text-white underline">
              Support kontaktieren
            </a>
          </p>
        </div>
      </div>
    </div>
  );
}
