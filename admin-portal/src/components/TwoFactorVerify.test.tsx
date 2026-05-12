import { describe, it, expect, vi, beforeEach } from 'vitest';
import { render, screen, fireEvent, waitFor } from '../test/test-utils';
import userEvent from '@testing-library/user-event';
import { TwoFactorVerify } from './TwoFactorVerify';

// Mock AuthContext
const mockVerify2FACode = vi.fn();
const mockLogout = vi.fn();
const mockUseAuth = vi.fn();

vi.mock('../context/AuthContext', () => ({
  useAuth: () => mockUseAuth(),
}));

describe('TwoFactorVerify', () => {
  beforeEach(() => {
    vi.clearAllMocks();
    mockUseAuth.mockReturnValue({
      verify2FACode: mockVerify2FACode,
      logout: mockLogout,
      isLoading: false,
      user: { email: 'admin@test.com' },
    });
  });

  it('renders 2FA form', () => {
    render(<TwoFactorVerify />);

    expect(screen.getByText('Zwei-Faktor-Authentifizierung')).toBeInTheDocument();
    expect(screen.getByText('Code eingeben')).toBeInTheDocument();
    expect(screen.getByRole('button', { name: /verifizieren/i })).toBeInTheDocument();
    expect(screen.getByRole('button', { name: /abbrechen/i })).toBeInTheDocument();
  });

  it('shows user email', () => {
    render(<TwoFactorVerify />);

    expect(screen.getByText(/admin@test.com/)).toBeInTheDocument();
  });

  it('renders 6 digit inputs', () => {
    render(<TwoFactorVerify />);

    const inputs = document.querySelectorAll('input');
    expect(inputs.length).toBe(6);
  });

  it('focuses first input on mount', async () => {
    render(<TwoFactorVerify />);

    const inputs = document.querySelectorAll('input');
    await waitFor(() => {
      expect(inputs[0]).toHaveFocus();
    });
  });

  it('auto-advances to next input on digit entry', async () => {
    const user = userEvent.setup();
    render(<TwoFactorVerify />);

    const inputs = document.querySelectorAll('input');
    await user.type(inputs[0], '1');

    expect(inputs[1]).toHaveFocus();
  });

  it('only allows digit input', async () => {
    const user = userEvent.setup();
    render(<TwoFactorVerify />);

    const inputs = document.querySelectorAll('input');
    await user.type(inputs[0], 'abc');

    expect(inputs[0]).toHaveValue('');
  });

  it('handles paste of full code', async () => {
    render(<TwoFactorVerify />);

    const inputs = document.querySelectorAll('input');

    // Simulate paste by setting value directly
    fireEvent.change(inputs[0], { target: { value: '123456' } });

    expect(inputs[0]).toHaveValue('1');
    expect(inputs[1]).toHaveValue('2');
    expect(inputs[2]).toHaveValue('3');
    expect(inputs[3]).toHaveValue('4');
    expect(inputs[4]).toHaveValue('5');
    expect(inputs[5]).toHaveValue('6');
  });

  it('navigates back on backspace when input is empty', async () => {
    const user = userEvent.setup();
    render(<TwoFactorVerify />);

    const inputs = document.querySelectorAll('input');

    // Type in first input then move to second
    await user.type(inputs[0], '1');
    expect(inputs[1]).toHaveFocus();

    // Press backspace on empty second input
    await user.keyboard('{Backspace}');
    expect(inputs[0]).toHaveFocus();
  });

  it('submits code when form is submitted', async () => {
    mockVerify2FACode.mockResolvedValueOnce(undefined);
    render(<TwoFactorVerify />);

    const inputs = document.querySelectorAll('input');

    // Enter code
    fireEvent.change(inputs[0], { target: { value: '123456' } });

    // Submit
    const submitButton = screen.getByRole('button', { name: /verifizieren/i });
    fireEvent.click(submitButton);

    await waitFor(() => {
      expect(mockVerify2FACode).toHaveBeenCalledWith('123456');
    });
  });

  it('shows error for incomplete code', async () => {
    render(<TwoFactorVerify />);

    const inputs = document.querySelectorAll('input');
    fireEvent.change(inputs[0], { target: { value: '123' } });

    // Try to submit
    const form = screen.getByRole('button', { name: /verifizieren/i }).closest('form');
    fireEvent.submit(form!);

    await waitFor(() => {
      expect(screen.getByText(/vollständigen 6-stelligen Code/)).toBeInTheDocument();
    });
  });

  it('shows error on verification failure', async () => {
    mockVerify2FACode.mockRejectedValueOnce(new Error('Ungültiger Code'));
    render(<TwoFactorVerify />);

    const inputs = document.querySelectorAll('input');
    fireEvent.change(inputs[0], { target: { value: '123456' } });

    const submitButton = screen.getByRole('button', { name: /verifizieren/i });
    fireEvent.click(submitButton);

    await waitFor(() => {
      expect(screen.getByText('Ungültiger Code')).toBeInTheDocument();
    });
  });

  it('clears code after verification failure', async () => {
    mockVerify2FACode.mockRejectedValueOnce(new Error('Invalid'));
    render(<TwoFactorVerify />);

    const inputs = document.querySelectorAll('input');
    fireEvent.change(inputs[0], { target: { value: '123456' } });

    const submitButton = screen.getByRole('button', { name: /verifizieren/i });
    fireEvent.click(submitButton);

    await waitFor(() => {
      expect(inputs[0]).toHaveValue('');
    });
  });

  it('calls logout on cancel', async () => {
    const user = userEvent.setup();
    render(<TwoFactorVerify />);

    const cancelButton = screen.getByRole('button', { name: /abbrechen/i });
    await user.click(cancelButton);

    expect(mockLogout).toHaveBeenCalled();
  });

  it('disables submit button when code is incomplete', () => {
    render(<TwoFactorVerify />);

    const submitButton = screen.getByRole('button', { name: /verifizieren/i });
    expect(submitButton).toBeDisabled();
  });

  it('enables submit button when code is complete', () => {
    render(<TwoFactorVerify />);

    const inputs = document.querySelectorAll('input');
    fireEvent.change(inputs[0], { target: { value: '123456' } });

    const submitButton = screen.getByRole('button', { name: /verifizieren/i });
    expect(submitButton).not.toBeDisabled();
  });

  it('shows loading state during verification', () => {
    mockUseAuth.mockReturnValue({
      verify2FACode: mockVerify2FACode,
      logout: mockLogout,
      isLoading: true,
      user: { email: 'admin@test.com' },
    });

    render(<TwoFactorVerify />);

    const submitButton = screen.getByRole('button', { name: /verifizieren/i });
    expect(submitButton).toBeDisabled();
  });

  it('shows support link', () => {
    render(<TwoFactorVerify />);

    const supportLink = screen.getByText('Support kontaktieren');
    expect(supportLink).toHaveAttribute('href', 'mailto:support@fin1.de');
  });

  it('shows instructions text', () => {
    render(<TwoFactorVerify />);

    expect(screen.getByText(/Authenticator-App/)).toBeInTheDocument();
  });

  it('submits 8-character backup code in backup mode', async () => {
    mockVerify2FACode.mockResolvedValueOnce(undefined);
    const user = userEvent.setup();
    render(<TwoFactorVerify />);

    await user.click(screen.getByRole('button', { name: /Backup-Code \(8 Zeichen\)/i }));

    const backupInput = screen.getByLabelText('Backup-Code');
    await user.type(backupInput, 'ab12cd34');

    const submitButton = screen.getByRole('button', { name: /verifizieren/i });
    await user.click(submitButton);

    await waitFor(() => {
      expect(mockVerify2FACode).toHaveBeenCalledWith('AB12CD34');
    });
  });
});
