import { Card } from '../../../components/ui/Card';
import { Button } from '../../../components/ui/Button';

interface FAQDevMaintenanceCardProps {
  devResetting: boolean;
  onRunReset: () => Promise<void>;
}

export function FAQDevMaintenanceCard({ devResetting, onRunReset }: FAQDevMaintenanceCardProps) {
  return (
    <Card className="p-4 border border-amber-300 bg-amber-50/60">
      <div className="flex flex-col gap-2">
        <div>
          <h2 className="text-lg font-semibold text-amber-900">Development Maintenance</h2>
          <p className="text-sm text-amber-800">
            Erstellt zuerst ein Sicherheits-JSON (alle Kategorien + FAQs), klont dann jede{' '}
            <strong>aktive</strong>, veröffentlichte FAQ (isPublished, nicht archiviert) in neue Zeilen mit
            stabilen <code className="text-xs">faqId</code>, löscht anschließend die alten aktiven Zeilen und alle{' '}
            <strong>inaktiven</strong> FAQs (Entwürfe, archiviert, etc.) dauerhaft. Nur möglich, wenn der Server
            Hard-Deletes explizit erlaubt — analog zu AGB & Rechtstexte.
          </p>
        </div>
        <div className="flex flex-wrap gap-2 items-center">
          <Button
            variant="secondary"
            disabled={devResetting}
            onClick={() => void onRunReset()}
            title="DEV-only: FAQ-Baseline zurücksetzen (Dry-Run, dann bestätigter Lauf). Setzt ALLOW_FAQ_HARD_DELETE=true auf dem Parse-Host voraus."
          >
            {devResetting ? 'Läuft…' : 'DEV: Reset FAQs baseline (aktive klönen, inaktive löschen)'}
          </Button>
        </div>
      </div>
    </Card>
  );
}
