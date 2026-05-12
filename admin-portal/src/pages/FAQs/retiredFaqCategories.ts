const RETIRED_FAQ_CATEGORY_SLUGS = new Set(['investor_portfolio', 'trader_pools']);

export function isRetiredFaqCategorySlug(slug: string | undefined | null): boolean {
  return RETIRED_FAQ_CATEGORY_SLUGS.has((slug || '').toLowerCase());
}
