import { Button } from '../../../components/ui/Button';

interface TemplatesHeaderActionsProps {
  activeTab: 'response' | 'email' | 'stats';
  hasAnyTemplate: boolean;
  onExportFiltered: () => void;
  onImportFilteredAsNew: () => void;
  onBackfillShortcuts: () => void;
  onExportBackup: () => void;
  onSeedTemplates: () => void;
  onCreateResponseTemplate: () => void;
  onCreateEmailTemplate: () => void;
}

export function TemplatesHeaderActions({
  activeTab,
  hasAnyTemplate,
  onExportFiltered,
  onImportFilteredAsNew,
  onBackfillShortcuts,
  onExportBackup,
  onSeedTemplates,
  onCreateResponseTemplate,
  onCreateEmailTemplate,
}: TemplatesHeaderActionsProps) {
  return (
    <div className="flex gap-2">
      {activeTab === 'response' && (
        <>
          <Button
            variant="secondary"
            onClick={onExportFiltered}
            title="Aktuell gefilterte Textbausteine exportieren"
          >
            Export (filtered)
          </Button>
          <Button
            variant="secondary"
            onClick={onImportFilteredAsNew}
            title="Gefilterten Export als neue Templates importieren"
          >
            Import filtered (as new)
          </Button>
        </>
      )}
      <Button
        variant="secondary"
        onClick={onBackfillShortcuts}
        title="Fehlende Shortcut-Felder in aktiven CSR-Templates per Dry-Run prüfen und optional automatisch ergänzen"
      >
        Shortcut Backfill
      </Button>
      <Button
        variant="secondary"
        onClick={onExportBackup}
        title="Aktuelle CSR-Templates als JSON vom Backend exportieren (z. B. vor Reseed)"
      >
        Export (Backup)
      </Button>
      {!hasAnyTemplate && (
        <Button variant="secondary" onClick={onSeedTemplates}>
          📥 Standard-Templates laden
        </Button>
      )}
      {activeTab === 'response' && (
        <Button onClick={onCreateResponseTemplate}>+ Neues Template</Button>
      )}
      {activeTab === 'email' && (
        <Button onClick={onCreateEmailTemplate}>+ Neue E-Mail Vorlage</Button>
      )}
    </div>
  );
}
