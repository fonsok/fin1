import { useState } from 'react';
import clsx from 'clsx';
import { useNavigate, Link } from 'react-router-dom';
import { useAuth } from '../../context/AuthContext';
import { useTheme } from '../../context/ThemeContext';
import { Card, Input } from '../../components/ui';
import { TwoFactorVerify } from '../../components/TwoFactorVerify';
import { loginFailureRawMessage, mapLoginErrorMessage } from '../../utils/loginErrors';

import { adminBorderChrome, adminMuted } from '../../utils/adminThemeClasses';

export function CSRLoginPage() {
  const navigate = useNavigate();
  const { login, isLoading, needs2FAVerification } = useAuth();
  const { theme } = useTheme();
  const isDark = theme === 'dark';
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [error, setError] = useState('');

  if (needs2FAVerification) {
    return <TwoFactorVerify />;
  }

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setError('');

    try {
      const { user, needs2FAVerification: pending2fa } = await login(email, password);
      if (pending2fa) {
        return;
      }
      if (user.role === 'customer_service') {
        navigate('/csr', { replace: true });
      } else {
        navigate('/', { replace: true });
      }
    } catch (err) {
      setError(mapLoginErrorMessage(loginFailureRawMessage(err)));
    }
  };

  return (
    <div className="min-h-screen bg-gradient-to-br from-fin1-primary via-fin1-secondary to-fin1-primary flex items-center justify-center p-4">
      <div className="max-w-md w-full">
        {/* Logo & Header */}
        <div className="text-center mb-8">
          <div className="inline-flex items-center justify-center w-20 h-20 bg-white rounded-2xl shadow-xl mb-4">
            <svg className="w-12 h-12 text-fin1-primary" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M18.364 5.636l-3.536 3.536m0 5.656l3.536 3.536M9.172 9.172L5.636 5.636m3.536 9.192l-3.536 3.536M21 12a9 9 0 11-18 0 9 9 0 0118 0zm-5 0a4 4 0 11-8 0 4 4 0 018 0z" />
            </svg>
          </div>
          <h1 className="text-3xl font-bold text-white mb-2">CSR Portal</h1>
          <p className="text-white/80">Kundenservice-Anmeldung</p>
        </div>

        {/* Login Form — theme-aware Card so Input labels/fields match (same as Admin Login) */}
        <Card className="shadow-2xl rounded-2xl" padding="lg">
          <p className={clsx('text-sm mb-4', adminMuted(isDark))}>
            Compliance und andere Admin-Rollen mit 2FA: bitte{' '}
            <Link to="/login" className="underline font-medium text-fin1-primary">
              Admin-Anmeldung
            </Link>{' '}
            nutzen.
          </p>
          <form onSubmit={handleSubmit} className="space-y-6">
            {error && (
              <div
                className={clsx(
                  'px-4 py-3 rounded-lg text-sm border',
                  isDark ? 'bg-red-950/40 border-red-800 text-red-300' : 'bg-red-50 border-red-200 text-red-600',
                )}
              >
                {error}
              </div>
            )}

            <Input
              label="E-Mail-Adresse"
              type="email"
              value={email}
              onChange={(e) => setEmail(e.target.value)}
              placeholder="ihre.email@fin1.de"
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

            <button
              type="submit"
              disabled={isLoading}
              className="w-full bg-fin1-primary text-white py-3 rounded-lg font-medium hover:bg-fin1-secondary transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
            >
              {isLoading ? 'Wird angemeldet...' : 'Anmelden'}
            </button>
          </form>

          <div className={clsx('mt-6 pt-6 border-t', adminBorderChrome(isDark))}>
            <p className={clsx('text-center text-sm', adminMuted(isDark))}>
              Nur für autorisierte CSR-Mitarbeiter
            </p>
          </div>
        </Card>
      </div>
    </div>
  );
}
