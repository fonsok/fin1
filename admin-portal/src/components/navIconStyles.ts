/** Distinct icon accent per sidebar nav item (on fin1-primary background). */
export interface NavIconStyle {
  icon: string;
  bg: string;
}

export const NAV_ITEM_ICON_STYLES: Record<string, NavIconStyle> = {
  dashboard: { icon: 'text-sky-300', bg: 'bg-sky-400/25' },
  users: { icon: 'text-red-300', bg: 'bg-red-500/25' },
  tickets: { icon: 'text-amber-300', bg: 'bg-amber-400/25' },
  onboarding: { icon: 'text-emerald-300', bg: 'bg-emerald-400/25' },
  compliance: { icon: 'text-blue-300', bg: 'bg-blue-400/25' },
  finance: { icon: 'text-lime-300', bg: 'bg-lime-400/25' },
  security: { icon: 'text-rose-300', bg: 'bg-rose-400/25' },
  approvals: { icon: 'text-orange-300', bg: 'bg-orange-400/25' },
  'kyb-review': { icon: 'text-indigo-300', bg: 'bg-indigo-400/25' },
  audit: { icon: 'text-slate-200', bg: 'bg-slate-400/25' },
  templates: { icon: 'text-cyan-300', bg: 'bg-cyan-400/25' },
  faqs: { icon: 'text-teal-300', bg: 'bg-teal-400/25' },
  terms: { icon: 'text-slate-200', bg: 'bg-slate-400/25' },
  reports: { icon: 'text-amber-300', bg: 'bg-amber-400/25' },
  'document-search': { icon: 'text-yellow-300', bg: 'bg-yellow-400/25' },
  'app-ledger': { icon: 'text-green-300', bg: 'bg-green-400/25' },
  configuration: { icon: 'text-red-300', bg: 'bg-red-500/25' },
  system: { icon: 'text-stone-200', bg: 'bg-stone-400/25' },
  settings: { icon: 'text-slate-200', bg: 'bg-slate-400/25' },
};

export function getNavIconStyle(itemId: string): NavIconStyle {
  return NAV_ITEM_ICON_STYLES[itemId] ?? { icon: 'text-white/80', bg: 'bg-white/15' };
}
