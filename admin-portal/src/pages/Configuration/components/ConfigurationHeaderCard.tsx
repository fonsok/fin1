import { Card, Button, Badge } from '../../../components/ui';
import clsx from 'clsx';
import { useTheme } from '../../../context/ThemeContext';

import { adminMuted, adminPrimary } from '../../../utils/adminThemeClasses';
interface ConfigurationHeaderCardProps {
  pendingCount: number;
  onTogglePending: () => void;
}

export function ConfigurationHeaderCard({
  pendingCount,
  onTogglePending,
}: ConfigurationHeaderCardProps) {
  const { theme } = useTheme();
  const isDark = theme === 'dark';

  return (
    <Card>
      <div className="flex items-center justify-between">
        <div>
          <h2 className={clsx('text-lg font-semibold', adminPrimary(isDark))}>
            System-Konfiguration
          </h2>
          <p className={clsx('text-sm mt-1', adminMuted(isDark))}>
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
