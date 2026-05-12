import {
  PORTAL_DEV_PASSWORD_SOURCE,
  PORTAL_DEV_PORTAL_ACCOUNTS,
} from '../constants/portalLogin';

/**
 * Development-only quick reference: same login as production, explicit Finance vs Technical rows.
 */
export function DevPortalLoginReference() {
  if (!import.meta.env.DEV) {
    return null;
  }

  return (
    <div
      data-testid="dev-login-reference"
      className="mt-4 rounded-lg border border-dashed border-amber-200 bg-amber-50/90 p-3 text-left text-xs text-amber-950"
    >
      <p className="font-semibold text-amber-900 mb-2">Entwicklung: Portal-Zugänge</p>
      <table className="w-full border-collapse text-[11px]">
        <thead>
          <tr className="border-b border-amber-200 text-amber-800">
            <th className="py-1 pr-2 text-left font-medium">Rolle</th>
            <th className="py-1 pr-2 text-left font-medium">Parse</th>
            <th className="py-1 text-left font-medium">E-Mail</th>
          </tr>
        </thead>
        <tbody>
          {PORTAL_DEV_PORTAL_ACCOUNTS.map((row) => (
            <tr key={row.email} className="border-b border-amber-100/80 last:border-0">
              <td className="py-1.5 pr-2 align-top">{row.roleLabel}</td>
              <td className="py-1.5 pr-2 align-top font-mono text-[10px] text-amber-900/90">
                {row.parseRole}
              </td>
              <td className="py-1.5 align-top font-mono">{row.email}</td>
            </tr>
          ))}
        </tbody>
      </table>
      <p className="mt-2 text-[11px] text-amber-800/95 leading-snug">{PORTAL_DEV_PASSWORD_SOURCE}</p>
    </div>
  );
}
