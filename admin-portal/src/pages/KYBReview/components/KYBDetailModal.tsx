import { useState } from 'react';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { getCompanyKybSubmissionDetail, resetCompanyKyb, type KybSubmission, type KybAuditEntry } from '../../../api/admin';
import { Card, Button, Badge } from '../../../components/ui';
import { useAuth } from '../../../context/AuthContext';
import { useTheme } from '../../../context/ThemeContext';
import { formatDateTime } from '../../../utils/format';
import clsx from 'clsx';

const STEP_LABELS: Record<string, { label: string; icon: string }> = {
  legal_entity: { label: 'Rechtsform & Handelsregister', icon: '🏛️' },
  registered_address: { label: 'Anschrift', icon: '📍' },
  tax_compliance: { label: 'Steuerliche Angaben', icon: '📊' },
  beneficial_owners: { label: 'Wirtschaftlich Berechtigte', icon: '👥' },
  authorized_representatives: { label: 'Vertretungsberechtigte', icon: '✍️' },
  documents: { label: 'Dokumente', icon: '📄' },
  declarations: { label: 'Erklärungen', icon: '📋' },
  submission: { label: 'Einreichung', icon: '📨' },
};

interface KYBDetailModalProps {
  userId: string;
  onClose: () => void;
  onReview: (submission: KybSubmission) => void;
}

export function KYBDetailModal({ userId, onClose, onReview }: KYBDetailModalProps) {
  const { hasPermission } = useAuth();
  const canReviewKyb = hasPermission('reviewCompanyKyb');
  const canResetKyb = hasPermission('resetCompanyKyb');
  const { theme } = useTheme();
  const isDark = theme === 'dark';
  const queryClient = useQueryClient();
  const [expandedSteps, setExpandedSteps] = useState<Set<string>>(new Set());
  const [resetNotes, setResetNotes] = useState('');
  const [showResetForm, setShowResetForm] = useState(false);

  const { data, isLoading, error } = useQuery({
    queryKey: ['kybDetail', userId],
    queryFn: () => getCompanyKybSubmissionDetail(userId),
  });

  const resetMutation = useMutation({
    mutationFn: () => resetCompanyKyb(userId, resetNotes || undefined),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['kybSubmissions'] });
      queryClient.invalidateQueries({ queryKey: ['kybDetail', userId] });
      setShowResetForm(false);
      setResetNotes('');
    },
  });

  const canReset =
    canResetKyb &&
    (data?.user.companyKybStatus === 'rejected' || data?.user.companyKybStatus === 'more_info_requested');

  function toggleStep(step: string) {
    setExpandedSteps((prev) => {
      const next = new Set(prev);
      if (next.has(step)) next.delete(step);
      else next.add(step);
      return next;
    });
  }

  const STATUS_CONFIG: Record<string, { variant: 'success' | 'danger' | 'warning' | 'info'; label: string }> = {
    approved: { variant: 'success', label: 'Genehmigt' },
    rejected: { variant: 'danger', label: 'Abgelehnt' },
    more_info_requested: { variant: 'warning', label: 'Nachbesserung' },
    pending_review: { variant: 'warning', label: 'Ausstehend' },
    draft: { variant: 'info', label: 'Entwurf' },
  };
  const statusCfg = STATUS_CONFIG[data?.user.companyKybStatus ?? ''] ?? { variant: 'warning' as const, label: data?.user.companyKybStatus ?? 'Unbekannt' };
  const statusVariant = statusCfg.variant;
  const statusLabel = statusCfg.label;

  return (
    <div className="fixed inset-0 bg-black/50 flex items-start justify-center z-50 p-4 overflow-y-auto">
      <Card className="w-full max-w-3xl my-8">
        <div className="flex items-start justify-between mb-6">
          <div>
            <h2 className={clsx('text-xl font-bold', isDark ? 'text-slate-100' : 'text-gray-900')}>
              KYB-Einreichung
            </h2>
            {data && (
              <p className={clsx('text-sm mt-1', isDark ? 'text-slate-400' : 'text-gray-500')}>
                {data.user.customerNumber} &middot; {data.user.email}
              </p>
            )}
          </div>
          <button
            onClick={onClose}
            className={clsx(
              'p-2 rounded-lg transition-colors',
              isDark ? 'hover:bg-slate-600 text-slate-400' : 'hover:bg-gray-100 text-gray-400',
            )}
          >
            <svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M6 18L18 6M6 6l12 12" />
            </svg>
          </button>
        </div>

        {isLoading ? (
          <div className="flex items-center justify-center py-12">
            <div className="animate-spin w-8 h-8 border-4 border-fin1-primary border-t-transparent rounded-full" />
          </div>
        ) : error ? (
          <div className="text-center py-8">
            <p className={clsx('text-sm', isDark ? 'text-red-400' : 'text-red-600')}>
              Fehler beim Laden der Details.
            </p>
          </div>
        ) : data ? (
          <div className="space-y-4">
            {/* User Info */}
            <div className={clsx(
              'p-4 rounded-lg',
              isDark ? 'bg-slate-600/50' : 'bg-gray-50',
            )}>
              <div className="grid grid-cols-2 gap-3 text-sm">
                <InfoRow label="Name" value={[data.user.firstName, data.user.lastName].filter(Boolean).join(' ') || '-'} isDark={isDark} />
                <InfoRow label="Status" value={<Badge variant={statusVariant}>{statusLabel}</Badge>} isDark={isDark} />
                <InfoRow label="Eingereicht am" value={formatDateTime(data.user.companyKybCompletedAt)} isDark={isDark} />
                <InfoRow label="Letzter Schritt" value={STEP_LABELS[data.user.companyKybStep ?? '']?.label ?? data.user.companyKybStep ?? '-'} isDark={isDark} />
                {data.user.companyKybReviewedAt && (
                  <>
                    <InfoRow label="Geprüft am" value={formatDateTime(data.user.companyKybReviewedAt)} isDark={isDark} />
                    <InfoRow label="Geprüft von" value={data.user.companyKybReviewedBy ?? '-'} isDark={isDark} />
                  </>
                )}
                {data.user.companyKybReviewNotes && (
                  <div className="col-span-2">
                    <InfoRow label="Prüfungsnotizen" value={data.user.companyKybReviewNotes} isDark={isDark} />
                  </div>
                )}
              </div>
            </div>

            {/* Audit Trail Steps */}
            <h3 className={clsx('text-base font-semibold mt-6', isDark ? 'text-slate-200' : 'text-gray-800')}>
              Eingereichte Daten
            </h3>
            <div className="space-y-2">
              {data.auditTrail
                .filter((a) => !a.step.startsWith('review_'))
                .map((entry) => (
                  <StepAccordion
                    key={entry.objectId}
                    entry={entry}
                    expanded={expandedSteps.has(entry.step)}
                    onToggle={() => toggleStep(entry.step)}
                    isDark={isDark}
                  />
                ))}
            </div>

            {/* Actions */}
            {data.user.companyKybStatus === 'pending_review' && (
              <div className="flex justify-end gap-3 pt-4 border-t border-gray-200">
                <Button variant="secondary" onClick={onClose}>
                  Schließen
                </Button>
                {canReviewKyb && (
                  <Button
                    variant="primary"
                    onClick={() => onReview({
                      userId: data.user.objectId,
                      customerNumber: data.user.customerNumber,
                      email: data.user.email,
                      firstName: data.user.firstName,
                      lastName: data.user.lastName,
                      companyKybStatus: data.user.companyKybStatus,
                      companyKybCompletedAt: data.user.companyKybCompletedAt,
                      createdAt: '',
                    })}
                  >
                    Entscheidung treffen
                  </Button>
                )}
              </div>
            )}
            {data.user.companyKybStatus !== 'pending_review' && (
              <div className="flex flex-col gap-3 pt-4 border-t border-gray-200">
                {canReset && !showResetForm && (
                  <div className="flex justify-between items-center">
                    <p className={clsx('text-sm', isDark ? 'text-slate-400' : 'text-gray-500')}>
                      Zur Überarbeitung freigeben, damit der Nutzer erneut einreichen kann.
                    </p>
                    <Button variant="warning" onClick={() => setShowResetForm(true)}>
                      KYB zurücksetzen
                    </Button>
                  </div>
                )}
                {showResetForm && (
                  <div className={clsx('p-4 rounded-lg space-y-3', isDark ? 'bg-amber-900/20 border border-amber-700' : 'bg-amber-50 border border-amber-200')}>
                    <label className={clsx('block text-sm font-medium', isDark ? 'text-amber-300' : 'text-amber-700')}>
                      Anmerkung zum Zurücksetzen (optional)
                    </label>
                    <textarea
                      value={resetNotes}
                      onChange={(e) => setResetNotes(e.target.value)}
                      className={clsx(
                        'w-full px-4 py-2 rounded-lg border focus:outline-none focus:ring-2 focus:ring-amber-400',
                        isDark ? 'bg-slate-700 border-slate-600 text-slate-100' : 'bg-white border-gray-300 text-gray-900',
                      )}
                      rows={2}
                      placeholder="Optionaler Hinweis..."
                    />
                    {resetMutation.isError && (
                      <p className={clsx('text-sm', isDark ? 'text-red-400' : 'text-red-600')}>
                        {(resetMutation.error as Error)?.message ?? 'Fehler beim Zurücksetzen.'}
                      </p>
                    )}
                    <div className="flex gap-2 justify-end">
                      <Button variant="secondary" onClick={() => { setShowResetForm(false); setResetNotes(''); }}>
                        Abbrechen
                      </Button>
                      <Button variant="warning" loading={resetMutation.isPending} onClick={() => resetMutation.mutate()}>
                        Zurücksetzen bestätigen
                      </Button>
                    </div>
                  </div>
                )}
                <div className="flex justify-end">
                  <Button variant="secondary" onClick={onClose}>
                    Schließen
                  </Button>
                </div>
              </div>
            )}
          </div>
        ) : null}
      </Card>
    </div>
  );
}

function InfoRow({ label, value, isDark }: { label: string; value: React.ReactNode; isDark: boolean }) {
  return (
    <div>
      <span className={clsx('text-xs', isDark ? 'text-slate-400' : 'text-gray-500')}>{label}</span>
      <div className={clsx('font-medium', isDark ? 'text-slate-100' : 'text-gray-900')}>
        {typeof value === 'string' ? value : value}
      </div>
    </div>
  );
}

function StepAccordion({
  entry,
  expanded,
  onToggle,
  isDark,
}: {
  entry: KybAuditEntry;
  expanded: boolean;
  onToggle: () => void;
  isDark: boolean;
}) {
  const stepMeta = STEP_LABELS[entry.step] ?? { label: entry.step, icon: '📝' };
  const displayData = entry.fullData ?? entry.answers;

  return (
    <div className={clsx(
      'rounded-lg border transition-colors',
      isDark ? 'border-slate-600 bg-slate-700/50' : 'border-gray-200 bg-white',
    )}>
      <button
        onClick={onToggle}
        className={clsx(
          'w-full flex items-center justify-between px-4 py-3 text-left',
          isDark ? 'hover:bg-slate-600/40' : 'hover:bg-gray-50',
        )}
      >
        <div className="flex items-center gap-2">
          <span>{stepMeta.icon}</span>
          <span className={clsx('font-medium text-sm', isDark ? 'text-slate-100' : 'text-gray-800')}>
            {stepMeta.label}
          </span>
          <span className={clsx('text-xs', isDark ? 'text-slate-500' : 'text-gray-400')}>
            {formatDateTime(entry.completedAt)}
          </span>
        </div>
        <svg
          className={clsx(
            'w-4 h-4 transition-transform',
            expanded && 'rotate-180',
            isDark ? 'text-slate-400' : 'text-gray-400',
          )}
          fill="none" stroke="currentColor" viewBox="0 0 24 24"
        >
          <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M19 9l-7 7-7-7" />
        </svg>
      </button>
      {expanded && displayData && (
        <div className={clsx(
          'px-4 pb-4 border-t',
          isDark ? 'border-slate-600' : 'border-gray-100',
        )}>
          <div className="mt-3 space-y-2">
            {renderStepData(entry.step, displayData, isDark)}
          </div>
        </div>
      )}
    </div>
  );
}

function renderStepData(_step: string, data: Record<string, unknown>, isDark: boolean) {
  const fields = Object.entries(data).filter(([k]) => k !== '_positionOnly');

  if (fields.length === 0) {
    return (
      <p className={clsx('text-sm italic', isDark ? 'text-slate-500' : 'text-gray-400')}>
        Keine Daten vorhanden
      </p>
    );
  }

  return fields.map(([key, value]) => {
    if (Array.isArray(value)) {
      return (
        <div key={key} className="space-y-1">
          <DataLabel label={formatFieldName(key)} isDark={isDark} />
          {value.map((item, idx) => (
            <div
              key={idx}
              className={clsx(
                'ml-3 p-2 rounded text-xs',
                isDark ? 'bg-slate-600/50' : 'bg-gray-50',
              )}
            >
              {typeof item === 'object' && item !== null
                ? Object.entries(item).map(([k, v]) => (
                    <div key={k} className="flex gap-2">
                      <span className={clsx(isDark ? 'text-slate-400' : 'text-gray-500')}>
                        {formatFieldName(k)}:
                      </span>
                      <span className={clsx('font-medium', isDark ? 'text-slate-200' : 'text-gray-800')}>
                        {formatValue(v)}
                      </span>
                    </div>
                  ))
                : <span>{String(item)}</span>}
            </div>
          ))}
        </div>
      );
    }

    return (
      <div key={key} className="flex items-baseline gap-2 text-sm">
        <DataLabel label={formatFieldName(key)} isDark={isDark} />
        <span className={clsx('font-medium', isDark ? 'text-slate-200' : 'text-gray-800')}>
          {formatValue(value)}
        </span>
      </div>
    );
  });
}

function DataLabel({ label, isDark }: { label: string; isDark: boolean }) {
  return (
    <span className={clsx('text-xs min-w-[140px]', isDark ? 'text-slate-400' : 'text-gray-500')}>
      {label}:
    </span>
  );
}

const FIELD_NAME_MAP: Record<string, string> = {
  legalName: 'Firmenname',
  legalForm: 'Rechtsform',
  registerType: 'Registerart',
  registerNumber: 'Registernummer',
  registerCourt: 'Registergericht',
  incorporationCountry: 'Gründungsland',
  streetAndNumber: 'Straße & Hausnr.',
  postalCode: 'PLZ',
  city: 'Stadt',
  country: 'Land',
  businessStreetAndNumber: 'Geschäftsadresse',
  businessPostalCode: 'Geschäfts-PLZ',
  businessCity: 'Geschäftsstadt',
  businessCountry: 'Geschäftsland',
  vatId: 'USt-IdNr.',
  nationalTaxNumber: 'Steuernummer',
  economicIdentificationNumber: 'W-IdNr.',
  noVatIdDeclared: 'Keine USt-IdNr.',
  ubos: 'Wirtschaftl. Berechtigte',
  noUboOver25Percent: 'Keine UBO über 25%',
  fullName: 'Vollständiger Name',
  dateOfBirth: 'Geburtsdatum',
  nationality: 'Staatsangehörigkeit',
  ownershipPercent: 'Anteil (%)',
  directOrIndirect: 'Direkt/Indirekt',
  representatives: 'Vertretungsberechtigte',
  appAccountHolderIsRepresentative: 'Kontoinhaber ist Vertreter',
  roleTitle: 'Funktion',
  signingAuthority: 'Zeichnungsberechtigt',
  tradeRegisterExtractReference: 'Handelsregisterauszug',
  documentManifest: 'Dokumentenliste',
  documentsAcknowledged: 'Dokumente bestätigt',
  isPoliticallyExposed: 'Politisch exponiert (PEP)',
  pepDetails: 'PEP-Details',
  sanctionsSelfDeclarationAccepted: 'Sanktionserklärung',
  accuracyDeclarationAccepted: 'Richtigkeitserklärung',
  noTrustThirdPartyDeclarationAccepted: 'Eigenmittelerklärung',
  confirmedSummary: 'Zusammenfassung bestätigt',
  companyFourEyesRequestId: '4-Augen-Anfrage-ID',
};

function formatFieldName(key: string): string {
  return FIELD_NAME_MAP[key] ?? key.replace(/([A-Z])/g, ' $1').replace(/^./, (s) => s.toUpperCase());
}

function formatValue(value: unknown): string {
  if (value === null || value === undefined) return '-';
  if (typeof value === 'boolean') return value ? 'Ja' : 'Nein';
  return String(value);
}
