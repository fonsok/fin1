// FAQ Types

export interface FAQ {
  objectId: string;
  faqId: string;
  question: string;
  /** Optional English question (canonical Parse field). */
  questionEn?: string;
  answer: string;
  /** Optional English answer (canonical Parse field). */
  answerEn?: string;
  /** @deprecated Legacy misnamed field (stored English); still accepted on import until migrated. */
  questionDe?: string;
  /** @deprecated Legacy misnamed field (stored English); still accepted on import until migrated. */
  answerDe?: string;
  // Legacy single category (kept for backwards compatibility)
  categoryId: string;
  // New: support assigning an FAQ to multiple categories
  categoryIds?: string[];
  sortOrder: number;
  isPublished: boolean;
  isArchived: boolean;
  isPublic: boolean;
  isUserVisible: boolean;
  // Legacy single context/source tag
  source?: string;
  // New: multiple logical contexts for a single FAQ (e.g. help_center + landing + investor)
  contexts?: string[];
  createdAt?: string;
  updatedAt?: string;
}

export interface FAQCategory {
  objectId: string;
  slug: string;
  title?: string;
  displayName?: string;
  icon?: string;
  sortOrder: number;
  isActive: boolean;
  showOnLanding: boolean;
  showInHelpCenter: boolean;
  showInCSR: boolean;
}

export interface CreateFAQRequest {
  faqId?: string;
  question: string;
  questionEn?: string;
  answer: string;
  answerEn?: string;
  // Primary category for backwards compatibility
  categoryId: string;
  // Full set of assigned categories
  categoryIds?: string[];
  sortOrder?: number;
  isPublished?: boolean;
  isPublic?: boolean;
  isUserVisible?: boolean;
  // Primary context/source for backwards compatibility
  source?: string;
  // Full set of assigned contexts
  contexts?: string[];
}

export interface UpdateFAQRequest {
  question?: string;
  questionEn?: string;
  answer?: string;
  answerEn?: string;
  categoryId?: string;
  categoryIds?: string[];
  sortOrder?: number;
  isPublished?: boolean;
  isArchived?: boolean;
  isPublic?: boolean;
  isUserVisible?: boolean;
  source?: string;
  contexts?: string[];
}

export interface FAQListResponse {
  faqs: FAQ[];
}

export interface FAQCategoriesResponse {
  categories: FAQCategory[];
}

export interface CreateFAQCategoryRequest {
  slug: string;
  title?: string;
  displayName?: string;
  icon?: string;
  sortOrder?: number;
  isActive?: boolean;
  showOnLanding?: boolean;
  showInHelpCenter?: boolean;
  showInCSR?: boolean;
}
