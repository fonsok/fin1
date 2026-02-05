---
filePatterns:
  - "admin-portal/**/*.ts"
  - "admin-portal/**/*.tsx"
  - "admin-portal/**/*.css"
---

# Admin Portal - React/TypeScript Standards

Architecture and coding standards for the FIN1 Admin Web Portal (`admin-portal/`).

## Deployment

| Environment | URL |
|-------------|-----|
| Production (HTTPS) | `https://192.168.178.24/admin/` |
| Production (HTTP) | `http://192.168.178.24/admin/` |
| Local Dev | `http://localhost:3000/` |

**Note:** Self-signed SSL certificate requires browser exception for HTTPS.

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
├── src/
│   ├── api/           # API layer (Parse REST calls)
│   ├── components/    # Reusable UI components
│   │   └── ui/        # Base UI components (Button, Card, Input, Badge)
│   ├── context/       # React Context providers (Auth, etc.)
│   ├── hooks/         # Custom React hooks
│   ├── i18n/          # Internationalization (German-first)
│   ├── pages/         # Page components (one folder per feature)
│   │   ├── Users/
│   │   ├── Finance/
│   │   │   ├── FinanceDashboard.tsx   # Main page (< 400 lines)
│   │   │   ├── components/            # Page-specific components
│   │   │   ├── types.ts               # TypeScript interfaces
│   │   │   ├── mockData.ts            # Mock data for development
│   │   │   └── index.ts               # Exports
│   │   └── ...
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
// ✅ CORRECT: Permission-based rendering
{hasPermission('users:write') && <EditButton />}

// ❌ FORBIDDEN: Hardcoded role checks
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

## Security Requirements

- **REQUIRED**: Session token stored in `localStorage` (not cookies for SPA)
- **REQUIRED**: All API calls include session token header
- **REQUIRED**: Logout clears all local storage
- **REQUIRED**: 2FA verification for elevated roles
- **FORBIDDEN**: Storing passwords or sensitive data in localStorage
- **FORBIDDEN**: Console logging of tokens or passwords

## Testing

### Unit Tests (Vitest)

```bash
# Run tests
npm run test

# Watch mode
npm run test:watch
```

**Test patterns:**
- Test files: `*.test.ts` or `*.test.tsx`
- Location: Same folder as source file
- Mock API calls with `vi.mock('../api/parse')`

### Component Tests (React Testing Library)

```typescript
import { render, screen } from '@testing-library/react';
import { UserListPage } from './UserList';

test('displays loading state', () => {
  render(<UserListPage />);
  expect(screen.getByText(/laden/i)).toBeInTheDocument();
});
```

### E2E Tests (Playwright) - Future

For critical user flows like login, user management, approvals.

## Build & Deployment

```bash
# Development
npm run dev

# Production build
npm run build

# Preview production build
npm run preview
```

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
| `/approvals` | Approvals | 4-Eyes Workflow | compliance, admin |
| `/audit` | Audit | Audit Logs | compliance, admin |
| `/configuration` | Configuration | System Parameters | admin |
| `/system` | System | Server Health | admin, security_officer |
| `/settings` | Settings | User Settings, 2FA | All |

## Related Documentation

- `Documentation/FIN1_APP_DOCS/10_ADMIN_PORTAL_REQUIREMENTS.md` - Feature requirements
- `Documentation/FIN1_APP_DOCS/09_ADMIN_ROLES_SEPARATION.md` - Role definitions
- `Documentation/FIN1_APP_DOCS/03_TECHNISCHE_SPEZIFIKATION.md` - 4-Eyes Configuration Workflow
- `backend/parse-server/cloud/utils/permissions.js` - Backend permissions
- `backend/parse-server/cloud/functions/configuration.js` - Configuration Cloud Functions
- `backend/parse-server/cloud/utils/emailService.js` - Email service implementation
- `backend/parse-server/cloud/functions/notifications.js` - Email notification functions
