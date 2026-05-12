import { useState } from 'react';
import { useMutation, useQueryClient } from '@tanstack/react-query';
import clsx from 'clsx';
import { cloudFunction } from '../../../api/admin';
import { Button, Card } from '../../../components/ui';
import { useTheme } from '../../../context/ThemeContext';

interface CorrectionModalProps {
  onClose: () => void;
}

const CORRECTION_TYPES = [
  { value: 'fee_refund', label: 'Gebührenerstattung', targetType: 'user' },
  { value: 'investment_adjustment', label: 'Investment-Korrektur', targetType: 'investment' },
  { value: 'balance_adjustment', label: 'Kontostand-Korrektur', targetType: 'user' },
  { value: 'vat_remittance', label: 'USt-Abführung Finanzamt', targetType: 'system' },
  { value: 'other', label: 'Sonstiges', targetType: 'other' },
] as const;

export function CorrectionModal({ onClose }: CorrectionModalProps): JSX.Element {
  const { theme } = useTheme();
  const isDark = theme === 'dark';
  const queryClient = useQueryClient();
  const [correctionType, setCorrectionType] = useState('fee_refund');
  const [targetId, setTargetId] = useState('');
  const [amount, setAmount] = useState('');
  const [reason, setReason] = useState('');
  const [feeRefundInvoiceId, setFeeRefundInvoiceId] = useState('');
  const [feeRefundBatchId, setFeeRefundBatchId] = useState('');
  const [error, setError] = useState<string | null>(null);

  const selectedType = CORRECTION_TYPES.find((t) => t.value === correctionType);

  const mutation = useMutation({
    mutationFn: () =>
      cloudFunction('createCorrectionRequest', {
        correctionType,
        targetId: targetId || undefined,
        targetType: selectedType?.targetType || 'other',
        reason,
        oldValue: '0',
        newValue: amount,
        ...(correctionType === 'fee_refund' && feeRefundInvoiceId.trim()
          ? { invoiceId: feeRefundInvoiceId.trim() }
          : {}),
        ...(correctionType === 'fee_refund' && feeRefundBatchId.trim()
          ? { batchId: feeRefundBatchId.trim() }
          : {}),
      }),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['financialDashboard'] });
      queryClient.invalidateQueries({ queryKey: ['approvals'] });
      alert('Korrekturanfrage erstellt. Diese wird zur 4-Augen-Freigabe weitergeleitet.');
      onClose();
    },
    onError: (err: Error) => {
      setError(err.message || 'Fehler beim Erstellen der Korrekturanfrage');
    },
  });

  const handleSubmit = async (e: React.FormEvent): Promise<void> => {
    e.preventDefault();
    setError(null);

    const amountNum = Number(amount);
    if (!amount || !Number.isFinite(amountNum) || amountNum <= 0) {
      setError('Bitte geben Sie einen gültigen Betrag ein.');
      return;
    }
    if (!reason.trim()) {
      setError('Bitte geben Sie eine Begründung ein.');
      return;
    }
    if (correctionType === 'fee_refund') {
      if (!feeRefundInvoiceId.trim() && !feeRefundBatchId.trim()) {
        setError(
          'Gebührenerstattung: Bitte mindestens eine Invoice-ID (Parse) oder eine Batch-ID angeben.',
        );
        return;
      }
    }

    mutation.mutate();
  };

  const fieldClass = clsx(
    'w-full px-3 py-2 rounded-lg focus:outline-none focus:ring-2 focus:ring-fin1-primary focus:border-fin1-primary',
    isDark
      ? 'bg-slate-900/90 border border-slate-600 text-slate-100 placeholder:text-slate-500'
      : 'border border-gray-200 text-gray-900 bg-white placeholder:text-gray-400',
  );

  return (
    <div className="fixed inset-0 bg-black/50 flex items-center justify-center z-50 p-4">
      <Card className="max-w-md w-full max-h-[90vh] overflow-y-auto shadow-xl" padding="none">
        <div className={clsx('p-6 border-b', isDark ? 'border-slate-600' : 'border-gray-100')}>
          <h2 className={clsx('text-xl font-semibold', isDark ? 'text-slate-100' : 'text-gray-900')}>
            Neue Korrekturbuchung
          </h2>
          <p className={clsx('text-sm mt-1', isDark ? 'text-slate-400' : 'text-gray-500')}>
            Erfordert 4-Augen-Freigabe durch einen zweiten Admin
          </p>
        </div>
        <form onSubmit={handleSubmit} className="p-6 space-y-4">
          {error && (
            <div
              className={clsx(
                'p-3 text-sm rounded-lg border',
                isDark
                  ? 'bg-red-950/50 border-red-800/80 text-red-200'
                  : 'bg-red-50 border-transparent text-red-700',
              )}
            >
              {error}
            </div>
          )}
          <div>
            <label className={clsx('block text-sm font-medium mb-1', isDark ? 'text-slate-300' : 'text-gray-700')}>
              Art der Korrektur
            </label>
            <select
              value={correctionType}
              onChange={(e) => setCorrectionType(e.target.value)}
              className={fieldClass}
            >
              {CORRECTION_TYPES.map((t) => (
                <option key={t.value} value={t.value}>
                  {t.label}
                </option>
              ))}
            </select>
          </div>

          {selectedType?.targetType !== 'system' && (
            <div>
              <label className={clsx('block text-sm font-medium mb-1', isDark ? 'text-slate-300' : 'text-gray-700')}>
                {selectedType?.targetType === 'investment'
                  ? 'Investment-ID'
                  : 'User-ID (Empfänger)'}
              </label>
              <input
                type="text"
                value={targetId}
                onChange={(e) => setTargetId(e.target.value)}
                placeholder={
                  selectedType?.targetType === 'investment'
                    ? 'Investment-ID eingeben...'
                    : 'User-ID eingeben...'
                }
                className={fieldClass}
              />
            </div>
          )}

          <div>
            <label className={clsx('block text-sm font-medium mb-1', isDark ? 'text-slate-300' : 'text-gray-700')}>
              Betrag (EUR)
            </label>
            <input
              type="number"
              step="0.01"
              min="0.01"
              value={amount}
              onChange={(e) => setAmount(e.target.value)}
              placeholder="0.00"
              className={fieldClass}
              required
            />
          </div>

          {correctionType === 'fee_refund' && (
            <div className="space-y-3">
              <p
                className={clsx(
                  'text-xs p-2 rounded border',
                  isDark
                    ? 'text-slate-300 bg-slate-900/50 border-slate-600'
                    : 'text-gray-500 bg-gray-50 border-transparent',
                )}
              >
                Pflicht: mindestens eines ausfüllen — Parse <code className="text-xs">Invoice</code>
                -objectId und/oder <code className="text-xs">batchId</code> der App-Servicegebühr.
                Werden beide angegeben, muss die Batch-ID exakt dem Batch der Rechnung entsprechen
                (sonst lehnt der Server ab).
              </p>
              <div>
                <label className={clsx('block text-sm font-medium mb-1', isDark ? 'text-slate-300' : 'text-gray-700')}>
                  Invoice-ID (Parse objectId)
                </label>
                <input
                  type="text"
                  value={feeRefundInvoiceId}
                  onChange={(e) => setFeeRefundInvoiceId(e.target.value)}
                  placeholder="Parse objectId der Rechnung…"
                  className={fieldClass}
                />
              </div>
              <div>
                <label className={clsx('block text-sm font-medium mb-1', isDark ? 'text-slate-300' : 'text-gray-700')}>
                  Batch-ID (Investment-Batch)
                </label>
                <input
                  type="text"
                  value={feeRefundBatchId}
                  onChange={(e) => setFeeRefundBatchId(e.target.value)}
                  placeholder="Investment batchId…"
                  className={fieldClass}
                />
              </div>
            </div>
          )}

          {correctionType === 'vat_remittance' && (
            <p
              className={clsx(
                'text-xs p-2 rounded border',
                isDark
                  ? 'text-slate-300 bg-slate-900/50 border-slate-600'
                  : 'text-gray-500 bg-gray-50 border-transparent',
              )}
            >
              USt-Abführung: Betrag wird von PLT-TAX-VAT abgebucht und als Zahlung ans Finanzamt
              verbucht. Die Buchung reduziert die ausstehende USt-Verbindlichkeit.
            </p>
          )}

          <div>
            <label className={clsx('block text-sm font-medium mb-1', isDark ? 'text-slate-300' : 'text-gray-700')}>
              Begründung
            </label>
            <textarea
              value={reason}
              onChange={(e) => setReason(e.target.value)}
              rows={3}
              placeholder="Detaillierte Begründung für die Korrektur..."
              className={fieldClass}
              required
            />
          </div>

          <div className="flex gap-3 pt-4 justify-end flex-wrap">
            <Button type="button" variant="ghost" onClick={onClose}>
              Abbrechen
            </Button>
            <Button type="submit" className="flex-1 min-w-[12rem]" disabled={mutation.isPending}>
              {mutation.isPending ? 'Wird erstellt...' : 'Korrektur einreichen'}
            </Button>
          </div>
        </form>
      </Card>
    </div>
  );
}
