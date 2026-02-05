import React, { useState, useRef, useEffect } from 'react';
import { useAuth } from '../context/AuthContext';
import { Button, Card } from './ui';

export function TwoFactorVerify() {
  const { verify2FACode, logout, isLoading, user } = useAuth();
  const [code, setCode] = useState(['', '', '', '', '', '']);
  const [error, setError] = useState('');
  const inputRefs = useRef<(HTMLInputElement | null)[]>([]);

  // Focus first input on mount
  useEffect(() => {
    inputRefs.current[0]?.focus();
  }, []);

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

    const fullCode = code.join('');
    if (fullCode.length !== 6) {
      setError('Bitte geben Sie den vollständigen 6-stelligen Code ein');
      return;
    }

    try {
      await verify2FACode(fullCode);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Ungültiger Code');
      setCode(['', '', '', '', '', '']);
      inputRefs.current[0]?.focus();
    }
  };

  const handleCancel = async () => {
    await logout();
  };

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
            <h2 className="text-lg font-semibold text-gray-900">
              Code eingeben
            </h2>
            <p className="text-gray-500 text-sm mt-1">
              Öffnen Sie Ihre Authenticator-App und geben Sie den 6-stelligen Code ein
            </p>
          </div>

          <form onSubmit={handleSubmit}>
            {/* Code Input */}
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
                  className="w-12 h-14 text-center text-2xl font-semibold border-2 border-gray-200 rounded-lg focus:border-fin1-primary focus:outline-none transition-colors"
                />
              ))}
            </div>

            {error && (
              <div className="p-3 bg-red-50 border border-red-200 rounded-lg mb-4">
                <p className="text-sm text-red-600 text-center">{error}</p>
              </div>
            )}

            <div className="space-y-3">
              <Button
                type="submit"
                className="w-full"
                size="lg"
                loading={isLoading}
                disabled={code.some(d => !d)}
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
            <p className="text-xs text-gray-400 text-center mt-6">
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
