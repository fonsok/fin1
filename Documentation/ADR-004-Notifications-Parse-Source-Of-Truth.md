# ADR-004: Notifications — Parse as source of truth, paging, and bulk mark-read

## Status
**ACCEPTED** — Effective immediately

## Context
- FIN1 supports in-app notifications backed by Parse (`Notification` class) and shown in the iOS app.
- Mobile UX requires **immediate** state updates (mark-read) even if the network is slow or temporarily unavailable.
- Notification history can grow beyond a single REST page; hard limits risk missing older but relevant items.
- Multiple devices must converge: “Mark all read” must be synchronized to the backend to keep unread counters consistent.

## Decision

### 1. Backend is the source of truth (Parse `Notification`)
- Parse `Notification` objects are authoritative for persisted notifications.
- The client may keep local in-memory state for UX, but backend data is the durable source.

### 2. Read state is write-through locally, best-effort synced
- When a notification is marked read in the UI, the client updates local state immediately.
- The client then attempts a best-effort backend sync:
  - Single: Cloud Function `markNotificationRead`
  - Bulk: Cloud Function `markAllNotificationsRead`
- Backend is responsible for enforcing ownership and setting consistent fields (`isRead`, `readAt`).

### 3. Fetch uses cursor-based pagination (resource-saving)
- The iOS client fetches notifications ordered by `-createdAt` and paginates using a `createdAt < cursor` constraint.
- Fetch is bounded by:
  - `pageSize = 100`
  - `maxTotal = 500` (hard cap to prevent runaway network/battery usage)
- This is a deliberate trade-off: show recent + some history reliably, without turning app activation into a heavy sync job.

### 4. `readAt` is a first-class field on the client
- `AppNotification` carries `readAt` (optional) so “recently read” logic is time-based and consistent.
- Mapping rules:
  - If backend provides `readAt`, use it.
  - If backend only provides `isRead == true`, fall back to `createdAt` (legacy/partial data).

### 5. Release security: mock auth must not be usable
- Release builds must not authenticate via mock providers.
- Until a real production auth provider is wired, Release uses a fail-closed auth provider to prevent accidental mock login paths.

### 6. Optional: in-app document deep links (`metadata`)
- **Use case:** A persisted Parse `Notification` should open a specific **`Document`** row on tap (invoice, collection bill, monthly statement PDF entry, etc.), even when that document is **not** duplicated as a separate card in the Documents tab.
- **Client contract** (`NotificationMetadataActionResolver`):
  - Prefer `metadata.documentId` = Parse **`Document.objectId`**, **or**
  - `metadata.referenceType` = `document` (case-insensitive after trim) and `metadata.referenceId` = Parse **`Document.objectId`**.
- **Resolution:** `NotificationCardViewModel` calls `DocumentService.resolveDocumentForDeepLink(objectId:)` — local cache first, else `GET /classes/Document/{objectId}` via `DocumentAPIService.fetchDocument`, then presents `DocumentNavigationHelper.sheetView` (same routing/hydration as other entry points). Survey and ticket metadata keep higher priority when present.

## Rationale
- Cursor paging avoids `skip` performance pitfalls and is stable with `-createdAt` ordering.
- Write-through UX keeps the app responsive; best-effort sync keeps multi-device state convergent.
- Hard caps protect battery, bandwidth, and “app became active” responsiveness.
- Explicit `readAt` prevents UI logic from relying on placeholders.

## Consequences
- **Positive**: stable UX under poor network, predictable resource usage, backend-aligned read state.
- **Negative**: older notifications beyond `maxTotal` are intentionally not shown without an explicit “load more/archive” feature; adjust cap/UI if product needs full history.

## References
- iOS:
  - `FIN1/Shared/Services/NotificationAPIService.swift` (paging + Parse mapping)
  - `FIN1/Shared/Services/NotificationServiceProtocol.swift` (write-through + best-effort sync)
  - `FIN1/Shared/Services/NotificationMetadataActionResolver.swift` (survey / ticket / document routing)
  - `FIN1/Shared/Models/Notification.swift` (`AppNotification.readAt`)
- Backend:
  - `backend/parse-server/cloud/triggers/notification.js` (`markNotificationRead`, `markAllNotificationsRead`)
- Documentation:
  - `Documentation/PARSE_SERVER_INTEGRATION_PROGRESS.md`
  - [`Documentation/ADR-012-Partial-Sell-Metrics-Finance-Smoke-And-Ops.md`](ADR-012-Partial-Sell-Metrics-Finance-Smoke-And-Ops.md) — weitere **Parse-SSOT**- und **Admin-/Betriebs**-Doku (Finance-Smoke, System-Health)
  - Cursor rules: `.cursor/rules/architecture.md`, `.cursor/rules/documentation-checkpoints.md`

