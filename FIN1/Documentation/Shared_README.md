# Shared Components

This directory contains shared components, services, and utilities used across multiple features.

## Structure Overview

```
Shared/
├── Accounting/            # Financial accounting utilities
│   ├── BankContraAccountPosting.swift
│   ├── BankContraAccountPostingService.swift
│   └── TraderAccountStatementBuilder.swift
├── Components/            # Reusable UI components
│   ├── Common/           # General-purpose components
│   ├── DataDisplay/      # Data presentation (notifications, overlays)
│   ├── DataLoading/      # Pagination and lazy loading
│   ├── DataTable/        # Table components
│   ├── Forms/            # Input fields and form components
│   ├── ImageLoading/     # Optimized image views
│   ├── KYC/              # KYC compliance components
│   ├── Legal/            # Terms and legal modals
│   ├── Navigation/       # Navigation helpers and tab configuration
│   ├── Performance/      # Performance monitoring
│   ├── Profile/          # User profile components
│   ├── Search/           # Search and filter components
│   ├── Settings/         # Settings UI components
│   └── Watchlist/        # Watchlist UI components
├── Data/                  # Static data providers
│   ├── FAQDataProvider.swift
│   ├── PrivacyPolicyDataProvider.swift
│   └── TermsOfServiceDataProvider.swift
├── Extensions/            # Swift extensions
│   ├── Color+AppColors.swift
│   ├── Invoice+Calculations.swift
│   ├── Number+Formatting.swift
│   └── String+*.swift
├── Models/                # Shared data models
│   ├── AppError.swift
│   ├── CalculationConstants.swift
│   ├── Document.swift
│   ├── FilterData/       # Filter-related models
│   ├── KYCChangeRequest/ # KYC request models
│   ├── Mock*.swift       # Mock data for development
│   ├── Notification.swift
│   ├── OrderModels.swift
│   └── Settings/         # Settings models
├── Services/              # Shared services (44 files)
│   ├── AppServices.swift           # DI container
│   ├── AppServicesBuilder.swift    # Service factory
│   ├── CashBalanceService.swift
│   ├── CommissionCalculationService.swift
│   ├── ConfigurationService.swift
│   ├── DocumentService.swift
│   ├── EventBus.swift              # Event-driven communication
│   ├── FeeCalculationService.swift
│   ├── ServiceFactory.swift
│   ├── ServiceLifecycleCoordinator.swift
│   ├── ThemeManager.swift
│   ├── TransactionIdService.swift
│   └── [... and more service protocols]
├── Utilities/             # Utility classes
│   ├── DataFlowValidator.swift
│   ├── DocumentNamingUtility.swift
│   └── OrderCalculationUtility.swift
└── ViewModels/            # Shared ViewModels (12 files)
    ├── AddressChangeRequestViewModel.swift
    ├── ContactSupportViewModel.swift
    ├── EditProfileViewModel.swift
    ├── HelpCenterViewModel.swift
    ├── ModularProfileViewModel.swift
    ├── PrivacyPolicyViewModel.swift
    ├── TermsAcceptanceViewModel.swift
    └── TermsOfServiceViewModel.swift
```

## Key Components

### Services (Protocol-Based DI)

All services follow the protocol-based dependency injection pattern:

| Service | Protocol | Purpose |
|---------|----------|---------|
| `DocumentService` | `DocumentServiceProtocol` | Document handling and storage |
| `NotificationService` | `NotificationServiceProtocol` | Role-based notifications |
| `CashBalanceService` | `CashBalanceServiceProtocol` | Cash balance management |
| `ConfigurationService` | `ConfigurationServiceProtocol` | App configuration; wird im `ServiceLifecycleCoordinator` (critical) gestartet und synchronisiert finanzielle Parameter vom Server via `getConfig`. |
| `ThemeManager` | - | Theme and appearance |
| `TransactionIdService` | `TransactionIdServiceProtocol` | Transaction ID generation |

### AppServices (DI Container)

The `AppServices` struct is the composition root for dependency injection:

```swift
@Environment(\.appServices) private var services

// Access services
let user = services.userService.currentUser
let balance = services.cashBalanceService.getBalance()
```

### Components

#### DataTable Components
- Reusable table components for displaying tabular data
- Configurable headers, cells, and interactions
- Responsive design support

#### Profile Components
- User profile management (`ModularProfileView`)
- Settings and preferences
- Account information display
- KYC change requests

#### Navigation Components
- `MainTabView` - Role-based tab navigation
- `TabBarAppearanceConfigurator` - Tab bar styling
- Navigation helpers for documents and trading

#### DataLoading Components
- `PaginationCoordinator` - Pagination state management
- `PaginatedListView` - Lazy-loading list component
- `OptimizedDataLoader` - Performance-optimized loading

### Extensions

| Extension | Purpose |
|-----------|---------|
| `Color+AppColors` | App-wide color definitions |
| `Number+Formatting` | German number formatting |
| `Invoice+Calculations` | Invoice calculation helpers |
| `String+Bezeichnung` | Security description parsing |

### Utilities

| Utility | Purpose |
|---------|---------|
| `DataFlowValidator` | Validates data flow at critical points |
| `DocumentNamingUtility` | Consistent document naming |
| `OrderCalculationUtility` | Order calculation helpers |

## Usage

These shared components and services are imported and used by features via dependency injection:

```swift
// In a ViewModel
init(userService: any UserServiceProtocol,
     documentService: any DocumentServiceProtocol) {
    self.userService = userService
    self.documentService = documentService
}

// In a View
@Environment(\.appServices) private var services
```

## Architecture Notes

- **No Singletons**: Services are injected via `AppServices`, not accessed via `.shared`
- **Protocol-Based**: All services implement protocols for testability
- **MVVM Pattern**: ViewModels handle business logic, Views handle UI only
- **ResponsiveDesign**: All components use `ResponsiveDesign` for measurements

---

**Last Updated**: January 2026
