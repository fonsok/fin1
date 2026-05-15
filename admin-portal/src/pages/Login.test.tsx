import { describe, it, expect, vi, beforeEach } from 'vitest';
import { render, screen, waitFor } from '../test/test-utils';
import userEvent from '@testing-library/user-event';
import { LoginPage } from './Login';
import { PORTAL_LOGIN_EMAIL_PLACEHOLDER } from '../constants/portalLogin';
import type { AuthUser } from '../context/AuthContext';

// Mock AuthContext
const mockLogin = vi.fn();

const loginOk = (role: string): { user: AuthUser; needs2FAVerification: boolean } => ({
  user: {
    objectId: 'u1',
    email: 'a@test.com',
    username: 'a@test.com',
    role,
    requires2FA: false,
    has2FAEnabled: false,
  },
  needs2FAVerification: false,
});
const mockUseAuth = vi.fn();

vi.mock('../context/AuthContext', () => ({
  useAuth: () => mockUseAuth(),
}));

// Mock TwoFactorVerify
vi.mock('../components/TwoFactorVerify', () => ({
  TwoFactorVerify: () => <div data-testid="2fa-verify">2FA Verification</div>,
}));

describe('LoginPage', () => {
  beforeEach(() => {
    vi.clearAllMocks();
    mockUseAuth.mockReturnValue({
      login: mockLogin,
      isLoading: false,
      needs2FAVerification: false,
    });
  });

  it('renders login form', () => {
    render(<LoginPage />);

    expect(screen.getByText('FIN1 Admin Portal')).toBeInTheDocument();
    expect(screen.getByRole('heading', { name: 'Anmelden' })).toBeInTheDocument();
    expect(screen.getByLabelText(/e-mail/i)).toBeInTheDocument();
    expect(screen.getByLabelText(/^Passwort$/i)).toBeInTheDocument();
  });

  it('renders logo and branding', () => {
    render(<LoginPage />);

    expect(screen.getByText('F1')).toBeInTheDocument();
    expect(screen.getByText('Administrations-Bereich')).toBeInTheDocument();
  });

  it('shows footer with copyright', () => {
    render(<LoginPage />);

    const currentYear = new Date().getFullYear();
    expect(screen.getByText(new RegExp(`©\\s*${currentYear}\\s*FIN1`))).toBeInTheDocument();
  });

  it('submits form with credentials', async () => {
    mockLogin.mockResolvedValueOnce(loginOk('admin'));
    const user = userEvent.setup();

    render(<LoginPage />);

    await user.type(screen.getByLabelText(/e-mail/i), 'admin@test.com');
    await user.type(screen.getByLabelText(/^Passwort$/i), 'password123');
    await user.click(screen.getByRole('button', { name: /anmelden/i }));

    expect(mockLogin).toHaveBeenCalledWith('admin@test.com', 'password123');
  });

  it('displays error message on login failure', async () => {
    mockLogin.mockRejectedValueOnce(new Error('Invalid credentials'));
    const user = userEvent.setup();

    render(<LoginPage />);

    await user.type(screen.getByLabelText(/e-mail/i), 'wrong@test.com');
    await user.type(screen.getByLabelText(/^Passwort$/i), 'wrongpass');
    await user.click(screen.getByRole('button', { name: /anmelden/i }));

    await waitFor(() => {
      expect(screen.getByText('E-Mail oder Passwort ist nicht korrekt.')).toBeInTheDocument();
    });
  });

  it('displays generic error for non-Error objects', async () => {
    mockLogin.mockRejectedValueOnce('Some error');
    const user = userEvent.setup();

    render(<LoginPage />);

    await user.type(screen.getByLabelText(/e-mail/i), 'test@test.com');
    await user.type(screen.getByLabelText(/^Passwort$/i), 'pass');
    await user.click(screen.getByRole('button', { name: /anmelden/i }));

    await waitFor(() => {
      expect(screen.getByText('Anmeldung fehlgeschlagen. Bitte erneut versuchen.')).toBeInTheDocument();
    });
  });

  it('maps lockout error to user-friendly message', async () => {
    mockLogin.mockRejectedValueOnce(new Error('Your account is locked due to multiple failed login attempts. Please try again after 5 minute(s)'));
    const user = userEvent.setup();

    render(<LoginPage />);

    await user.type(screen.getByLabelText(/e-mail/i), 'finance@fin1.de');
    await user.type(screen.getByLabelText(/^Passwort$/i), 'wrongpass');
    await user.click(screen.getByRole('button', { name: /anmelden/i }));

    await waitFor(() => {
      expect(screen.getByText(/Zu viele Fehlversuche/)).toBeInTheDocument();
    });
  });

  it('shows loading state during login', () => {
    mockUseAuth.mockReturnValue({
      login: mockLogin,
      isLoading: true,
      needs2FAVerification: false,
    });

    render(<LoginPage />);

    const button = screen.getByRole('button', { name: /anmelden/i });
    expect(button).toBeDisabled();
  });

  it('clears error on new submit', async () => {
    mockLogin
      .mockRejectedValueOnce(new Error('First error'))
      .mockResolvedValueOnce(loginOk('admin'));
    const user = userEvent.setup();

    render(<LoginPage />);

    // First submit fails
    await user.type(screen.getByLabelText(/e-mail/i), 'test@test.com');
    await user.type(screen.getByLabelText(/^Passwort$/i), 'pass');
    await user.click(screen.getByRole('button', { name: /anmelden/i }));

    await waitFor(() => {
      expect(screen.getByText('Anmeldung fehlgeschlagen. Bitte erneut versuchen.')).toBeInTheDocument();
    });

    // Second submit clears error
    await user.click(screen.getByRole('button', { name: /anmelden/i }));

    await waitFor(() => {
      expect(
        screen.queryByText('Anmeldung fehlgeschlagen. Bitte erneut versuchen.'),
      ).not.toBeInTheDocument();
    });
  });

  it('shows 2FA verification when needed', () => {
    mockUseAuth.mockReturnValue({
      login: mockLogin,
      isLoading: false,
      needs2FAVerification: true,
    });

    render(<LoginPage />);

    expect(screen.getByTestId('2fa-verify')).toBeInTheDocument();
    expect(screen.queryByText('Anmelden')).not.toBeInTheDocument();
  });

  it('requires email field', () => {
    render(<LoginPage />);

    const emailInput = screen.getByLabelText(/e-mail/i);
    expect(emailInput).toHaveAttribute('required');
  });

  it('requires password field', () => {
    render(<LoginPage />);

    const passwordInput = screen.getByLabelText(/^Passwort$/i);
    expect(passwordInput).toHaveAttribute('required');
  });

  it('shows placeholder text', () => {
    render(<LoginPage />);

    expect(screen.getByPlaceholderText(PORTAL_LOGIN_EMAIL_PLACEHOLDER)).toBeInTheDocument();
    expect(screen.getByPlaceholderText('••••••••')).toBeInTheDocument();
  });

  it('in dev, shows quick reference for admins and CSR emails', () => {
    render(<LoginPage />);

    expect(screen.getByTestId('dev-login-reference')).toBeInTheDocument();
    expect(screen.getByText('Finance Admin')).toBeInTheDocument();
    expect(screen.getByText('Technischer Admin')).toBeInTheDocument();
    expect(screen.getByText('Compliance (Portal)')).toBeInTheDocument();
    expect(screen.getByText('compliance@fin1.de')).toBeInTheDocument();
    expect(screen.getByText('CSR Level 1')).toBeInTheDocument();
    expect(screen.getByText('L1@fin1.de')).toBeInTheDocument();
  });
});
