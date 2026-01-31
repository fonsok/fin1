# Investment Pool Platform (App Name Configurable)

A modern, native Swift implementation of an investment pool platform that connects investors and traders, built with SwiftUI and following iOS best practices.

## 🎯 Overview

This app enables:
- **Investors** to discover and invest in professional traders
- **Traders** to manage investment pools and execute trades
- **Proportional profit/loss sharing** among all participants
- **Secure authentication** with biometric support
- **Real-time portfolio tracking** and performance monitoring

## ✨ Features

### Core Functionality
- **Multi-step registration** with KYC compliance
- **Role-based user experience** (Investor/Trader)
- **Investment pool management** with n-trade execution
- **Real-time portfolio tracking** and performance metrics
- **Secure authentication** with Face ID/Touch ID support
- **Push notifications** for important events

### Investor Features
- **Trader discovery** with performance metrics
- **Investment creation** with customizable parameters
- **Portfolio overview** with active investments
- **Performance tracking** and profit distribution
- **Watchlist and favorites** system

### Trader Features
- **Trading dashboard** with current pot overview
- **Trade execution** and management
- **Position tracking** and P&L monitoring
- **Performance analytics** and risk metrics
- **Investor fund management**

### Customer Support Features
- **Support ticket system** with user self-service and CSR management
- **FAQ knowledge base** with articles derived from resolved tickets
- **Customer search and profile** access with audit logging
- **Ticket assignment and escalation** with automatic routing
- **Satisfaction surveys** and feedback collection
- **Agent performance dashboard** with metrics and analytics
- **Email template management** for standardized responses
- **RBAC (Role-Based Access Control)** with granular permissions

### Admin Features
- **Admin summary reports** aggregating investments and trades
- **Rounding differences management** for financial reconciliation
- **Configuration management** for app settings and parameters
- **Bank contra ledger** for bank reconciliation
- **Financial settings** and app settings management

## 🛠 Technical Stack

- **Platform:** iOS 16.0+
- **Language:** Swift 5.9+
- **UI Framework:** SwiftUI
- **Architecture:** MVVM + Service Layer + Dependency Injection
- **State Management:** Combine + @StateObject
- **Authentication:** LocalAuthentication (Face ID/Touch ID)
- **Design System:** Custom color palette with SF Symbols + ResponsiveDesign system
- **Backend:** Parse Server (self-hosted)
- **Network Tools:** nmap, netcat, mtr for diagnostics

## 🏗 Project Structure

```
FIN1/
├── Documentation/                # Root-level documentation (24 files)
│   ├── ARCHITECTURE_GUARDRAILS.md
│   ├── NETWORK_TOOLS.md         # Network tools & scripts
│   ├── MAC_DEVELOPMENT_OPTIMIZATION.md
│   └── ...                      # See Documentation/README.md
├── FIN1/
│   ├── Assets.xcassets/          # Color assets and app icons
│   ├── Features/                 # Feature-based modules
│   │   ├── Authentication/       # Auth feature
│   │   │   ├── Models/          # User, UserEnums, UserExtensions
│   │   │   ├── Services/        # UserServiceProtocol
│   │   │   ├── ViewModels/      # AuthenticationViewModel
│   │   │   └── Views/           # Login, SignUp, Landing views
│   │   ├── Dashboard/           # Dashboard feature
│   │   │   ├── Models/          # DashboardActivity, DashboardStats
│   │   │   ├── Services/        # DashboardService, DashboardServiceProtocol
│   │   │   ├── ViewModels/      # DashboardViewModel
│   │   │   └── Views/           # DashboardView, Components
│   │   ├── Investor/            # Investor feature
│   │   │   ├── Models/          # Investment
│   │   │   ├── Services/        # InvestmentServiceProtocol
│   │   │   ├── ViewModels/      # InvestorPortfolioViewModel
│   │   │   └── Views/           # Investor-specific views
│   │   ├── Trader/              # Trader feature
│   │   │   ├── Models/          # Trade, Order, TradingStats
│   │   │   ├── Services/        # TraderService, TraderServiceProtocol
│   │   │   ├── ViewModels/      # TraderTradingViewModel
│   │   │   └── Views/           # Trader-specific views
│   │   ├── CustomerSupport/    # Customer support feature
│   │   │   ├── Models/          # SupportTicket, FAQArticle, CSRAgent
│   │   │   ├── Services/        # CustomerSupportService, FAQKnowledgeBaseService
│   │   │   ├── ViewModels/      # CustomerSupportDashboardViewModel
│   │   │   └── Views/           # Support dashboard, ticket management
│   │   └── Admin/               # Admin feature
│   │       ├── Models/          # AdminSummaryReport, RoundingDifference
│   │       ├── Services/        # RoundingDifferencesService
│   │       ├── ViewModels/      # AdminSummaryReportViewModel
│   │       └── Views/           # Admin dashboard, reports, settings
│   ├── Documentation/           # Feature-level documentation (49 files)
│   │   └── ...                  # Feature-specific docs, code reviews
│   ├── Shared/                   # Shared components and services
│   │   ├── Components/          # Reusable UI components
│   │   ├── Extensions/          # Color+AppColors, etc.
│   │   ├── Models/              # AppError, Document, Notification, MockData
│   │   ├── Services/            # Shared service protocols
│   │   └── ViewModels/          # Shared ViewModels (WatchlistViewModel)
│   ├── ContentView.swift        # Legacy view (can be removed)
│   └── FIN1App.swift           # Main app entry point + DI container
├── FIN1Tests/                    # Unit tests
├── FIN1UITests/                  # UI tests
├── scripts/                      # Development scripts
│   ├── network/                 # Network-related scripts
│   │   ├── health-check-backend.sh
│   │   ├── network-tuning.sh
│   │   └── README.md
│   ├── caffeinate-build.sh
│   ├── check-file-sizes.sh
│   └── ...                      # See scripts/README.md
└── README.md                     # This file
```

## 🚀 Getting Started

### Prerequisites
- Xcode 15.0+
- iOS 16.0+ deployment target
- macOS 13.0+ (for development)

### Installation

1. **Clone the repository**
   ```bash
   git clone <repository-url>
   cd FIN1
   ```

2. **Open in Xcode**
   ```bash
   open FIN1.xcodeproj
   ```

3. **Set up color assets** (Required!)
   - Open `Assets.xcassets` in Xcode
   - Create color sets as specified in `FIN1/create_colors.md`
   - This step is **mandatory** for the app to compile

4. **Build and run**
   - Select your target device/simulator
   - Press `Cmd+R` to build and run

## 🎨 Design System

### Color Palette
The app uses a sophisticated blue theme with carefully chosen accent colors:

- **Primary:** Deep blue (#193365) for backgrounds
- **Secondary:** Dark blue (#0d1933) for cards
- **Accent:** Bright blue (#007aff) for primary actions
- **Success:** Green (#278e4c) for positive states
- **Error:** Red (#eb0000) for negative states
- **Warning:** Orange (#ff9500) for alerts

### Typography
- **Font Family:** SF Pro (system default)
- **Hierarchy:** Clear typography scale with proper contrast
- **Accessibility:** Dynamic Type support

### Components
- **Cards:** Rounded corners with subtle shadows
- **Buttons:** Consistent styling with proper states
- **Forms:** Clean input fields with validation
- **Navigation:** Tab-based navigation with inline titles

## 🔐 Authentication Flow

1. **Landing Page** → User chooses to login or sign up
2. **Registration** → 7-step process with validation
3. **Login** → Email/password or biometric authentication
4. **Main App** → Role-based dashboard and navigation

## 📱 User Experience

### Investor Journey
1. **Discover** → Browse and filter traders
2. **Research** → View detailed trader profiles
3. **Invest** → Create investment with custom parameters
4. **Monitor** → Track portfolio performance
5. **Profit** → Receive proportional returns

### Trader Journey
1. **Setup** → Configure trading parameters
2. **Manage** → Handle investor funds and pools
3. **Trade** → Execute trades with pooled capital
4. **Distribute** → Share profits/losses proportionally
5. **Grow** → Build reputation and attract investors

## 🧪 Testing

### Unit Tests
- **Coverage Target:** 95%+
- **Framework:** XCTest
- **Focus:** Business logic and data models

### UI Tests
- **Framework:** XCUITest
- **Coverage:** Critical user flows
- **Automation:** CI/CD pipeline integration

### Test Data
- **Mock Models:** Comprehensive test data
- **Scenarios:** Edge cases and error conditions
- **Performance:** Load testing and memory profiling

## 🔒 Security Features

- **Biometric Authentication:** Face ID/Touch ID support
- **Secure Storage:** Keychain integration
- **Data Encryption:** AES-256 for sensitive data
- **Network Security:** TLS 1.3 for API communication
- **GDPR Compliance:** Data privacy and user consent

## 📊 Performance

### Targets
- **App Launch:** < 2 seconds
- **Navigation:** < 0.5 seconds
- **API Calls:** < 1.5 seconds
- **Offline Support:** Cached data access

### Optimization
- **Lazy Loading:** Efficient list rendering
- **Image Caching:** Optimized asset management
- **Memory Management:** Proper cleanup and disposal
- **Background Processing:** Efficient data updates

## 🚧 Development Status

### ✅ Completed
- [x] Project structure and architecture
- [x] Authentication system (UI + logic)
- [x] User management and state
- [x] Dashboard and navigation
- [x] Investor discovery and portfolio
- [x] Trader trading and depot views
- [x] Customer support system (tickets, FAQ, agents)
- [x] Admin features (reports, rounding differences, configuration)
- [x] Notifications and profile
- [x] Design system and components
- [x] Calculation services (commission, profit, collection bills)
- [x] Network tools and diagnostics
- [x] Mac development optimization

### 🔄 In Progress
- [ ] API integration with Parse Server
- [ ] Real-time data updates
- [ ] Push notification implementation
- [ ] Advanced trading features

### 📋 Planned
- [ ] Charts and analytics
- [ ] Advanced filtering and search
- [ ] Social features and reviews
- [ ] Mobile wallet integration
- [ ] Multi-language support

## 🤝 Contributing

### Development Guidelines
- **SwiftUI Best Practices:** Follow Apple's design guidelines
- **Code Style:** Use SwiftLint/SwiftFormat for consistency
- **Architecture:** Maintain MVVM pattern
- **Testing:** Write tests for new features
- **Documentation:** Update README and code comments

### Pull Request Process
1. **Fork** the repository
2. **Create** a feature branch
3. **Implement** your changes
4. **Test** thoroughly
5. **Submit** a pull request

### Documentation

**Two Documentation Directories:**
- **`Documentation/`** (Root-Level) - 24 files: Architecture, development guides, network tools
- **`FIN1/Documentation/`** (Feature-Level) - 49 files: Feature-specific docs, code reviews

See `Documentation/README.md` for complete index.

### Development Scripts

**Network Scripts** (in `scripts/network/`):
- `health-check-backend.sh` - Backend connection testing (netcat, nmap, mtr)
- `network-tuning.sh` - Network performance tuning (on-demand)

**Other Scripts:**
- `caffeinate-build.sh` - Intelligent caffeinate wrapper for builds
- `check-file-sizes.sh` - Validates file size limits (≤400 lines)
- `validate-mvvm-architecture.sh` - MVVM compliance checking
- See `scripts/README.md` for complete list

### Engineering Guide
- See `Documentation/ENGINEERING_GUIDE.md` for:
  - MVVM + DI rules and composition root
  - Lifecycle preloading and telemetry
  - Testing structure and Xcode Test Plan
  - Lint/format tooling and PR guardrails (Danger)
  - CI workflow details and how to add ViewModels/Services

## 📄 License

This project is proprietary software. All rights reserved.

## 📞 Support

For technical support or questions:
- **Issues:** GitHub Issues
- **Documentation:**
  - Root-level: `Documentation/` (24 files)
  - Feature-level: `FIN1/Documentation/` (49 files)
  - Scripts: `scripts/README.md`
- **Development:** Follow the setup instructions above

## 🔧 Development Tools

### Network Diagnostics
```bash
# Backend connection test
./scripts/network/health-check-backend.sh [HOST]

# Network performance tuning
./scripts/network/network-tuning.sh status
```

### Code Quality
```bash
# Check file sizes
./scripts/check-file-sizes.sh

# Validate MVVM architecture
./scripts/validate-mvvm-architecture.sh

# Check ResponsiveDesign compliance
./scripts/check-responsive-design.sh
```

### Mac Development
```bash
# Optimize Mac for development
./scripts/optimize-mac-for-development.sh

# Build with caffeinate (prevents sleep)
./scripts/caffeinate-build.sh --mode build
```

See `Documentation/NETWORK_TOOLS.md` and `scripts/README.md` for details.

## 🔮 Future Roadmap

### Phase 1: Core Platform (Current)
- Basic investment and trading functionality
- User authentication and management
- Portfolio tracking and analytics

### Phase 2: Advanced Features
- Real-time market data integration
- Advanced trading algorithms
- Social trading features

### Phase 3: Enterprise Features
- Institutional investor support
- Advanced risk management
- Regulatory compliance tools

---

**Note:** This is a comprehensive investment platform implementation. Ensure you have proper financial licenses and compliance before deploying to production.

## 🏷 App Name / Branding

- User-facing copy must use `AppBrand.appName` (bundle-driven) instead of hardcoding an app name.
