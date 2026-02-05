import { useState } from 'react';
import { Button } from '../../../components/ui';

interface CorrectionModalProps {
  onClose: () => void;
}

export function CorrectionModal({ onClose }: CorrectionModalProps): JSX.Element {
  const [type, setType] = useState('fee_refund');
  const [amount, setAmount] = useState('');
  const [reason, setReason] = useState('');

  const handleSubmit = async (e: React.FormEvent): Promise<void> => {
    e.preventDefault();
    // TODO: Call createCorrectionRequest Cloud Function
    alert('Korrekturanfrage erstellt. Diese wird zur 4-Augen-Freigabe weitergeleitet.');
    onClose();
  };

  return (
    <div className="fixed inset-0 bg-black/50 flex items-center justify-center z-50">
      <div className="bg-white rounded-xl shadow-xl max-w-md w-full mx-4">
        <div className="p-6 border-b border-gray-100">
          <h2 className="text-xl font-semibold">Neue Korrekturbuchung</h2>
          <p className="text-sm text-gray-500 mt-1">
            Erfordert 4-Augen-Freigabe durch einen zweiten Admin
          </p>
        </div>
        <form onSubmit={handleSubmit} className="p-6 space-y-4">
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">
              Art der Korrektur
            </label>
            <select
              value={type}
              onChange={(e) => setType(e.target.value)}
              className="w-full px-3 py-2 border border-gray-200 rounded-lg focus:ring-2 focus:ring-fin1-primary focus:border-fin1-primary"
            >
              <option value="fee_refund">Gebührenerstattung</option>
              <option value="investment_adjustment">Investment-Korrektur</option>
              <option value="balance_adjustment">Kontostand-Korrektur</option>
              <option value="other">Sonstiges</option>
            </select>
          </div>
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">
              Betrag (EUR)
            </label>
            <input
              type="number"
              step="0.01"
              value={amount}
              onChange={(e) => setAmount(e.target.value)}
              placeholder="0.00"
              className="w-full px-3 py-2 border border-gray-200 rounded-lg focus:ring-2 focus:ring-fin1-primary focus:border-fin1-primary"
              required
            />
          </div>
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">
              Begründung
            </label>
            <textarea
              value={reason}
              onChange={(e) => setReason(e.target.value)}
              rows={3}
              placeholder="Detaillierte Begründung für die Korrektur..."
              className="w-full px-3 py-2 border border-gray-200 rounded-lg focus:ring-2 focus:ring-fin1-primary focus:border-fin1-primary"
              required
            />
          </div>
          <div className="flex gap-3 pt-4">
            <Button type="button" variant="ghost" onClick={onClose}>
              Abbrechen
            </Button>
            <Button type="submit" className="flex-1">
              Korrektur einreichen
            </Button>
          </div>
        </form>
      </div>
    </div>
  );
}
