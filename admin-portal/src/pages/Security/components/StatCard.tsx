import { Card } from '../../../components/ui';

type Variant = 'default' | 'success' | 'warning' | 'error';

interface StatCardProps {
  title: string;
  value: string;
  subtitle: string;
  variant?: Variant;
}

export function StatCard({ title, value, subtitle, variant = 'default' }: StatCardProps): JSX.Element {
  const variantStyles: Record<Variant, string> = {
    default: 'bg-white',
    success: 'bg-green-50 border-green-200',
    warning: 'bg-amber-50 border-amber-200',
    error: 'bg-red-50 border-red-200',
  };

  const valueStyles: Record<Variant, string> = {
    default: 'text-gray-900',
    success: 'text-green-700',
    warning: 'text-amber-700',
    error: 'text-red-700',
  };

  return (
    <Card className={`p-4 ${variantStyles[variant]}`}>
      <p className="text-sm font-medium text-gray-500">{title}</p>
      <p className={`text-2xl font-bold mt-1 ${valueStyles[variant]}`}>{value}</p>
      <p className="text-xs text-gray-400 mt-1">{subtitle}</p>
    </Card>
  );
}
