import { Button } from '../../../components/ui/Button';

interface TermsHeaderActionsProps {
  importing: boolean;
  importingActive: boolean;
  onExportBackup: () => void;
  onExportActiveBackup: () => void;
  onPromptImportBackup: () => void;
  onPromptImportActiveBackup: () => void;
  onCreateEmptyVersion: () => void;
}

export function TermsHeaderActions({
  importing,
  importingActive,
  onExportBackup,
  onExportActiveBackup,
  onPromptImportBackup,
  onPromptImportActiveBackup,
  onCreateEmptyVersion,
}: TermsHeaderActionsProps) {
  return (
    <div className="flex gap-2">
      <Button
        variant="secondary"
        onClick={onExportBackup}
        title="Exportiert alle gespeicherten Rechtstext-Versionen (TermsContent) als JSON vom Backend: Dokumenttyp, Sprache, Versionsname, Gueltigkeitsdatum, aktiv/archiviert, vollstaendiger Abschnittsbaum. Sinnvoll vor Migration, Restore oder grossen Inhaltsaenderungen."
      >
        Export (Backup)
      </Button>
      <Button
        variant="secondary"
        onClick={onExportActiveBackup}
        title="Exportiert nur die aktuell aktiven, nicht-archivierten Texte und nutzt dafuer die Filter oben (Dokumenttyp und Sprache). Wenn dort 'alle' steht, wird kein Filter gesetzt und es koennen mehrere aktive Dokumente im Export landen. Kompakte Sicherung der live relevanten Fassungen."
      >
        Export active (filtered)
      </Button>
      <Button
        variant="secondary"
        onClick={onPromptImportBackup}
        disabled={importing}
        title="Voll-Restore aus JSON: zuerst Dry-Run-Preview (z. B. wie viele Eintraege archiviert/importiert wuerden), danach bestaetigter Lauf. Bestehende Versionen im Wirkungsbereich werden archiviert/deaktiviert und die Backup-Versionen werden eingespielt. Konflikte/Warnungen siehst du in der Preview."
      >
        {importing ? 'Importiere…' : 'Import (Restore)'}
      </Button>
      <Button
        variant="secondary"
        onClick={onPromptImportActiveBackup}
        disabled={importingActive}
        title="Import fuer 'active-only'-Backups: legt neue TermsContent-Versionen an und setzt sie aktiv. Aeltere Versionen bleiben als Historie erhalten. Ablauf wie beim Restore: Dry-Run-Preview, dann bestaetigter Import."
      >
        {importingActive ? 'Importiere…' : 'Import active (as new)'}
      </Button>
      <Button onClick={onCreateEmptyVersion}>+ Neue Version (leer)</Button>
    </div>
  );
}
