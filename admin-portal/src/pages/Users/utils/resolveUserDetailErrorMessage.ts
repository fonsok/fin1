export function resolveUserDetailErrorMessage(error: unknown, userId: string | undefined): string {
  if (!userId) {
    return 'Keine Benutzer-ID in der URL.';
  }

  if (error instanceof Error) {
    const message = error.message.trim();
    if (message) {
      const looksNotFound =
        /101|object not found|nicht gefunden/i.test(message) || /code\s*101/i.test(message);
      if (looksNotFound) {
        return `Benutzer nicht gefunden (${userId}).`;
      }
      return `Benutzerdetails konnten nicht geladen werden: ${message}`;
    }
  }

  return `Benutzer nicht gefunden (${userId}).`;
}
