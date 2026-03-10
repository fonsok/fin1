import SwiftUI

/// Main Quick Actions section for the dashboard
/// Displays role-specific quick action buttons based on the current user's role
struct DashboardQuickActionsSection: View {
    @Environment(\.appServices) private var appServices
    @Binding var navigateToDiscovery: String?
    @EnvironmentObject var tabRouter: TabRouter
    @State private var showOrderBuy = false
    @Environment(\.themeManager) private var themeManager

    // MARK: - Computed Properties

    /// Current user's role for explicit role-based rendering
    private var currentUserRole: UserRole? {
        appServices.userService.currentUser?.role
    }

    var body: some View {
        VStack(spacing: ResponsiveDesign.spacing(16)) {
            // Role-specific content based on user type
            roleSpecificContent
        }
        .sheet(isPresented: $showOrderBuy) {
            SecuritiesSearchView(services: appServices)
        }
    }

    // MARK: - Role-Specific Content

    /// Returns the appropriate Quick Actions content based on user role
    ///
    /// Role breakdown:
    /// - **Trader**: Shows "Handeln" button (opens securities search)
    /// - **Investor**: Shows nothing (New Investment button is displayed separately in DashboardContainer)
    /// - **Other roles**: Shows generic Quick Actions grid (Get Started, Learn More)
    @ViewBuilder
    private var roleSpecificContent: some View {
        switch currentUserRole {
        case .trader:
            traderQuickActions

        case .investor:
            // NOTE: Investor's "New Investment" button is displayed in DashboardContainer
            // as a separate section above Quick Actions. This section intentionally shows nothing.
            investorQuickActions

        case .admin, .customerService, .other:
            // Admin, Customer Service, and other roles get generic Quick Actions
            otherRolesQuickActions

        case .none:
            // Fallback for when user role is not determined
            EmptyView()
        }
    }

    // MARK: - Trader Quick Actions

    /// Trader-specific Quick Actions: "Handeln", "Wallet", and "Price Alerts" buttons
    private var traderQuickActions: some View {
        VStack(spacing: ResponsiveDesign.spacing(12)) {
            Button(action: {
                showOrderBuy = true
            }) {
                HStack(spacing: ResponsiveDesign.spacing(12)) {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(ResponsiveDesign.headlineFont())
                        .foregroundColor(AppTheme.fontColor)

                    Text("Handeln")
                        .font(ResponsiveDesign.headlineFont())
                        .fontWeight(.semibold)
                        .foregroundColor(AppTheme.fontColor)
                }
                .frame(maxWidth: .infinity)
                .frame(height: ResponsiveDesign.spacing(56))
                .background(AppTheme.buttonColor)
                .cornerRadius(ResponsiveDesign.spacing(12))
            }
            .accessibilityIdentifier("HandelnButton")
            .accessibilityLabel("Handeln")
            .accessibilityHint("Tap to open securities search")

            if appServices.configurationService.walletFeatureEnabled {
                NavigationLink(value: DashboardRoute.wallet) {
                    HStack(spacing: ResponsiveDesign.spacing(12)) {
                        Image(systemName: "wallet.pass.fill")
                            .font(ResponsiveDesign.headlineFont())
                            .foregroundColor(AppTheme.fontColor)

                        Text("Wallet")
                            .font(ResponsiveDesign.headlineFont())
                            .fontWeight(.semibold)
                            .foregroundColor(AppTheme.fontColor)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: ResponsiveDesign.spacing(56))
                    .background(AppTheme.buttonColor)
                    .cornerRadius(ResponsiveDesign.spacing(12))
                }
            }

            // Price Alerts button - users can access via tab bar
            // Quick action removed to keep UI clean - Price Alerts is accessible via "Alerts" tab
        }
    }

    // MARK: - Investor Quick Actions

    /// Investor-specific Quick Actions: Wallet button (only when wallet feature is enabled)
    ///
    /// IMPORTANT: The "New Investment" button for investors is displayed in
    /// `DashboardContainer` using `NewInvestmentButton`, not here.
    /// This separation allows the button to appear above Quick Stats.
    private var investorQuickActions: some View {
        Group {
            if appServices.configurationService.walletFeatureEnabled {
                NavigationLink(value: DashboardRoute.wallet) {
                    HStack(spacing: ResponsiveDesign.spacing(12)) {
                        Image(systemName: "wallet.pass.fill")
                            .font(ResponsiveDesign.headlineFont())
                            .foregroundColor(AppTheme.fontColor)

                        Text("Wallet")
                            .font(ResponsiveDesign.headlineFont())
                            .fontWeight(.semibold)
                            .foregroundColor(AppTheme.fontColor)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: ResponsiveDesign.spacing(56))
                    .background(AppTheme.buttonColor)
                    .cornerRadius(ResponsiveDesign.spacing(12))
                }
            }
        }
    }

    // MARK: - Other Roles Quick Actions

    /// Generic Quick Actions for roles other than Trader or Investor
    private var otherRolesQuickActions: some View {
        VStack(spacing: ResponsiveDesign.spacing(16)) {
            // Section header
            HStack {
                Text("Quick Actions")
                    .font(ResponsiveDesign.headlineFont())
                    .foregroundColor(AppTheme.fontColor)
                Spacer()
            }

            // Action cards grid
            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible()), count: 2),
                spacing: ResponsiveDesign.spacing(16)
            ) {
                DashboardQuickActionCard(
                    title: "Get Started",
                    icon: "play.circle.fill",
                    color: AppTheme.accentGreen
                ) {
                    // TODO: Navigate to onboarding
                }

                DashboardQuickActionCard(
                    title: "Learn More",
                    icon: "book.fill",
                    color: AppTheme.accentLightBlue
                ) {
                    // TODO: Navigate to help
                }
            }
        }
    }
}

#Preview {
    DashboardQuickActionsSection(navigateToDiscovery: .constant(nil))
        .environmentObject(TabRouter())
}
