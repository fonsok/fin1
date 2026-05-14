import { useState } from 'react';
import { useMutation, useQueryClient } from '@tanstack/react-query';
import { reviewCompanyKyb, type KybSubmission } from '../../../api/admin';
import { Card, Button, Badge } from '../../../components/ui';
import { useTheme } from '../../../context/ThemeContext';
import { formatDateTime } from '../../../utils/format';
import clsx from 'clsx';

import { adminMuted, adminPrimary } from '../../../utils/adminThemeClasses';
interface KYBDecisionModalProps {
  submission: KybSubmission;
  onClose: () => void;
  onComplete: () => void;
}

export function KYBDecisionModal({ submission, onClose, onComplete }: KYBDecisionModalProps) {
  const { theme } = useTheme();
  const isDark = theme === 'dark';
  const queryClient = useQueryClient();
  const [decision, setDecision] = useState<'approved' | 'rejected' | 'more_info_requested'>('approved');
  const [notes, setNotes] = useState('');
  const [successMessage, setSuccessMessage] = useState<string | null>(null);

  const mutation = useMutation({
    mutationFn: () => reviewCompanyKyb(submission.userId, decision, notes || undefined),
    onSuccess: (result) => {
      queryClient.invalidateQueries({ queryKey: ['kybSubmissions'] });
      queryClient.invalidateQueries({ queryKey: ['kybDetail', submission.userId] });
      setSuccessMessage(result.message);
      setTimeout(onComplete, 1500);
    },
  });

  const displayName = [submission.firstName, submission.lastName].filter(Boolean).join(' ') || submission.email;
  const notesRequired = decision === 'rejected' || decision === 'more_info_requested';
  const isSubmitDisabled = notesRequired && !notes.trim();

  if (successMessage) {
    return (
      <div className="fixed inset-0 bg-black/50 flex items-center justify-center z-50 p-4">
        <Card className="w-full max-w-md text-center">
          <div className="text-4xl mb-4">{decision === 'approved' ? '✅' : decision === 'more_info_requested' ? '📋' : '❌'}</div>
          <p className={clsx('text-lg font-semibold', adminPrimary(isDark))}>
            {successMessage}
          </p>
        </Card>
      </div>
    );
  }

  return (
    <div className="fixed inset-0 bg-black/50 flex items-center justify-center z-50 p-4">
      <Card className="w-full max-w-lg">
        <h3 className={clsx('text-lg font-semibold mb-4', adminPrimary(isDark))}>
          KYB-Entscheidung
        </h3>

        {/* Submission info */}
        <div className={clsx(
          'space-y-3 mb-5 p-4 rounded-lg',
          isDark ? 'bg-slate-600/50' : 'bg-gray-50',
        )}>
          <div className="flex justify-between text-sm">
            <span className={clsx(adminMuted(isDark))}>Firma:</span>
            <span className={clsx('font-medium', adminPrimary(isDark))}>
              {displayName}
            </span>
          </div>
          <div className="flex justify-between text-sm">
            <span className={clsx(adminMuted(isDark))}>Kunden-ID:</span>
            <span className="font-mono text-xs">{submission.customerNumber}</span>
          </div>
          <div className="flex justify-between text-sm">
            <span className={clsx(adminMuted(isDark))}>E-Mail:</span>
            <span>{submission.email}</span>
          </div>
          <div className="flex justify-between text-sm">
            <span className={clsx(adminMuted(isDark))}>Eingereicht am:</span>
            <span>{formatDateTime(submission.companyKybCompletedAt)}</span>
          </div>
          <div className="flex justify-between text-sm">
            <span className={clsx(adminMuted(isDark))}>Status:</span>
            <Badge variant="warning">Ausstehend</Badge>
          </div>
        </div>

        {/* Decision toggle */}
        <div className="mb-4">
          <label className={clsx('block text-sm font-medium mb-2', isDark ? 'text-slate-300' : 'text-gray-700')}>
            Entscheidung
          </label>
          <div className="flex gap-2">
            <button
              onClick={() => setDecision('approved')}
              className={clsx(
                'flex-1 py-2.5 px-3 rounded-lg text-sm font-medium border-2 transition-colors',
                decision === 'approved'
                  ? 'border-emerald-500 bg-emerald-50 text-emerald-700'
                  : isDark
                    ? 'border-slate-600 text-slate-300 hover:border-slate-500'
                    : 'border-gray-200 text-gray-600 hover:border-gray-300',
                decision === 'approved' && isDark && 'bg-emerald-900/30 text-emerald-300 border-emerald-600',
              )}
            >
              ✅ Genehmigen
            </button>
            <button
              onClick={() => setDecision('more_info_requested')}
              className={clsx(
                'flex-1 py-2.5 px-3 rounded-lg text-sm font-medium border-2 transition-colors',
                decision === 'more_info_requested'
                  ? 'border-amber-500 bg-amber-50 text-amber-700'
                  : isDark
                    ? 'border-slate-600 text-slate-300 hover:border-slate-500'
                    : 'border-gray-200 text-gray-600 hover:border-gray-300',
                decision === 'more_info_requested' && isDark && 'bg-amber-900/30 text-amber-300 border-amber-600',
              )}
            >
              📋 Nachbesserung
            </button>
            <button
              onClick={() => setDecision('rejected')}
              className={clsx(
                'flex-1 py-2.5 px-3 rounded-lg text-sm font-medium border-2 transition-colors',
                decision === 'rejected'
                  ? 'border-red-500 bg-red-50 text-red-700'
                  : isDark
                    ? 'border-slate-600 text-slate-300 hover:border-slate-500'
                    : 'border-gray-200 text-gray-600 hover:border-gray-300',
                decision === 'rejected' && isDark && 'bg-red-900/30 text-red-300 border-red-600',
              )}
            >
              ❌ Ablehnen
            </button>
          </div>
        </div>

        {/* Notes */}
        <div className="mb-5">
          <label className={clsx('block text-sm font-medium mb-1', isDark ? 'text-slate-300' : 'text-gray-700')}>
            {decision === 'approved'
              ? 'Notizen (optional)'
              : decision === 'more_info_requested'
                ? 'Welche Informationen fehlen? (erforderlich)'
                : 'Ablehnungsgrund (erforderlich)'}
          </label>
          <textarea
            value={notes}
            onChange={(e) => setNotes(e.target.value)}
            className={clsx(
              'w-full px-4 py-2 rounded-lg border focus:outline-none focus:ring-2 focus:ring-fin1-primary',
              isDark
                ? 'bg-slate-700 border-slate-600 text-slate-100 placeholder-slate-500'
                : 'bg-white border-gray-300 text-gray-900 placeholder-gray-400',
            )}
            rows={3}
            placeholder={
              decision === 'approved'
                ? 'Optionale Notizen...'
                : decision === 'more_info_requested'
                  ? 'Bitte beschreiben Sie die fehlenden oder fehlerhaften Angaben...'
                  : 'Grund für die Ablehnung...'
            }
          />
        </div>

        {/* Error */}
        {mutation.isError && (
          <div className={clsx(
            'mb-4 p-3 rounded-lg text-sm',
            isDark ? 'bg-red-900/30 text-red-300' : 'bg-red-50 text-red-700',
          )}>
            {(mutation.error as Error)?.message ?? 'Ein Fehler ist aufgetreten.'}
          </div>
        )}

        {/* Actions */}
        <div className="flex gap-3 justify-end">
          <Button variant="secondary" onClick={onClose} disabled={mutation.isPending}>
            Abbrechen
          </Button>
          <Button
            variant={decision === 'approved' ? 'success' : decision === 'more_info_requested' ? 'warning' : 'danger'}
            loading={mutation.isPending}
            disabled={isSubmitDisabled}
            onClick={() => mutation.mutate()}
          >
            {decision === 'approved'
              ? 'Genehmigen'
              : decision === 'more_info_requested'
                ? 'Nachbesserung anfordern'
                : 'Ablehnen'}
          </Button>
        </div>
      </Card>
    </div>
  );
}
