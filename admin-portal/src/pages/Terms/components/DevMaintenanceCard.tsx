import { Card } from '../../../components/ui/Card';
import { Button } from '../../../components/ui/Button';

interface DevMaintenanceCardProps {
  devResetting: boolean;
  onRunReset: () => Promise<void>;
}

export function DevMaintenanceCard({ devResetting, onRunReset }: DevMaintenanceCardProps) {
  return (
    <Card className="p-4 border border-amber-300 bg-amber-50/60">
      <div className="flex flex-col gap-2">
        <div>
          <h2 className="text-lg font-semibold text-amber-900">Development Maintenance</h2>
          <p className="text-sm text-amber-800">
            Löscht alle <strong>inaktiven</strong> Rechtstext-Versionen (Hard Delete) und klont die aktuellen
            aktiven Versionen als neue Baseline. Nur verfügbar, wenn der Server dies explizit erlaubt.
          </p>
        </div>
        <div className="flex flex-wrap gap-2 items-center">
          <Button
            variant="secondary"
            disabled={devResetting}
            onClick={() => void onRunReset()}
            title="DEV-only: Klont aktive Versionen als v1.0.0 und löscht alle inaktiven Versionen"
          >
            {devResetting ? 'Läuft…' : 'DEV: Reset legal docs baseline (v1.0.0)'}
          </Button>
        </div>
      </div>
    </Card>
  );
}
