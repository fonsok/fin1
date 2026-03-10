// TermsContent (legal docs) types for admin panel

/** Human-readable labels for document types (Terms, Privacy, Imprint). */
export const DOCUMENT_TYPE_LABELS: Record<string, string> = {
  terms: 'AGB / Terms',
  privacy: 'Datenschutz',
  imprint: 'Impressum',
};

export interface TermsSection {
  id: string;
  title: string;
  content: string;
  icon: string;
}

export interface TermsContentListItem {
  objectId: string;
  version: string;
  language: string;
  documentType: string;
  effectiveDate: string | null;
  isActive: boolean;
  documentHash: string | null;
  sectionCount: number;
  createdAt: string | null;
  updatedAt: string | null;
}

export interface TermsContentFull extends TermsContentListItem {
  sections: TermsSection[];
}

export interface CreateTermsContentRequest {
  version: string;
  language: string;
  documentType: string;
  effectiveDate: string;
  isActive?: boolean;
  sections: TermsSection[];
}

export interface ListTermsContentResponse {
  items: TermsContentListItem[];
}

/** Eine Änderung zwischen zwei Versionen (für Admin-Anzeige). */
export type SectionChangeType = 'added' | 'removed' | 'modified';

export interface SectionChange {
  changeType: SectionChangeType;
  sectionId: string;
  sectionTitle: string;
  description?: string;
}

export interface VersionChangesResult {
  previousVersion: string;
  previousEffectiveDate: string | null;
  changes: SectionChange[];
}
