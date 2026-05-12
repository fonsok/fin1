import { describe, it, expect } from 'vitest';
import { render, screen } from '../../test/test-utils';
import { Badge, getStatusVariant } from './Badge';

describe('Badge', () => {
  it('renders with children', () => {
    render(<Badge>Active</Badge>);
    expect(screen.getByText('Active')).toBeInTheDocument();
  });

  it('applies success variant styles', () => {
    render(<Badge variant="success">Success</Badge>);
    expect(screen.getByText('Success')).toHaveClass('bg-green-100', 'text-green-800');
  });

  it('applies warning variant styles', () => {
    render(<Badge variant="warning">Warning</Badge>);
    expect(screen.getByText('Warning')).toHaveClass('bg-amber-100', 'text-amber-800');
  });

  it('applies danger variant styles', () => {
    render(<Badge variant="danger">Danger</Badge>);
    expect(screen.getByText('Danger')).toHaveClass('bg-red-100', 'text-red-800');
  });

  it('applies neutral variant by default', () => {
    render(<Badge>Default</Badge>);
    expect(screen.getByText('Default')).toHaveClass('bg-gray-100', 'text-gray-800');
  });
});

describe('getStatusVariant', () => {
  it('returns success for active status', () => {
    expect(getStatusVariant('active')).toBe('success');
  });

  it('returns success for approved status', () => {
    expect(getStatusVariant('approved')).toBe('success');
  });

  it('returns warning for pending status', () => {
    expect(getStatusVariant('pending')).toBe('warning');
  });

  it('returns danger for suspended status', () => {
    expect(getStatusVariant('suspended')).toBe('danger');
  });

  it('returns neutral for unknown status', () => {
    expect(getStatusVariant('unknown')).toBe('neutral');
  });

  it('is case insensitive', () => {
    expect(getStatusVariant('ACTIVE')).toBe('success');
    expect(getStatusVariant('Pending')).toBe('warning');
  });
});
