import { Card, Button, Badge } from '../../../components/ui';

interface ConfigurationHeaderCardProps {
  pendingCount: number;
  onTogglePending: () => void;
}

export function ConfigurationHeaderCard({
  pendingCount,
  onTogglePending,
}: ConfigurationHeaderCardProps) {
  return (
    <Card>
      <div className="flex items-center justify-between">
        <div>
          <h2 className="text-lg font-semibold">System-Konfiguration</h2>
          <p className="text-sm text-gray-500 mt-1">
            Kritische Parameter erfordern 4-Augen-Genehmigung
          </p>
        </div>
        <div className="flex gap-2">
          {pendingCount > 0 && (
            <Button variant="secondary" onClick={onTogglePending}>
              <span className="flex items-center gap-2">
                Ausstehend
                <Badge variant="warning">{pendingCount}</Badge>
              </span>
            </Button>
          )}
        </div>
      </div>
    </Card>
  );
}
