import SwiftUI

// MARK: - Dashboard Container
/// Handles role-based rendering and navigation for the dashboard
struct DashboardContainer: View {
    @Environment(\.appServices) private var services
    @EnvironmentObject var tabRouter: TabRouter

    var body: some View {
        DashboardContainerContent(services: self.services)
            .environmentObject(self.tabRouter)
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
    @State private var maximumRiskExposurePercent: Double = 2.0
    @State private var riskWarningText: String = ""

    private var defaultRiskWarningText: String {
        "Note: never expose more than \(Int(self.maximumRiskExposurePercent)) % of your assets to risk."
    }

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
        NavigationStack(path: self.$navigationPath) {
            ZStack {
                AppTheme.screenBackground
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: ResponsiveDesign.spacing(6)) {
                        // Welcome Header
                        DashboardWelcomeHeader()

                        // Risk Warning Message (value from configuration)
                        Text(self.riskWarningText.isEmpty ? self.defaultRiskWarningText : self.riskWarningText)
                            .font(ResponsiveDesign.captionFont())
                            .foregroundColor(AppTheme.secondaryText)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)
                            .padding(.bottom, ResponsiveDesign.spacing(8))

                        // Quick Stats
                        DashboardStatsSection(navigationPath: self.$navigationPath, appServices: self.services)
                            .environmentObject(self.tabRouter)
                            .padding(.bottom, ResponsiveDesign.spacing(12))

                        // New Investment button (for investors only, outside Quick Actions)
                        if self.viewModel.isInvestor {
                            NewInvestmentButton()
                                .environmentObject(self.tabRouter)
                        }

                        // Quick Actions
                        DashboardQuickActionsSection(navigateToDiscovery: self.$viewModel.selectedTab)

                        // Role-specific content
                        self.roleSpecificContent
                    }
                    .padding(.horizontal, ResponsiveDesign.horizontalPadding())
                    .padding(.top, ResponsiveDesign.spacing(8))
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: DashboardRoute.self) { route in
                switch route {
                case .accountStatement:
                    AccountStatementView(services: self.services)
                case .wallet:
                    WalletViewWrapper(services: self.services)
                }
            }
        }
        .onChange(of: self.viewModel.selectedTab) { _, newValue in
            print("🔄 Navigation selection changed to: \(newValue ?? "nil")")
        }
        .onAppear {
            self.maximumRiskExposurePercent = self.services.configurationService.maximumRiskExposurePercent
            Task {
                let provider = LegalSnippetProvider(termsContentService: services.termsContentService)
                let language: TermsOfServiceDataProvider.Language = .german
                let text = await provider.text(
                    for: .dashboardRiskNote,
                    language: language,
                    documentType: .terms,
                    defaultText: self.defaultRiskWarningText,
                    placeholders: [
                        "MAX_RISK_PERCENT": String(Int(self.maximumRiskExposurePercent))
                    ]
                )
                await MainActor.run {
                    self.riskWarningText = text
                }
            }
            Task {
                await self.viewModel.loadDashboardDataAsync()
            }
        }
        .onReceive(self.services.configurationService.configurationChanged) { _ in
            self.maximumRiskExposurePercent = self.services.configurationService.maximumRiskExposurePercent
        }
    }

    // MARK: - Role-specific Content

    @ViewBuilder
    private var roleSpecificContent: some View {
        if self.viewModel.isInvestor {
            DashboardTraderOverview()
        } else if self.viewModel.isTrader {
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
