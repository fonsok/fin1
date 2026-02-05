import { Card } from '../../../components/ui';

interface StatCardProps {
  title: string;
  value: string;
  subtitle: string;
  icon: string;
  trend?: string;
}

export function StatCard({ title, value, subtitle, icon, trend }: StatCardProps): JSX.Element {
  return (
    <Card className="p-6">
      <div className="flex items-start justify-between">
        <div>
          <p className="text-sm font-medium text-gray-500">{title}</p>
          <p className="text-2xl font-bold text-gray-900 mt-1">{value}</p>
          <p className="text-sm text-gray-400 mt-1">{subtitle}</p>
        </div>
        <div className="flex flex-col items-end">
          <span className="text-2xl">{icon}</span>
          {trend && (
            <span className="text-xs font-medium text-green-600 mt-2">{trend}</span>
          )}
        </div>
      </div>
    </Card>
  );
}
