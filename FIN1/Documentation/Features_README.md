# Feature-Based Architecture

This directory contains the feature-based organization of the app, following SwiftUI best practices and MVVM architecture.

## Structure Overview

```
Features/
├── Admin/                 # Admin-only functionality
│   ├── Models/           # AdminSummaryReport, RoundingDifference
│   ├── Services/         # RoundingDifferencesService
│   ├── ViewModels/       # 4 ViewModels
│   └── Views/            # Admin dashboard, settings, reports
├── Authentication/        # User authentication and signup
│   ├── Models/           # User, UserEnums, UserExtensions
│   ├── Services/         # UserService, UserValidation, RiskClassCalculation
│   ├── ViewModels/       # AuthenticationViewModel, LandingViewModel, etc.
│   └── Views/            # Login, SignUp (57 files), Landing
├── CustomerSupport/       # Customer support features
│   ├── Models/           # AuditModels, CustomerSupportModels
│   ├── Services/         # CustomerSupportService, AuditLoggingService
│   ├── ViewModels/       # CustomerSupportDashboardViewModel
│   └── Views/            # Support dashboard and components
├── Dashboard/             # Main dashboard functionality
│   ├── Models/           # AccountStatementEntry, DashboardRoute
│   ├── Services/         # DashboardService, DashboardDataLoader
│   ├── ViewModels/       # 7 ViewModels (Dashboard, AccountStatement, etc.)
│   └── Views/            # Dashboard, AccountStatement, components
├── Investor/              # Investor-specific features
│   ├── Models/           # Investment, PoolTradeParticipation
│   ├── Repositories/     # InvestmentRepositoryProtocol
│   ├── Services/         # 28 services (Investment, CollectionBill, etc.)
│   ├── ViewModels/       # 12 ViewModels
│   └── Views/            # Discovery, Portfolio, TraderDetail (50+ files)
└── Trader/                # Trader-specific features
    ├── Components/       # Search components
    ├── Helpers/          # Calculation helpers
    ├── Models/           # 31 models (Trade, Order, Invoice, etc.)
    ├── Services/         # 58 services (Trading, Orders, Invoices, etc.)
    ├── Utils/            # PDF, Downloads utilities
    ├── ViewModels/       # 21 ViewModels
    └── Views/            # 88 views (Trading, Depot, Securities, etc.)
```

## Feature Details

### Admin (8 files)
Administrative functionality for app management:
- **RoundingDifferencesService** - Tracks and resolves rounding differences
- **AdminSummaryReportViewModel** - Generates admin reports
- **ConfigurationSettingsViewModel** - App configuration management
- **BankContraLedgerViewModel** - Bank reconciliation

### Authentication (81 files)
Complete authentication and onboarding flow:
- **AuthenticationViewModel** - Login/logout coordination
- **SignUp/** - 57 files for multi-step registration
- **RiskClassCalculation** - Investor risk assessment
- **UserValidationService** - Input validation

### CustomerSupport (12 files)
Customer support dashboard and tools:
- **CustomerSupportService** - Support ticket management
- **AuditLoggingService** - Audit trail for compliance
- **CustomerSupportDashboardViewModel** - Support agent dashboard

### Dashboard (27 files)
Central dashboard for all user roles:
- **DashboardViewModel** - Main dashboard coordination
- **DashboardStatsViewModel** - Stats section logic
- **AccountStatementViewModel** - Account statement generation
- **MonthlyAccountStatementViewModel** - Monthly reports

### Investor (100 files)
Investor-specific trading and portfolio:
- **InvestorDiscoveryViewModel** - Trader discovery
- **InvestorPortfolioViewModel** - Portfolio management
- **InvestmentCompletionService** - Investment lifecycle
- **InvestorCollectionBillCalculationService** - Fee calculations
- **InvestorInvestmentStatementAggregator** - Statement generation

### Trader (213 files)
Complete trading functionality:
- **TraderTradingViewModel** - Trading operations
- **TraderDepotViewModel** - Depot management
- **OrderManagementService** - Order lifecycle
- **TradeLifecycleService** - Trade execution
- **InvoiceService** - Invoice generation
- **SecuritiesSearchService** - Securities search and filtering

## Architecture Principles

### MVVM Pattern ✅
Every feature follows strict MVVM:
```
View (UI only) → ViewModel (Business Logic) → Service (Data/Network)
```

### File Split Pattern (≤300) ✅
- Keep Swift files ideally at or below 300 lines.
- Prefer cohesive split by responsibility (Core + Extensions), not by arbitrary chunks.
- Recommended naming:
  - `FeatureType.swift` (core state/init/public surface)
  - `FeatureType+Loading.swift`
  - `FeatureType+Backend.swift`
  - `FeatureType+Computed.swift`
- Recent examples in this codebase:
  - `InvestmentsViewModel` split into loading/computed extensions
  - `InvestmentService` split into creation/status, completion, backend sync
  - `UserService` split into authentication, profile, admin, sync

### Dependency Injection ✅
All services injected via protocols:
```swift
init(userService: any UserServiceProtocol,
     investmentService: any InvestmentServiceProtocol)
```

### Protocol-Based Services ✅
Every service has a protocol for testability:
```swift
protocol InvestmentServiceProtocol {
    func getInvestments(for userId: String) -> [Investment]
}

final class InvestmentService: InvestmentServiceProtocol { ... }
```

### ResponsiveDesign ✅
All UI uses `ResponsiveDesign` for measurements:
```swift
.padding(ResponsiveDesign.current.padding.standard)
.font(ResponsiveDesign.current.fonts.body)
```

## File Counts by Feature

| Feature | Models | Services | ViewModels | Views | Total |
|---------|--------|----------|------------|-------|-------|
| Admin | 2 | 2 | 4 | 8 | 16 |
| Authentication | 3 | 6 | 6 | 66 | 81 |
| CustomerSupport | 3 | 5 | 1 | 3 | 12 |
| Dashboard | 3 | 3 | 7 | 14 | 27 |
| Investor | 4 | 29 | 12 | 55 | 100 |
| Trader | 31 | 58 | 21 | 103 | 213 |

## Benefits

- **Feature Isolation**: Each feature is self-contained with its own Models, Services, ViewModels, and Views
- **Clear Ownership**: Easy to identify where functionality lives
- **Scalability**: New features follow the same pattern
- **Team Collaboration**: Different teams can work on different features
- **Testing**: Feature-specific testing with mock services
- **Maintenance**: Changes are localized to specific features

## Adding a New Feature

1. Create feature folder: `Features/NewFeature/`
2. Add subdirectories: `Models/`, `Services/`, `ViewModels/`, `Views/`
3. Create service protocol: `NewFeatureServiceProtocol.swift`
4. Create service implementation: `NewFeatureService.swift`
5. Create ViewModel: `NewFeatureViewModel.swift`
6. Create Views
7. Register service in `AppServices`

---

**Last Updated**: January 2026
