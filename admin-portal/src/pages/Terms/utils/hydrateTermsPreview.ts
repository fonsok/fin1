export interface LegalBrandingPreviewValues {
  appName: string;
  platformName?: string;
}

function replaceTokenFlexible(haystack: string, token: string, replacement: string): string {
  if (!token) return haystack;
  // Supports:
  // - {{APP_NAME}}, {{ APP_NAME }}, {{app_name}}
  // - {(APP_NAME)}, {( APP_NAME )}, {(app_name)}
  const escaped = token.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
  const curly = new RegExp(`\\{\\{\\s*${escaped}\\s*\\}\\}`, 'gi');
  const paren = new RegExp(`\\{\\(\\s*${escaped}\\s*\\)\\}`, 'gi');
  return haystack.replace(curly, replacement).replace(paren, replacement);
}

/**
 * Admin-only preview helper: replaces common legal placeholders in *display* text.
 * Important: this must never be used to mutate persisted TermsContent on save.
 */
export function hydrateTermsPreviewText(
  input: string,
  values: LegalBrandingPreviewValues | null | undefined,
): string {
  if (!values) return input;
  const appName = (values.appName ?? '').trim();
  const platformName = (values.platformName ?? '').trim();

  let out = input;

  // Support both canonical {{TOKEN}} and legacy {(TOKEN)} placeholders.
  out = replaceTokenFlexible(out, 'APP_NAME', appName);

  // Optional: if older templates used PRODUCT_NAME as an alias.
  out = replaceTokenFlexible(out, 'PRODUCT_NAME', appName);

  // (We intentionally do NOT try to rewrite arbitrary legacy literals like "bbb".)

  if (platformName.length > 0) {
    out = replaceTokenFlexible(out, 'LEGAL_PLATFORM_NAME', platformName);
  }

  return out;
}
