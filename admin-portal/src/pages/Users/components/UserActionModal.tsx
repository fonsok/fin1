import clsx from 'clsx';
import { Card, Button } from '../../../components/ui';

import { adminControlField, adminSoft, adminStrong } from '../../../utils/adminThemeClasses';
interface UserActionModalProps {
  showActionModal: 'suspend' | 'reactivate' | 'reset' | null;
  actionReason: string;
  isDark: boolean;
  loading: boolean;
  onChangeReason: (value: string) => void;
  onClose: () => void;
  onConfirm: () => void;
}

export function UserActionModal({
  showActionModal,
  actionReason,
  isDark,
  loading,
  onChangeReason,
  onClose,
  onConfirm,
}: UserActionModalProps) {
  if (!showActionModal) return null;

  return (
    <div className="fixed inset-0 bg-black/50 flex items-center justify-center z-50 p-4">
      <Card className="w-full max-w-md">
        <h3 className="text-lg font-semibold mb-4">
          {showActionModal === 'suspend' && 'Benutzer sperren'}
          {showActionModal === 'reactivate' && 'Benutzer reaktivieren'}
          {showActionModal === 'reset' && 'Passwort zurücksetzen'}
        </h3>

        <p className={clsx('mb-4', adminSoft(isDark))}>
          {showActionModal === 'suspend' && 'Der Benutzer wird gesperrt und kann sich nicht mehr anmelden.'}
          {showActionModal === 'reactivate' && 'Der Benutzer wird reaktiviert und kann sich wieder anmelden.'}
          {showActionModal === 'reset' && 'Der Benutzer muss beim nächsten Login ein neues Passwort setzen.'}
        </p>

        <label className={clsx('block text-sm font-medium mb-1', adminStrong(isDark))}>
          Begründung (wird protokolliert)
        </label>
        <textarea
          value={actionReason}
          onChange={(e) => onChangeReason(e.target.value)}
          className={clsx(
            'w-full px-4 py-2 border rounded-lg focus:outline-none focus:ring-2 focus:ring-fin1-primary mb-4',
            adminControlField(isDark),
          )}
          rows={3}
          placeholder="Grund für diese Aktion..."
          required
        />

        <div className="flex gap-3 justify-end">
          <Button variant="secondary" onClick={onClose}>
            Abbrechen
          </Button>
          <Button
            variant={showActionModal === 'suspend' ? 'danger' : 'primary'}
            disabled={!actionReason.trim()}
            loading={loading}
            onClick={onConfirm}
          >
            Bestätigen
          </Button>
        </div>
      </Card>
    </div>
  );
}
