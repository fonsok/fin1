import SwiftUI

// MARK: - Dashboard Stats Section
/// Displays quick stats for the dashboard
/// Uses DashboardStatsViewModel for all business logic (MVVM compliant)
struct DashboardStatsSection: View {
    @Environment(\.appServices) private var appServices
    @EnvironmentObject var tabRouter: TabRouter
    @Binding var navigationPath: NavigationPath
    @Environment(\.themeManager) private var themeManager

    @StateObject private var viewModel: DashboardStatsViewModel

    // MARK: - Initialization

    init(navigationPath: Binding<NavigationPath>, appServices: AppServices) {
        self._navigationPath = navigationPath
        self._viewModel = StateObject(wrappedValue: DashboardStatsViewModel(appServices: appServices))
    }

    var body: some View {
        Group {
            if viewModel.isInvestor {
                VStack(spacing: ResponsiveDesign.spacing(12)) {
                    investorStatsContent
                }
                .padding(ResponsiveDesign.spacing(16))
                .background(AppTheme.sectionBackground.opacity(0.5))
                .cornerRadius(ResponsiveDesign.spacing(12))
            } else {
                // Trader: Show rows with section wrapper matching welcome section
                VStack(spacing: ResponsiveDesign.spacing(12)) {
                    traderStatsContent
                }
                .padding(ResponsiveDesign.spacing(16))
                .background(AppTheme.sectionBackground.opacity(0.5))
                .cornerRadius(ResponsiveDesign.spacing(12))
            }
        }
        .task {
            await viewModel.onViewAppear()
        }
        .onAppear {
            viewModel.refreshAllData()
        }
        .onChange(of: appServices.investmentService.investments.count) { _, _ in
            viewModel.onInvestmentsCountChange()
        }
    }

    // MARK: - Section Header

    private var sectionHeader: some View {
        HStack {
            Text("Quick Stats")
                .font(ResponsiveDesign.captionFont())
                .fontWeight(.regular)
                .foregroundColor(AppTheme.secondaryText)
            Spacer()
        }
    }

    // MARK: - Investor Stats Content

    private var investorStatsContent: some View {
        VStack(spacing: ResponsiveDesign.spacing(12)) {
            // Cash Balance row
            cashBalanceRow

            // Account action shortcuts directly below balance
            accountActionsRow

            // Active Investments row
            activeInvestmentsRow
        }
    }

    private var cashBalanceRow: some View {
        HStack {
            HStack(spacing: ResponsiveDesign.spacing(4)) {
                Text("Cash Balance")
                    .font(ResponsiveDesign.headlineFont())
                    .fontWeight(.light)
                    .foregroundColor(AppTheme.tertiaryText)

                Image(systemName: "info.circle.fill")
                    .font(ResponsiveDesign.scaledSystemFont(size: ResponsiveDesign.spacing(14)))
                    .foregroundColor(AppTheme.accentLightBlue)
            }
            .contentShape(Rectangle())
            .onTapGesture {
                openAccountStatement()
            }
            .accessibilityLabel("Cash balance")
            .accessibilityHint("Opens detailed account statement")
            .accessibilityAddTraits(.isButton)
            Spacer()
            Text(viewModel.investorBalance)
                .font(ResponsiveDesign.headlineFont())
                .fontWeight(.regular)
                .foregroundColor(AppTheme.fontColor)
        }
    }

    private var activeInvestmentsRow: some View {
        HStack {
            Text("Active Investments")
                .font(ResponsiveDesign.headlineFont())
                .fontWeight(.light)
                .foregroundColor(AppTheme.tertiaryText)
            Spacer()
            Text("\(viewModel.activeInvestmentsCount)")
                .font(ResponsiveDesign.headlineFont())
                .fontWeight(.medium)
                .foregroundColor(AppTheme.accentGreen.opacity(0.8))
                .contentShape(Rectangle())
                .onTapGesture {
                    tabRouter.selectedTab = 2
                }
                .accessibilityLabel("Active Investments")
                .accessibilityHint("Tap to view your investments")
                .accessibilityAddTraits(.isButton)
        }
    }

    // MARK: - Trader Stats Content

    private var traderStatsContent: some View {
        VStack(spacing: ResponsiveDesign.spacing(12)) {
            // Row 1: Account Balance
            traderAccountBalanceRow

            // Row 1b: Account action shortcuts directly below balance
            accountActionsRow

            // Row 2: Depot Value
            traderDepotValueRow

            // Row 3: Pool
            traderPoolRow
        }
    }

    private var traderAccountBalanceRow: some View {
        HStack {
            HStack(spacing: ResponsiveDesign.spacing(4)) {
                Text("Account Balance")
                    .font(ResponsiveDesign.headlineFont())
                    .fontWeight(.light)
                    .foregroundColor(AppTheme.tertiaryText)

                Image(systemName: "info.circle.fill")
                    .font(ResponsiveDesign.scaledSystemFont(size: ResponsiveDesign.spacing(14)))
                    .foregroundColor(AppTheme.accentLightBlue)
            }
            .contentShape(Rectangle())
            .onTapGesture {
                openAccountStatement()
            }
            .accessibilityLabel("Account balance")
            .accessibilityHint("Opens trader account statement")
            .accessibilityAddTraits(.isButton)
            Spacer()
            Text(viewModel.accountBalance.formattedAsLocalizedCurrency())
                .font(ResponsiveDesign.headlineFont())
                .fontWeight(.medium)
                .foregroundColor(AppTheme.fontColor)
        }
    }

    private var traderDepotValueRow: some View {
        HStack {
            Text("Depot Value")
                .font(ResponsiveDesign.headlineFont())
                .fontWeight(.light)
                .foregroundColor(AppTheme.tertiaryText)
            Spacer()
            Text(viewModel.depotValue.formattedAsLocalizedCurrency())
                .font(ResponsiveDesign.headlineFont())
                .fontWeight(.medium)
                .foregroundColor(AppTheme.fontColor)
        }
    }

    private var traderPoolRow: some View {
        HStack {
            Text("Pool")
                .font(ResponsiveDesign.headlineFont())
                .fontWeight(.light)
                .foregroundColor(AppTheme.tertiaryText)
            Spacer()
            poolStatusText
        }
    }

    private var accountActionsRow: some View {
        HStack(spacing: ResponsiveDesign.spacing(8)) {
            Button {
                openAccountActions()
            } label: {
                HStack(spacing: ResponsiveDesign.spacing(6)) {
                    Image(systemName: "arrow.down.circle.fill")
                    Text("Einzahlen")
                        .fontWeight(.semibold)
                }
                .font(ResponsiveDesign.captionFont())
                .frame(maxWidth: .infinity)
                .padding(.vertical, ResponsiveDesign.spacing(8))
                .background(AppTheme.buttonColor.opacity(0.85))
                .foregroundColor(AppTheme.fontColor)
                .cornerRadius(ResponsiveDesign.spacing(10))
            }

            Button {
                openAccountActions()
            } label: {
                HStack(spacing: ResponsiveDesign.spacing(6)) {
                    Image(systemName: "arrow.up.circle.fill")
                    Text("Auszahlen")
                        .fontWeight(.semibold)
                }
                .font(ResponsiveDesign.captionFont())
                .frame(maxWidth: .infinity)
                .padding(.vertical, ResponsiveDesign.spacing(8))
                .background(AppTheme.buttonColor.opacity(0.85))
                .foregroundColor(AppTheme.fontColor)
                .cornerRadius(ResponsiveDesign.spacing(10))
            }
        }
    }

    @ViewBuilder
    private var poolStatusText: some View {
        let isActive = viewModel.traderPoolsStatus == "active"
        if isActive {
            Text("active")
                .font(ResponsiveDesign.headlineFont())
                .fontWeight(.medium)
                .italic()
                .foregroundColor(AppTheme.accentGreen)
        } else {
            Text("-")
                .font(ResponsiveDesign.headlineFont())
                .fontWeight(.medium)
                .foregroundColor(AppTheme.tertiaryText)
        }
    }

    // MARK: - Navigation

    private func openAccountStatement() {
        navigationPath.append(DashboardRoute.accountStatement)
    }

    private func openAccountActions() {
        navigationPath.append(DashboardRoute.wallet)
    }
}

#Preview {
    DashboardStatsSection(navigationPath: .constant(NavigationPath()), appServices: AppServices.live)
        .environmentObject(TabRouter())
}
