export function getSeverityVariant(severity: string): 'success' | 'warning' | 'danger' | 'neutral' {
  switch (severity) {
    case 'low':
      return 'success';
    case 'medium':
      return 'warning';
    case 'high':
    case 'critical':
      return 'danger';
    default:
      return 'neutral';
  }
}
