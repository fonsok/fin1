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
                    StripedStepList {
                        DashboardWelcomeHeader()
                            .stripedListSection(stripeIndex: 0)

                        Text(self.riskWarningText.isEmpty ? self.defaultRiskWarningText : self.riskWarningText)
                            .font(ResponsiveDesign.captionFont())
                            .foregroundColor(AppTheme.secondaryText)
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .stripedListSection(stripeIndex: 1)

                        DashboardStatsSection(navigationPath: self.$navigationPath, appServices: self.services)
                            .environmentObject(self.tabRouter)
                            .stripedListSection(stripeIndex: 2)

                        if self.viewModel.isInvestor {
                            NewInvestmentButton()
                                .environmentObject(self.tabRouter)
                                .stripedListSection(stripeIndex: 3)

                            DashboardQuickActionsSection(navigateToDiscovery: self.$viewModel.selectedTab)
                                .stripedListSection(stripeIndex: 4)

                            DashboardTraderOverview(startStripeIndex: 5)
                        } else if self.viewModel.isTrader {
                            DashboardQuickActionsSection(navigateToDiscovery: self.$viewModel.selectedTab)
                                .stripedListSection(stripeIndex: 3)
                        } else {
                            DashboardQuickActionsSection(navigateToDiscovery: self.$viewModel.selectedTab)
                                .stripedListSection(stripeIndex: 3)
                        }
                    }
                    .padding(.bottom, ResponsiveDesign.spacing(16))
                }
                .scrollIndicators(.hidden)
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
}

#Preview {
    DashboardContainer()
        .environmentObject(TabRouter())
}
