import { useState } from 'react';
import { getAdminListSearchHealth, type AdminListSearchHealth } from '../../api/admin';
import { Button } from '../../components/ui/Button';

const SEARCH_INDEX_STATUS_TOOLTIP =
  'Prüft MongoDB Text- und Prefix-Index auf adminSearchBlob für Investment- und Trade-Listen (Summary-Report-Suche). Zeigt Index-Status und ob Beispieldatensätze ein Suchfeld haben.';

function formatCollectionLine(label: string, c: AdminListSearchHealth['investment']): string {
  if (!c.ok) {
    return `${label}: Fehler — ${c.error ?? 'unbekannt'}`;
  }
  const text = c.hasTextOnBlob ? 'ja' : 'nein';
  const prefix = c.hasPrefixOnBlob ? 'ja' : 'nein';
  return `${label}: Text-Index ${text}, Prefix-Index ${prefix}`;
}

function formatHealthMessage(health: AdminListSearchHealth): string {
  const status = health.healthy ? 'OK (healthy)' : 'Nicht OK';
  const lines = [
    `Such-Index Status: ${status}`,
    '',
    formatCollectionLine('Investment', health.investment),
    formatCollectionLine('Trade', health.trade),
    '',
    `Beispiel adminSearchBlob — Investment: ${health.samples.investmentHasBlob ? 'ja' : 'nein'}, Trade: ${health.samples.tradeHasBlob ? 'ja' : 'nein'}`,
  ];
  if (health.repairHint) {
    lines.push('', `Hinweis: ${health.repairHint}`);
  }
  return lines.join('\n');
}

export function SummaryReportSearchIndexStatusButton(): JSX.Element {
  const [loading, setLoading] = useState(false);

  const handleClick = async () => {
    setLoading(true);
    try {
      const health = await getAdminListSearchHealth();
      window.alert(formatHealthMessage(health));
    } catch (err) {
      window.alert(err instanceof Error ? err.message : 'Such-Index-Status konnte nicht geladen werden.');
    } finally {
      setLoading(false);
    }
  };

  return (
    <Button
      variant="secondary"
      onClick={() => void handleClick()}
      disabled={loading}
      title={SEARCH_INDEX_STATUS_TOOLTIP}
    >
      {loading ? 'Prüfe…' : 'Such-Index Status'}
    </Button>
  );
}
