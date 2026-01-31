import SwiftUI

// MARK: - Dashboard Container
/// Handles role-based rendering and navigation for the dashboard
struct DashboardContainer: View {
    @Environment(\.appServices) private var services
    @EnvironmentObject var tabRouter: TabRouter

    var body: some View {
        DashboardContainerContent(services: services)
            .environmentObject(tabRouter)
    }
}

// MARK: - Dashboard Container Content
/// Internal view that receives services as parameters
private struct DashboardContainerContent: View {
    let services: AppServices
    @StateObject private var viewModel: DashboardViewModel
    @EnvironmentObject var tabRouter: TabRouter
    @State private var navigationPath = NavigationPath()
    @ObservedObject private var themeManager = ThemeManager.shared

    init(services: AppServices) {
        self.services = services
        // Create ViewModel with the injected services
        _viewModel = StateObject(wrappedValue: DashboardViewModel(
            userService: services.userService,
            dashboardService: services.dashboardService,
            telemetryService: services.telemetryService
        ))
    }

    var body: some View {
        NavigationStack(path: $navigationPath) {
            ZStack {
                AppTheme.screenBackground
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: ResponsiveDesign.spacing(6)) {
                        // Welcome Header
                        DashboardWelcomeHeader()

                        // Risk Warning Message
                        Text("Note: never expose more than 2% of your assets to risk.")
                            .font(ResponsiveDesign.captionFont())
                            .foregroundColor(AppTheme.secondaryText)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)
                            .padding(.bottom, ResponsiveDesign.spacing(8))

                        // Quick Stats
                        DashboardStatsSection(navigationPath: $navigationPath)
                            .environmentObject(tabRouter)
                            .padding(.bottom, ResponsiveDesign.spacing(12))

                        // New Investment button (for investors only, outside Quick Actions)
                        if viewModel.isInvestor {
                            NewInvestmentButton()
                                .environmentObject(tabRouter)
                        }

                        // Quick Actions
                        DashboardQuickActionsSection(navigateToDiscovery: $viewModel.selectedTab)

                        // Role-specific content
                        roleSpecificContent
                    }
                    .padding(.horizontal, ResponsiveDesign.horizontalPadding())
                    .padding(.top, ResponsiveDesign.spacing(8))
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: DashboardRoute.self) { route in
                switch route {
                case .accountStatement:
                    AccountStatementView(services: services)
                case .wallet:
                    WalletViewWrapper(services: services)
                }
            }
        }
        .onChange(of: viewModel.selectedTab) { _, newValue in
            print("🔄 Navigation selection changed to: \(newValue ?? "nil")")
        }
        .onAppear {
            Task {
                await viewModel.loadDashboardDataAsync()
            }
        }
    }

    // MARK: - Role-specific Content

    @ViewBuilder
    private var roleSpecificContent: some View {
        if viewModel.isInvestor {
            DashboardTraderOverview()
        } else if viewModel.isTrader {
            // Trader-specific content can be added here
            EmptyView()
        } else {
            // Default content for other roles
            EmptyView()
        }
    }
}

#Preview {
    DashboardContainer()
        .environmentObject(TabRouter())
}
