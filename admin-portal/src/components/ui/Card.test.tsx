import { describe, it, expect } from 'vitest';
import { render, screen } from '../../test/test-utils';
import { Card, CardHeader } from './Card';

describe('Card', () => {
  it('renders children', () => {
    render(<Card>Card content</Card>);
    expect(screen.getByText('Card content')).toBeInTheDocument();
  });

  it('applies default padding (md)', () => {
    render(<Card data-testid="card">Content</Card>);
    // The Card wraps children in a div with the classes
    const card = screen.getByTestId('card');
    expect(card).toHaveClass('p-6');
  });

  it('applies small padding', () => {
    render(<Card padding="sm" data-testid="card">Content</Card>);
    const card = screen.getByTestId('card');
    expect(card).toHaveClass('p-4');
  });

  it('applies large padding', () => {
    render(<Card padding="lg" data-testid="card">Content</Card>);
    const card = screen.getByTestId('card');
    expect(card).toHaveClass('p-8');
  });

  it('applies no padding', () => {
    render(<Card padding="none" data-testid="card">Content</Card>);
    const card = screen.getByTestId('card');
    expect(card).not.toHaveClass('p-4');
    expect(card).not.toHaveClass('p-6');
    expect(card).not.toHaveClass('p-8');
  });

  it('applies custom className', () => {
    render(<Card className="custom-class" data-testid="card">Content</Card>);
    const card = screen.getByTestId('card');
    expect(card).toHaveClass('custom-class');
  });

  it('has base styling classes', () => {
    render(<Card data-testid="card">Content</Card>);
    const card = screen.getByTestId('card');
    expect(card).toHaveClass('bg-white', 'rounded-xl', 'shadow-sm');
  });
});

describe('CardHeader', () => {
  it('renders title', () => {
    render(<CardHeader title="Test Title" />);
    expect(screen.getByText('Test Title')).toBeInTheDocument();
  });

  it('renders subtitle when provided', () => {
    render(<CardHeader title="Title" subtitle="Subtitle text" />);
    expect(screen.getByText('Subtitle text')).toBeInTheDocument();
  });

  it('does not render subtitle when not provided', () => {
    render(<CardHeader title="Title" />);
    expect(screen.queryByText('Subtitle text')).not.toBeInTheDocument();
  });

  it('renders action when provided', () => {
    render(<CardHeader title="Title" action={<button>Action</button>} />);
    expect(screen.getByRole('button', { name: 'Action' })).toBeInTheDocument();
  });

  it('applies correct title styling', () => {
    render(<CardHeader title="Test Title" />);
    const title = screen.getByText('Test Title');
    expect(title).toHaveClass('text-lg', 'font-semibold');
  });

  it('applies correct subtitle styling', () => {
    render(<CardHeader title="Title" subtitle="Subtitle" />);
    const subtitle = screen.getByText('Subtitle');
    expect(subtitle).toHaveClass('text-sm', 'text-gray-500');
  });
});
