import { describe, it, expect, vi, beforeEach } from 'vitest';
import { render, screen, waitFor } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { LoginPage } from './Login';

// Mock AuthContext
const mockLogin = vi.fn();
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
    expect(screen.getByLabelText(/passwort/i)).toBeInTheDocument();
  });

  it('renders logo and branding', () => {
    render(<LoginPage />);

    expect(screen.getByText('F1')).toBeInTheDocument();
    expect(screen.getByText('Administrations-Bereich')).toBeInTheDocument();
  });

  it('shows footer with copyright', () => {
    render(<LoginPage />);

    const currentYear = new Date().getFullYear();
    expect(screen.getByText(new RegExp(`${currentYear}`))).toBeInTheDocument();
  });

  it('submits form with credentials', async () => {
    mockLogin.mockResolvedValueOnce(undefined);
    const user = userEvent.setup();

    render(<LoginPage />);

    await user.type(screen.getByLabelText(/e-mail/i), 'admin@test.com');
    await user.type(screen.getByLabelText(/passwort/i), 'password123');
    await user.click(screen.getByRole('button', { name: /anmelden/i }));

    expect(mockLogin).toHaveBeenCalledWith('admin@test.com', 'password123');
  });

  it('displays error message on login failure', async () => {
    mockLogin.mockRejectedValueOnce(new Error('Invalid credentials'));
    const user = userEvent.setup();

    render(<LoginPage />);

    await user.type(screen.getByLabelText(/e-mail/i), 'wrong@test.com');
    await user.type(screen.getByLabelText(/passwort/i), 'wrongpass');
    await user.click(screen.getByRole('button', { name: /anmelden/i }));

    await waitFor(() => {
      expect(screen.getByText('Invalid credentials')).toBeInTheDocument();
    });
  });

  it('displays generic error for non-Error objects', async () => {
    mockLogin.mockRejectedValueOnce('Some error');
    const user = userEvent.setup();

    render(<LoginPage />);

    await user.type(screen.getByLabelText(/e-mail/i), 'test@test.com');
    await user.type(screen.getByLabelText(/passwort/i), 'pass');
    await user.click(screen.getByRole('button', { name: /anmelden/i }));

    await waitFor(() => {
      expect(screen.getByText('Anmeldung fehlgeschlagen')).toBeInTheDocument();
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
      .mockResolvedValueOnce(undefined);
    const user = userEvent.setup();

    render(<LoginPage />);

    // First submit fails
    await user.type(screen.getByLabelText(/e-mail/i), 'test@test.com');
    await user.type(screen.getByLabelText(/passwort/i), 'pass');
    await user.click(screen.getByRole('button', { name: /anmelden/i }));

    await waitFor(() => {
      expect(screen.getByText('First error')).toBeInTheDocument();
    });

    // Second submit clears error
    await user.click(screen.getByRole('button', { name: /anmelden/i }));

    await waitFor(() => {
      expect(screen.queryByText('First error')).not.toBeInTheDocument();
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

    const passwordInput = screen.getByLabelText(/passwort/i);
    expect(passwordInput).toHaveAttribute('required');
  });

  it('shows placeholder text', () => {
    render(<LoginPage />);

    expect(screen.getByPlaceholderText('admin@fin1.de')).toBeInTheDocument();
    expect(screen.getByPlaceholderText('••••••••')).toBeInTheDocument();
  });
});
