---
filePatterns:
  - "admin-portal/**/*.ts"
  - "admin-portal/**/*.tsx"
  - "admin-portal/**/*.css"
  - "admin-portal/eslint.config.js"
---

# Admin Portal - React/TypeScript Standards

Architecture and coding standards for the FIN1 Admin Web Portal (`admin-portal/`).

## Deployment

| Environment | URL |
|-------------|-----|
| Production (HTTPS, HTTP→Redirect) | `https://192.168.178.24/admin/` |
| Local Dev | `http://localhost:3000/` |

**Note:** Self-signed SSL certificate requires browser exception for HTTPS.

### Portal login (Admin + Finance Admin)

- **One URL, one flow:** `Login.tsx` + `AuthContext` — technical admin (`admin`) and Finance Admin (`business_admin`) use the **same** page and the same `login()` path; CSR uses the same entry then redirects to `/csr`.
- **Copy & dev reference:** `src/constants/portalLogin.ts` and `src/components/DevPortalLoginReference.tsx` (Vite `import.meta.env.DEV` only). Keeps Finance Admin visibility aligned with `scripts/create-business-admin.sh` without branching auth logic.
- **Dev passwords (table):** `Documentation/DEV_LOGIN_ACCOUNTS.md` — canonical `finance@fin1.de` / `Finance2026!` and all other test accounts.

### Login troubleshooting (Admin-Portal)

- **Application ID:** Parse REST erwartet typischerweise `fin1-app-id` (nicht `fin1`); siehe `admin-portal` Build-Env / `WEB_PANEL_LOGIN_CREDENTIALS.md`.
- **„Invalid username/password“:** Live-Passwort kann von Script-/Doku-Defaults abweichen; auf dem Server `createAdminUser` mit `forcePasswordReset: true` und Rolle `business_admin` bzw. `admin` ausführen (Master-Key).
- **Temporäre Sperre:** Nach mehreren Fehlversuchen meldet Parse Lockout (~5 Minuten bei Standard `accountLockout` in `backend/parse-server/index.js`). **Sofort:** Nach Deploy Cloud-Code `unlockParseAccountLockout` (Master-Key) oder `createAdminUser` mit `forcePasswordReset` — beides hebt die Parse-Lockout-Felder auf (`usersAdminAccounts.js`). Siehe `WEB_PANEL_LOGIN_CREDENTIALS.md`.
- **2FA:** Backend akzeptiert 6-stelliges TOTP und 8-stellige Backup-Codes; im Portal beide Wege nutzen (Backup-Modus in `TwoFactorVerify`).

## User management (Benutzer)

- **Liste:** `src/pages/Users/UserList.tsx` → Cloud Function `searchUsers`.
- **Detail:** `src/pages/Users/UserDetail.tsx`, Route `/users/:userId` (Parse `objectId`) → `getUserDetails`. Enthält u. a. Stammdaten, optional Kontostand (`Wallet`-Datensatz), rollenabhängig **Trading- bzw. Investment-Übersicht** (`UserTradeCard`, `InvestmentTable`) und **Kontoauszug** (`AccountStatementCard`, `AccountStatement` für `user:<email>`), letzte `AuditLog`-Einträge. Spezifikation: `Documentation/FIN1_APP_DOCS/10_ADMIN_PORTAL_REQUIREMENTS.md` — Abschnitt **Benutzer-Detailseite** inkl. Unterabschnitte **Trading- und Investment-Übersicht** und **Kontoauszug**.

## Technology Stack

- **Framework**: React 18+ with TypeScript
- **Build Tool**: Vite
- **Styling**: TailwindCSS with FIN1 brand colors
- **State Management**: TanStack Query (React Query) for server state
- **Routing**: React Router v6
- **API**: Direct REST calls to Parse Server (no Parse SDK due to Vite compatibility)

## Architecture Patterns

### Component Structure

```
admin-portal/
├── eslint.config.js   # ESLint 9 Flat Config
├── vitest.config.ts
├── src/
│   ├── api/           # API layer (Parse REST calls)
│   ├── components/    # Reusable UI components
│   │   └── ui/        # Base UI components (Button, Card, Input, Badge)
│   ├── context/       # React Context providers (Auth, Theme, etc.)
│   ├── csr-portal/    # CSR layout + CSR route shell (/admin/csr/*)
│   ├── hooks/         # Custom React hooks (usePermissions, etc.)
│   ├── i18n/          # Internationalization (German-first)
│   ├── pages/         # Page components (one folder per feature)
│   │   ├── Users/
│   │   ├── KYBReview/ # Firmen-KYB (geteilt Admin + CSR Lesemodus)
│   │   ├── CSR/       # CSR Web Panel pages
│   │   ├── Finance/
│   │   │   ├── FinanceDashboard.tsx   # Main page (< 400 lines)
│   │   │   ├── components/            # Page-specific components
│   │   │   ├── types.ts               # TypeScript interfaces
│   │   │   ├── mockData.ts            # Mock data for development
│   │   │   └── index.ts               # Exports
│   │   └── ...
│   ├── test/          # Vitest setup + test-utils (ThemeProvider, MemoryRouter)
│   └── utils/         # Utility functions (formatting, etc.)
```

### Page Organization Pattern

**REQUIRED**: Large pages must be split into smaller files:

```
pages/Feature/
├── FeaturePage.tsx      # Main page, max 400 lines
├── components/          # Sub-components
│   ├── StatCard.tsx
│   ├── DataTable.tsx
│   └── Modal.tsx
├── types.ts             # Interfaces & types
├── mockData.ts          # Development mock data
├── utils.ts             # Feature-specific utilities
└── index.ts             # Re-exports
```

### API Layer Pattern

**REQUIRED**: All Parse Server communication via `src/api/parse.ts`:

```typescript
// ✅ CORRECT: Centralized API calls
import { cloudFunction } from '../api/parse';
const result = await cloudFunction<ResponseType>('functionName', params);

// ❌ FORBIDDEN: Direct fetch calls in components
fetch('/parse/functions/...')
```

### Authentication Pattern

**REQUIRED**: Use `AuthContext` for all auth state:

```typescript
// ✅ CORRECT: Use auth hook
const { user, permissions, hasPermission, logout } = useAuth();

// ❌ FORBIDDEN: Direct localStorage access for auth
localStorage.getItem('sessionToken')
```

### Permission Checks

**REQUIRED**: Check permissions before rendering sensitive UI:

```typescript
// ✅ CORRECT: Permission-based rendering (keys match backend, see permissions/constants.js)
{hasPermission('updateTicket') && <EditButton />}

// ❌ FORBIDDEN: Hardcoded role checks for capability UI
{user.role === 'admin' && <EditButton />}
```

## Coding Standards

### TypeScript

- **REQUIRED**: Strict TypeScript (`strict: true` in tsconfig)
- **REQUIRED**: Explicit return types for functions
- **REQUIRED**: Interface over type for object shapes
- **FORBIDDEN**: `any` type (use `unknown` if truly unknown)
- **FORBIDDEN**: Non-null assertions (`!`) without justification

```typescript
// ✅ CORRECT
interface User {
  objectId: string;
  email: string;
  role: string;
}

async function getUser(id: string): Promise<User> {
  // ...
}

// ❌ FORBIDDEN
const user: any = await getUser(id);
const email = user!.email;
```

### React Components

- **REQUIRED**: Functional components with hooks
- **REQUIRED**: Named exports (not default exports)
- **FORBIDDEN**: Class components
- **FORBIDDEN**: Inline styles (use TailwindCSS)

```typescript
// ✅ CORRECT
export function UserListPage() {
  const { data, isLoading } = useQuery({ ... });
  return <div className="p-4">...</div>;
}

// ❌ FORBIDDEN
export default class UserList extends React.Component { ... }
```

### State Management

- **Server State**: TanStack Query (`useQuery`, `useMutation`)
- **UI State**: React `useState`
- **Shared State**: React Context

```typescript
// ✅ CORRECT: Server state with React Query
const { data, isLoading, error } = useQuery({
  queryKey: ['users', filters],
  queryFn: () => searchUsers(filters),
});

// ❌ FORBIDDEN: Manual fetch with useState for server data
const [users, setUsers] = useState([]);
useEffect(() => { fetch(...).then(setUsers); }, []);
```

### Error Handling

**REQUIRED**: Consistent error display:

```typescript
// ✅ CORRECT
if (error) {
  return <ErrorMessage error={error} />;
}

// ❌ FORBIDDEN: Swallowing errors
catch (e) { /* ignore */ }
```

## Styling Guidelines

### TailwindCSS

- **REQUIRED**: Use Tailwind utility classes
- **REQUIRED**: Use FIN1 brand colors (`fin1-primary`, `fin1-secondary`, etc.)
- **FORBIDDEN**: Custom CSS files for component styling
- **FORBIDDEN**: Inline `style` props

```tsx
// ✅ CORRECT
<button className="bg-fin1-primary text-white px-4 py-2 rounded-lg">

// ❌ FORBIDDEN
<button style={{ backgroundColor: '#1a5f7a' }}>
```

### Responsive Design

**REQUIRED**: Mobile-first responsive design:

```tsx
// ✅ CORRECT: Mobile-first with breakpoints
<div className="flex flex-col sm:flex-row gap-4">

// ❌ FORBIDDEN: Desktop-only layouts
<div className="flex flex-row gap-4">
```

## Internationalization (i18n)

**RECOMMENDED**: German-first, prefer text in `src/i18n/de.ts`:

```typescript
// ✅ PREFERRED: Use translation keys for reusable text
import { t } from '../i18n/de';
<h1>{t('users.title')}</h1>

// ✅ ACCEPTABLE: Inline German for page-specific text
<h1>Benutzerverwaltung</h1>

// ❌ AVOID: Mixing languages
<button>Submit</button>  // Should be "Absenden"
```

**When to use i18n keys:**
- Repeated text (buttons, labels, errors)
- Status values (active, pending, etc.)
- Navigation items

**When inline text is OK:**
- Page titles (if not repeated)
- Context-specific help text
- Error messages with dynamic content

## File Size Limits

| File Type | Max Lines |
|-----------|-----------|
| Components | 300 |
| Pages | 400 |
| Hooks | 100 |
| Utils | 200 |
| API functions | 200 |

## Naming Conventions

- **Files**: `PascalCase.tsx` for components, `camelCase.ts` for utils
- **Components**: `PascalCase`
- **Hooks**: `useCamelCase`
- **Functions**: `camelCase`
- **Constants**: `UPPER_SNAKE_CASE`
- **Interfaces**: `PascalCase` (no `I` prefix)

### Domain wording: App vs Platform (tax mode UI)

- **REQUIRED**: In Admin-Portal UI copy and frontend identifiers, prefer **`App`** wording over **`Platform`** for tax-mode labels.
- **REQUIRED**: Use centralized branding constants from `src/constants/branding.ts` (for example `APP_WITHHOLDS_LABEL`) instead of inline strings.
- **REQUIRED**: Treat **`legalAppName`** as the canonical configurable **App Name** for `{{APP_NAME}}` hydration; manage it under **Configuration** (4-eyes), not as a primary editor under **AGB & Rechtstexte**.
- **ALLOWED (compatibility only)**: Persisted backend enum value `platform_withholds` remains unchanged for API/DB compatibility.
- **FORBIDDEN**: Introducing new frontend constants/labels with `PLATFORM_*` naming for this domain.

## Security Requirements

- **REQUIRED**: Session token stored in `localStorage` (not cookies for SPA)
- **REQUIRED**: All API calls include session token header
- **REQUIRED**: Logout clears all local storage
- **REQUIRED**: 2FA verification for elevated roles
- **FORBIDDEN**: Storing passwords or sensitive data in localStorage
- **FORBIDDEN**: Console logging of tokens or passwords

## Lint (ESLint 9)

- **Config:** `eslint.config.js` (Flat Config: `@eslint/js`, `typescript-eslint`, `eslint-plugin-react-hooks`, `eslint-plugin-react-refresh`).
- **Run:** `npm run lint` (must exit  zero before merge if CI is green).
- **CI:** GitHub Actions job `admin-portal` runs `npm ci` → `npm run lint` → `npm run test:run` → `npm run build`.

## Testing

### Unit Tests (Vitest)

```bash
npm run test        # Watch mode
npm run test:run    # Single run (CI)
npm run test:coverage
```

**Conventions:**
- Tests: `*.test.ts` / `*.test.tsx`, colocated under `src/`.
- Mock Parse/HTTP with `vi.mock` as needed.

### Component tests (React Testing Library)

**REQUIRED for UI that uses `useTheme()` or `Link`:** import `render` (and helpers) from `src/test/test-utils.tsx`, not raw `@testing-library/react`, so `ThemeProvider` and `MemoryRouter` wrap the tree.

```typescript
import { render, screen } from '../../test/test-utils';
import { UserListPage } from './UserList';

test('displays loading state', () => {
  render(<UserListPage />);
  expect(screen.getByText(/laden/i)).toBeInTheDocument();
});
```

`renderHook` may still come from `@testing-library/react` when no Theme/Router is needed.

### E2E Tests (Playwright) - Future

For critical user flows like login, user management, approvals.

## Build & Deployment

```bash
# Development
npm run dev

# Production build (runs tsc + vite build; postbuild syncs dist → ../admin/)
npm run build

# Preview production build
npm run preview

# Build + rsync to production host (see deploy.sh in admin-portal/)
npm run deploy
```

### Production static files (avoid stale bundles)

- **Served path:** Nginx `location /admin` serves the directory that receives the built assets (e.g. on the server `~/fin1-server/admin/`, often mirrored to `/var/www/admin`). **Do not assume** `~/fin1-server/admin-portal/dist/` is what users load.
- **After every deploy:** Confirm the **hashed** main bundle in `dist/index.html` matches what the server returns, e.g. `curl -sk https://<host>/admin/ | grep 'index-'` vs local `dist/index.html`. If they differ, the UI is still running an old build (symptom: missing fixes, old sorting behaviour).
- **Browser cache:** Hashed JS/CSS use long cache headers; `index.html` should be `no-store`. Users who see wrong behaviour should hard-refresh; mismatched tabs can point at different deployments.

### Parse Cloud Functions: list sorting (`sortBy` / `sortOrder`)

- **Single entry point:** All cloud calls go through `cloudFunction()` in `src/api/parse.ts` (not ad-hoc `fetch` to `/parse/functions/...`).
- **Body contract:** When `sortOrder` is present, `cloudFunction` normalizes it to `'asc' | 'desc'` and also sets **`listSortOrder`** to the same value in the JSON body.
- **Why `listSortOrder`:** Parse Server merges cloud parameters as `Object.assign({}, req.body, req.query)` (query wins). A stray `?sortOrder=desc` can override the body; **`listSortOrder` is body-only** so ascending sorts stay correct.
- **Backend pairing:** `backend/parse-server/cloud/utils/applyQuerySort.js` — use `applyQuerySort(query, request.params || {}, { allowed: [...], defaultField })`. Direction comes from `resolveListSortOrder(request.params)` (prefers `listSortOrder`). Keep **`allowed`** in sync with the few sortable columns exposed in the UI (`SortableTh` / `SortChip`).
- **In-memory sorts:** Any server-side sort after `find()` (e.g. App Ledger) must use the same direction resolution (`resolveListSortOrder`) so behaviour matches DB-sorted lists.

### Dates returned by Parse REST

- Encoded form: `{ "__type": "Date", "iso": "<ISO string>" }`.
- **Use** `formatDate`, `formatDateTime`, `formatRelative` from `src/utils/format.ts`; `safeParseDate` accepts plain strings, `Date`, and Parse-encoded objects (`unknown`).

### Freigaben / Approvals (`/approvals`)

- Data from `getPendingApprovals` is loaded once per poll; **filters** (e.g. by request type or `metadata.parameterName` for configuration changes) are **client-side** unless a dedicated cloud parameter is added.
- Config parameter display names live next to the page logic (`PARAM_DISPLAY_NAMES` / `CONFIG_PARAM_TYPES` in `ApprovalsList.tsx`); keep aligned with backend configuration keys.

**CSR vs. Admin:** Full admin routes live under `App.tsx` (`/` …); CSR-only UI under `csr-portal/CSRApp.tsx` with base path `/csr`. Firmen-KYB: shared `KYBReviewPage` at `/kyb-review` (admin nav **KYB-Status**) and `/csr/kyb` (CSR sidebar **KYB-Status**); review/reset UI requires cloud permissions `reviewCompanyKyb` / `resetCompanyKyb`.

## Email Notifications

**REQUIRED**: Email notifications are handled server-side via Cloud Functions:

### Available Email Functions

- **Tickets**: Automatic notifications for new tickets, updates, and replies
- **4-Eyes Approvals**: Notifications to approvers when requests are created
- **Security Alerts**: Critical security events sent to security team
- **Password Reset**: Reset links sent via email

### Email Configuration

Email service uses **Brevo (formerly Sendinblue)** SMTP:
- Configured via environment variables in `docker-compose.yml`
- Templates in `backend/parse-server/cloud/utils/emailService.js`
- Cloud Functions in `backend/parse-server/cloud/functions/notifications.js`

### Testing Email

```bash
# Via Cloud Function (requires admin session)
curl -X POST 'http://localhost:1337/parse/functions/sendTestEmail' \
  -H 'X-Parse-Application-Id: fin1-app-id' \
  -H 'X-Parse-Session-Token: <session-token>' \
  -H 'Content-Type: application/json' \
  -d '{"to": "test@example.com"}'
```

## Pages Overview

| Route | Page | Purpose | Roles |
|-------|------|---------|-------|
| `/` | Dashboard | KPIs, Quick Actions | All |
| `/users` | Users | User Management | admin, customer_service |
| `/tickets` | Tickets | Support Tickets | customer_service, admin |
| `/compliance` | Compliance | Compliance Events | compliance, admin |
| `/finance` | Finance | Financial Dashboard | business_admin, admin |
| `/security` | Security | Sessions, Alerts | security_officer, admin |
| `/approvals` | Approvals | 4-Eyes: Freigaben erteilen, Eigene Anträge, Alle Anträge, Abgeschlossen; **Typ filtern** (Antragsart + Konfigurationsparameter); Antragsteller kann pending Antrag zurückziehen. Sidebar zeigt rotes Badge mit Anzahl offener Anträge (requests + ownPending). | compliance, admin, business_admin |
| `/kyb-review` | KYB-Status | Firmen-KYB Einreichungen (Tabs, Detail, ggf. Entscheid/Reset mit Rechten) | business_admin, compliance (+ Nav sichtbar gemäß `reviewCompanyKyb`) |
| `/audit` | Audit | Audit Logs | compliance, admin |
| `/configuration` | Configuration | System Parameters | admin |
| `/system` | System | Server Health | admin, security_officer |
| `/settings` | Settings | User Settings, 2FA | All |

**CSR Web (base `/csr` after login at `/csr/login`):** u. a. `/csr/kyc` (KYC-Übersicht), `/csr/kyb` (KYB-Übersicht, Lesen für `customer_service`). Siehe `Documentation/FIN1_APP_DOCS/10_ADMIN_PORTAL_REQUIREMENTS.md` §10.

## Related Documentation

- `Documentation/FIN1_APP_DOCS/10_ADMIN_PORTAL_REQUIREMENTS.md` - Feature requirements
- `Documentation/FIN1_APP_DOCS/09_ADMIN_ROLES_SEPARATION.md` - Role definitions
- `Documentation/FIN1_APP_DOCS/03_TECHNISCHE_SPEZIFIKATION.md` - 4-Eyes Configuration Workflow
- `backend/parse-server/cloud/utils/permissions/constants.js` - Backend permission matrix
- `backend/parse-server/cloud/functions/configuration.js` - Configuration Cloud Functions
- `backend/parse-server/cloud/utils/emailService.js` - Email service implementation
- `backend/parse-server/cloud/functions/notifications.js` - Email notification functions
