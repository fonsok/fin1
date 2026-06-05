import clsx from 'clsx';
import type { DocumentBelegDisplaySection, DocumentSearchItem } from '../../api/admin';
import { formatDateTime } from '../../utils/format';
import {
  adminCaption,
  adminLabel,
  adminMuted,
  adminPrimary,
  adminStrong,
} from '../../utils/adminThemeClasses';
import { tableBodyCellMutedClasses } from '../../utils/tableStriping';

const TYPE_LABELS: Record<string, string> = {
  investorCollectionBill: 'Investor Collection Bill',
  traderCollectionBill: 'Trader Collection Bill',
  traderCreditNote: 'Gutschrift (Provision)',
  invoice: 'Rechnung',
  investmentReservationEigenbeleg: 'Eigenbeleg (Reservierung)',
  poolMirrorExecutionEigenbeleg: 'Eigenbeleg (Pool-Mirror)',
};

function typeLabel(type: string): string {
  return TYPE_LABELS[type] || type || 'Beleg';
}

function partyMetaLabel(detail: DocumentSearchItem): string {
  if (detail.partyLabel) return detail.partyLabel;
  if (detail.partyRole === 'trader') return 'Trader';
  if (detail.partyRole === 'investor') return 'Investor';
  return 'Inhaber';
}

function partyMetaValue(detail: DocumentSearchItem): string {
  const name = detail.partyDisplayName?.trim();
  const id = (detail.partyUserId || detail.userId || '').trim();
  if (name && id) return `${name} · ${id}`;
  return name || id || '—';
}

function SectionGrid({
  section,
  isDark,
}: {
  section: DocumentBelegDisplaySection;
  isDark: boolean;
}): JSX.Element {
  return (
    <div
      className={clsx(
        'rounded-lg border p-3 space-y-2',
        isDark ? 'border-slate-600 bg-slate-900/50' : 'border-gray-200 bg-gray-50/90',
      )}
    >
      <h3 className={clsx('text-sm font-semibold', adminStrong(isDark))}>{section.title}</h3>
      <dl className="grid grid-cols-1 sm:grid-cols-2 gap-x-4 gap-y-2 text-sm">
        {section.rows.map((row) => (
          <div key={`${section.title}-${row.label}`} className="min-w-0">
            <dt className={clsx('text-xs', adminCaption(isDark))}>{row.label}</dt>
            <dd className={clsx('font-medium whitespace-pre-wrap break-words', adminPrimary(isDark))}>
              {row.value}
            </dd>
          </div>
        ))}
      </dl>
    </div>
  );
}

export function DocumentBelegDetailPanel({
  detail,
  isDark,
}: {
  detail: DocumentSearchItem;
  isDark: boolean;
}): JSX.Element {
  const sections = detail.displaySections ?? [];
  const summaryText = detail.accountingSummaryText?.trim() ?? '';
  const showSummaryBlock = summaryText.length > 0;
  const isPlaceholder =
    detail.fileURL?.startsWith('eigenbeleg-') || detail.fileURL?.startsWith('invoice-beleg://');

  return (
    <div className="space-y-4">
      <div className="flex flex-wrap items-baseline gap-x-3 gap-y-1">
        <span className={clsx('text-base font-semibold', adminStrong(isDark))}>
          {typeLabel(detail.type)}
        </span>
        <span className={clsx('font-mono text-sm', adminLabel(isDark))}>
          {detail.accountingDocumentNumber || detail.documentNumber || '—'}
        </span>
        {(detail.summarySource === 'computed' || detail.summarySource === 'snapshot') && (
          <span className={clsx('text-xs', adminMuted(isDark))}>
            {detail.summarySource === 'snapshot' ? '(SSOT-Snapshot / Metadaten)' : '(Inhalt aus Metadaten)'}
          </span>
        )}
      </div>

      <div
        className={clsx(
          'grid grid-cols-2 sm:grid-cols-4 gap-3 text-sm rounded-lg border p-3',
          isDark ? 'border-slate-700' : 'border-gray-200',
        )}
      >
        <MetaCell label={partyMetaLabel(detail)} value={partyMetaValue(detail)} isDark={isDark} mono />
        <MetaCell label="Status" value={detail.status || '—'} isDark={isDark} />
        <MetaCell
          label="Hochgeladen"
          value={detail.uploadedAt ? formatDateTime(new Date(detail.uploadedAt)) : '—'}
          isDark={isDark}
        />
        <MetaCell label="Trade" value={detail.tradeId || '—'} isDark={isDark} mono />
        <MetaCell label="Investment" value={detail.investmentId || '—'} isDark={isDark} mono />
      </div>

      {(showSummaryBlock || sections.length > 0) && (
        <div className="space-y-3">
          <p className={clsx('text-xs font-medium uppercase tracking-wide', adminCaption(isDark))}>
            Belegangaben (Buchhaltung)
          </p>
          {showSummaryBlock && (
            <pre
              className={clsx(
                'max-h-[32rem] overflow-auto rounded-lg border p-4 text-sm whitespace-pre-wrap font-sans leading-relaxed',
                isDark ? 'border-slate-600 bg-slate-900 text-slate-200' : 'border-gray-200 bg-gray-100 text-gray-800',
              )}
            >
              {summaryText}
            </pre>
          )}
          {sections.map((sec) => (
            <SectionGrid key={sec.title} section={sec} isDark={isDark} />
          ))}
        </div>
      )}
      {!showSummaryBlock && sections.length === 0 && (
        <p className={clsx('text-sm', tableBodyCellMutedClasses(isDark))}>
          Keine strukturierten Beleginhalte — nur Dateiname: {detail.name}
        </p>
      )}

      {isPlaceholder && (
        <p className={clsx('text-xs', adminMuted(isDark))}>
          Kein PDF-Download: interner Beleg mit Buchungstext (wie in der iOS-App).
        </p>
      )}

      <details className={clsx('text-xs', adminMuted(isDark))}>
        <summary className="cursor-pointer">Technische Referenz</summary>
        <p className="mt-2 font-mono break-all">objectId: {detail.objectId}</p>
        <p className="font-mono break-all">fileURL: {detail.fileURL || '—'}</p>
      </details>
    </div>
  );
}

function MetaCell({
  label,
  value,
  isDark,
  mono = false,
}: {
  label: string;
  value: string;
  isDark: boolean;
  mono?: boolean;
}): JSX.Element {
  return (
    <div>
      <p className={clsx('text-xs', adminCaption(isDark))}>{label}</p>
      <p className={clsx('text-sm font-medium', mono && 'font-mono text-xs break-all', adminPrimary(isDark))}>
        {value}
      </p>
    </div>
  );
}
