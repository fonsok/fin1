const APP_NAME_PLACEHOLDER = '{{APP_NAME}}';

export const APP_NAME = import.meta.env.VITE_APP_NAME || APP_NAME_PLACEHOLDER;

function normalizeAppName(value: unknown): string {
  if (typeof value !== 'string') return APP_NAME;
  const trimmed = value.trim();
  return trimmed.length > 0 ? trimmed : APP_NAME;
}

export function getAppName(config?: Record<string, number | string | boolean>): string {
  return normalizeAppName(config?.legalAppName ?? config?.appName);
}

// Naming guard: use APP wording in frontend labels; keep backend enum value
// "platform_withholds" only for API/DB compatibility.
export function getAppWithholdsLabel(config?: Record<string, number | string | boolean>): string {
  return `${getAppName(config)} führt automatisch ab`;
}
