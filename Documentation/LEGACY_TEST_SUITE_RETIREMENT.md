# Legacy Test Suite Retirement

## Context
- `FIN1Tests` was the original umbrella test target dating back to pre-DI architecture.
- After the architecture refactor (AppServices + strict MVVM/SwiftUI rules) those files were never updated and rely on:
  - Removed models (`PotReservation`, `PotSelectionStrategy`, `InvestorPortfolioViewModel`, etc.)
  - Old service singletons (`UserService.shared`, `TradingStatisticsService.shared`, …)
  - Deprecated APIs (`AuthenticationViewModel.signUp`, legacy `Investment` initialisers, etc.)
- Reintroducing those concepts just to keep the target compiling would violate current Cursor rules and risk masking regressions.

## Decision
- As of 2025‑11‑20 the `FIN1Tests` target is **retired**. The shared scheme `FIN1.xcscheme` no longer lists it under `<TestAction>`.
- We now rely on the maintained suites:
  - `FIN1InvestorTests` (investor flow + accounting)
  - `FIN1UITests` (UI smoke tests)

## Follow‑up
- When re‑introducing app‑wide regression tests, create a new target that uses the modern DI setup and current domain models instead of reviving `FIN1Tests`.



