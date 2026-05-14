import React, { useState, useEffect } from 'react';
import clsx from 'clsx';
import { useAuth } from '../context/AuthContext';
import { useTheme } from '../context/ThemeContext';
import { Button, Input, Card } from '../components/ui';
import { TwoFactorVerify } from '../components/TwoFactorVerify';
import { DevPortalLoginReference } from '../components/DevPortalLoginReference';
import {
  PORTAL_LOGIN_CARD_INTRO,
  PORTAL_LOGIN_EMAIL_PLACEHOLDER,
} from '../constants/portalLogin';

import { adminCaption, adminMuted, adminPrimary } from '../utils/adminThemeClasses';
function mapLoginErrorMessage(rawMessage: string): string {
  const msg = rawMessage.toLowerCase();

  if (msg.includes('locked due to multiple failed login attempts') || msg.includes('account is locked')) {
    return 'Zu viele Fehlversuche. Konto ist kurzzeitig gesperrt (ca. 5 Minuten).';
  }

  if (msg.includes('invalid username/password') || msg.includes('invalid credentials')) {
    return 'E-Mail oder Passwort ist nicht korrekt.';
  }

  if (msg.includes('failed to fetch') || msg.includes('netzwerk') || msg.includes('network')) {
    return 'Login aktuell nicht möglich. Bitte später erneut versuchen.';
  }

  return rawMessage;
}

export function LoginPage() {
  const { theme } = useTheme();
  const isDark = theme === 'dark';
  const { login, isLoading, needs2FAVerification, user, isAuthenticated } = useAuth();
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [error, setError] = useState('');

  // Redirect CSR users immediately after successful login
  useEffect(() => {
    if (isAuthenticated && user?.role === 'customer_service') {
      // Force immediate redirect to CSR portal
      window.location.href = '/admin/csr';
    }
  }, [isAuthenticated, user?.role]);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setError('');

    try {
      await login(email, password);
      // Navigation will be handled by useEffect
    } catch (err) {
      if (err instanceof Error) {
        setError(mapLoginErrorMessage(err.message));
      } else {
        setError('Anmeldung fehlgeschlagen');
      }
    }
  };

  // Show 2FA verification if needed
  if (needs2FAVerification) {
    return <TwoFactorVerify />;
  }

  return (
    <div className="min-h-screen bg-gradient-to-br from-fin1-primary to-fin1-secondary flex items-center justify-center p-4">
      <div className="w-full max-w-md">
        {/* Logo */}
        <div className="text-center mb-8">
          <div className="inline-flex items-center justify-center w-16 h-16 bg-white rounded-2xl shadow-lg mb-4">
            <span className="text-2xl font-bold text-fin1-primary">F1</span>
          </div>
          <h1 className="text-2xl font-bold text-white">FIN1 Admin Portal</h1>
          <p className="text-fin1-light/80 mt-1">Administrations-Bereich</p>
        </div>

        {/* Login Card */}
        <Card className="shadow-xl">
          <h2 className={clsx('text-xl font-semibold mb-1', adminPrimary(isDark))}>
            Anmelden
          </h2>
          <p className={clsx('text-sm mb-6', adminMuted(isDark))}>
            {PORTAL_LOGIN_CARD_INTRO}
          </p>

          <form onSubmit={handleSubmit} className="space-y-4">
            <Input
              label="E-Mail"
              type="email"
              value={email}
              onChange={(e) => setEmail(e.target.value)}
              placeholder={PORTAL_LOGIN_EMAIL_PLACEHOLDER}
              required
              autoComplete="email"
              icon={
                <svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M3 8l7.89 5.26a2 2 0 002.22 0L21 8M5 19h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v10a2 2 0 002 2z" />
                </svg>
              }
            />

            <Input
              label="Passwort"
              type="password"
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              placeholder="••••••••"
              required
              autoComplete="current-password"
              icon={
                <svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 15v2m-6 4h12a2 2 0 002-2v-6a2 2 0 00-2-2H6a2 2 0 00-2 2v6a2 2 0 002 2zm10-10V7a4 4 0 00-8 0v4h8z" />
                </svg>
              }
            />

            {error && (
              <div
                className={clsx(
                  'p-3 border rounded-lg',
                  isDark ? 'bg-red-950/40 border-red-800' : 'bg-red-50 border-red-200',
                )}
              >
                <p className={clsx('text-sm', isDark ? 'text-red-300' : 'text-red-600')}>{error}</p>
              </div>
            )}

            <Button
              type="submit"
              className="w-full"
              size="lg"
              loading={isLoading}
            >
              Anmelden
            </Button>
          </form>

          <DevPortalLoginReference />

          <p className={clsx('text-xs text-center mt-6', adminCaption(isDark))}>
            Nur für autorisierte Administratoren
          </p>
        </Card>

        {/* Footer */}
        <p className="text-center text-fin1-light/60 text-sm mt-6">
          © {new Date().getFullYear()} FIN1. Alle Rechte vorbehalten.
        </p>
      </div>
    </div>
  );
}
