# ADR-006: Server-Owned Return Percentage Contract

## Status
Accepted

## Date
2026-04-20

## Context
Return percentage drift occurred when different clients computed return values from different denominators or fallback paths. For accounting-sensitive displays, this violates single-source-of-truth principles and increases reconciliation risk.

## Decision
1. Backend is the canonical owner of investor return percentage.
2. Each active investor collection bill document must include `metadata.returnPercentage`.
3. Clients must consume backend `metadata.returnPercentage` and must not derive return percentage locally.
4. If backend return percentage is unavailable, clients show explicit `pending` instead of local computation.
5. Settlement flow enforces an invariant: creating a collection bill without canonical return percentage is rejected.

## Contract
- Field: `Document.metadata.returnPercentage`
- Scope: documents with type `investorCollectionBill` / `investor_collection_bill` (excluding wallet receipt variants)
- Type: number (percentage, e.g. `37.38`)
- Required: yes, for active investor collection bill documents

## Operational Guardrails
- Daily monitor check: `backend/scripts/monitor-collection-bill-return-percentage.js`
- Admin cloud audit endpoint: `auditCollectionBillReturnPercentage`
- Regression test fixture: backend accounting helper test includes known expected return percentage

## Consequences
- Positive:
  - Consistent return display across investor/admin/customer-support surfaces
  - Better auditability and reduced accounting drift
- Trade-offs:
  - Stricter dependency on backend data readiness
  - Legacy malformed data must be migrated/archived to keep monitoring healthy
