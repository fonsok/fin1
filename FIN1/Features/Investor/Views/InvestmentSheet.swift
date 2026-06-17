import SwiftUI

// MARK: - Investment Sheet Wrapper
/// Wrapper view that handles dependency injection from environment
struct InvestmentSheet: View {
    let trader: InvestorTrader
    let onInvestmentSuccess: (() -> Void)?

    @Environment(\.appServices) private var services

    var body: some View {
        InvestmentSheetContent(
            trader: self.trader,
            onInvestmentSuccess: self.onInvestmentSuccess,
            services: self.services
        )
    }
}

// MARK: - Investment Sheet Content
/// Internal view that receives services as parameters
private struct InvestmentSheetContent: View {
    let trader: InvestorTrader
    let onInvestmentSuccess: (() -> Void)?
    let services: AppServices

    @Environment(\.dismiss) private var dismiss
    @Environment(\.themeManager) private var themeManager

    // MARK: - ViewModels
    @StateObject private var viewModel: InvestmentSheetViewModel
    @StateObject private var investmentSummaryViewModel: InvestmentSummaryViewModel

    init(trader: InvestorTrader, onInvestmentSuccess: (() -> Void)?, services: AppServices) {
        self.trader = trader
        self.onInvestmentSuccess = onInvestmentSuccess
        self.services = services

        // Create ViewModel with the injected services
        self._viewModel = StateObject(wrappedValue: InvestmentSheetViewModel(
            trader: trader,
            userService: services.userService,
            investmentService: services.investmentService,
            telemetryService: services.telemetryService,
            investorCashBalanceService: services.investorCashBalanceService,
            configurationService: services.configurationService,
            parseAPIClient: services.parseAPIClient,
            onInvestmentSuccess: onInvestmentSuccess
        ))
        self._investmentSummaryViewModel = StateObject(
            wrappedValue: InvestmentSummaryViewModel(
                amountPerInvestment: 0,
                numberOfInvestments: 3,
                totalInvestmentAmount: 0,
                configurationService: services.configurationService
            )
        )
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.screenBackground.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: ResponsiveDesign.spacing(16)) {
                        // Header
                        InvestmentHeaderView(trader: self.viewModel.trader)

                        // Investment Form
                        InvestmentFormView(
                            investmentAmount: self.$viewModel.investmentAmount,
                            selectedInvestmentSelection: self.$viewModel.selectedInvestmentSelection,
                            numberOfInvestments: self.$viewModel.numberOfInvestments,
                            configurationService: self.services.configurationService
                        )

                        // Cash Balance Warning
                        if self.viewModel.showInsufficientCashBalanceWarning {
                            self.insufficientCashBalanceWarningView
                        }

                        if self.viewModel.showInvestmentSlotLimitHint {
                            self.investmentSlotLimitHintView
                        }

                        if self.viewModel.isHydratingTraderIdentityMessage {
                            self.traderIdentityLoadingView
                        } else if let traderBlocked = self.viewModel.traderIdentityBlockedMessage {
                            self.traderIdentityBlockedView(message: traderBlocked)
                        }

                        if self.viewModel.showPoolMirrorCapacityBlockedProactive {
                            self.poolMirrorCapacityBlockedProactiveView
                        }

                        if self.viewModel.showPoolMirrorMaxInvestableOnInput {
                            self.poolMirrorMaxInvestableOnInputView
                        }

                        // Investment Selection Section
                        InvestmentSelectionView(
                            selectedInvestmentSelection: self.viewModel.selectedInvestmentSelection,
                            numberOfInvestments: self.viewModel.numberOfInvestments,
                            amountPerInvestment: self.viewModel.amountPerInvestment
                        )

                        // Investment Summary
                        InvestmentSummaryView(
                            viewModel: self.investmentSummaryViewModel,
                            remainingBalance: self.viewModel.remainingBalanceAfterInvestment,
                            currentBalance: self.viewModel.currentCashBalance
                        )

                        // Commission Confirmation
                        CommissionConfirmationView(
                            traderUsername: self.viewModel.trader.username,
                            commissionPercentage: self.services.configurationService.investorCommissionPercentage,
                            isConfirmed: self.$viewModel.isCommissionConfirmed
                        )

                        // Action Buttons
                        InvestmentActionButtonsView(
                            canProceed: self.viewModel.canProceed,
                            isLoading: self.viewModel.isLoading,
                            onCreateInvestment: {
                                Task {
                                    await self.viewModel.createInvestment()
                                }
                            },
                            onCancel: { self.dismiss() }
                        )
                    }
                    .padding()
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .navigationTitle("Investment")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        self.dismiss()
                    }
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Fertig") {
                        UIApplication.shared.sendAction(
                            #selector(UIResponder.resignFirstResponder),
                            to: nil,
                            from: nil,
                            for: nil
                        )
                    }
                }
            }
        }
        .task {
            await self.viewModel.refreshAuthoritativeCashBalance()
        }
        .alert("Investment nicht möglich", isPresented: self.$viewModel.showInvestmentError) {
            Button("OK") { }
        } message: {
            Text(self.viewModel.investmentErrorMessage)
        }
        .alert("Investment Created", isPresented: self.$viewModel.showSuccess) {
            Button("OK") {
                // This will be handled automatically by the timer
            }
            .accessibilityIdentifier("InvestmentSuccessOKButton")
        } message: {
            Text("Your investment has been successfully created! Returning to dashboard...")
        }
        .accessibilityIdentifier("InvestmentSuccessAlert")
        .onChange(of: self.viewModel.investmentAmount) {
            self.updateInvestmentSummary()
            self.viewModel.schedulePoolMirrorCapacityRefresh()
        }
        .onChange(of: self.viewModel.numberOfInvestments) {
            self.updateInvestmentSummary()
            self.viewModel.schedulePoolMirrorCapacityRefresh()
        }
        .onAppear {
            Task { @MainActor in
                await self.viewModel.prepareForInvestingFlow(
                    traderDataService: self.services.traderDataService
                )
                _ = self.viewModel.validateUserCanInvest()
                self.updateInvestmentSummary()
            }
        }
    }

    // MARK: - Helper Methods

    private func updateInvestmentSummary() {
        self.investmentSummaryViewModel.update(
            amountPerInvestment: self.viewModel.amountPerInvestment,
            numberOfInvestments: self.viewModel.numberOfInvestments,
            totalInvestmentAmount: self.viewModel.totalInvestmentAmount
        )
    }

    // MARK: - Warning Views

    @ViewBuilder
    private var insufficientCashBalanceWarningView: some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(8)) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(AppTheme.accentRed)
                    .font(ResponsiveDesign.scaledSystemFont(size: ResponsiveDesign.iconSize()))
                Text("!")
                    .font(ResponsiveDesign.headlineFont())
                    .foregroundColor(AppTheme.accentRed)
            }

            Text(self.viewModel.insufficientCashBalanceMessage)
                .font(ResponsiveDesign.bodyFont())
                .foregroundColor(AppTheme.primaryText)
                .multilineTextAlignment(.leading)
        }
        .padding()
        .background(AppTheme.accentRed.opacity(0.1))
        .overlay(
            RoundedRectangle(cornerRadius: ResponsiveDesign.spacing(10))
                .stroke(AppTheme.accentRed.opacity(0.3), lineWidth: 1)
        )
        .cornerRadius(ResponsiveDesign.spacing(10))
    }

    @ViewBuilder
    private var investmentSlotLimitHintView: some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(8)) {
            HStack {
                Image(systemName: "info.circle.fill")
                    .foregroundColor(AppTheme.accentOrange)
                    .font(ResponsiveDesign.scaledSystemFont(size: ResponsiveDesign.iconSize()))
                Text("Hinweis")
                    .font(ResponsiveDesign.headlineFont())
                    .foregroundColor(AppTheme.primaryText)
            }

            Text(self.viewModel.investmentSlotLimitHintMessage)
                .font(ResponsiveDesign.bodyFont())
                .foregroundColor(AppTheme.primaryText)
                .multilineTextAlignment(.leading)
        }
        .padding()
        .background(AppTheme.accentOrange.opacity(0.12))
        .overlay(
            RoundedRectangle(cornerRadius: ResponsiveDesign.spacing(10))
                .stroke(AppTheme.accentOrange.opacity(0.35), lineWidth: 1)
        )
        .cornerRadius(ResponsiveDesign.spacing(10))
        .accessibilityIdentifier("InvestmentSlotLimitHint")
    }

    @ViewBuilder
    private var traderIdentityLoadingView: some View {
        HStack(spacing: ResponsiveDesign.spacing(10)) {
            ProgressView()
            Text("Trader-Verbindung wird geladen …")
                .font(ResponsiveDesign.bodyFont())
                .foregroundColor(AppTheme.secondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .accessibilityIdentifier("TraderIdentityLoading")
    }

    @ViewBuilder
    private func traderIdentityBlockedView(message: String) -> some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(8)) {
            HStack {
                Image(systemName: "person.crop.circle.badge.exclamationmark")
                    .foregroundColor(AppTheme.accentOrange)
                    .font(ResponsiveDesign.scaledSystemFont(size: ResponsiveDesign.iconSize()))
                Text("Trader-Verbindung")
                    .font(ResponsiveDesign.headlineFont())
                    .foregroundColor(AppTheme.primaryText)
            }
            Text(message)
                .font(ResponsiveDesign.bodyFont())
                .foregroundColor(AppTheme.primaryText)
                .multilineTextAlignment(.leading)
            Button("Erneut verbinden") {
                Task {
                    await self.viewModel.prepareForInvestingFlow(
                        traderDataService: self.services.traderDataService
                    )
                }
            }
            .font(ResponsiveDesign.bodyFont())
        }
        .padding()
        .background(AppTheme.accentOrange.opacity(0.12))
        .overlay(
            RoundedRectangle(cornerRadius: ResponsiveDesign.spacing(10))
                .stroke(AppTheme.accentOrange.opacity(0.35), lineWidth: 1)
        )
        .cornerRadius(ResponsiveDesign.spacing(10))
        .accessibilityIdentifier("TraderIdentityBlockedHint")
    }

    @ViewBuilder
    private var poolMirrorCapacityBlockedProactiveView: some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(10)) {
            HStack {
                Image(systemName: "pause.circle.fill")
                    .foregroundColor(AppTheme.accentOrange)
                    .font(ResponsiveDesign.scaledSystemFont(size: ResponsiveDesign.iconSize()))
                Text("Hinweis")
                    .font(ResponsiveDesign.headlineFont())
                    .foregroundColor(AppTheme.primaryText)
            }

            Text(self.viewModel.poolMirrorCapacityBlockedProactiveMessage)
                .font(ResponsiveDesign.bodyFont())
                .foregroundColor(AppTheme.primaryText)
                .multilineTextAlignment(.leading)

            if self.viewModel.showPoolMirrorCapacityNotifyButton {
                self.poolMirrorCapacityAlertButton
            }
        }
        .padding()
        .background(AppTheme.accentOrange.opacity(0.12))
        .overlay(
            RoundedRectangle(cornerRadius: ResponsiveDesign.spacing(10))
                .stroke(AppTheme.accentOrange.opacity(0.35), lineWidth: 1)
        )
        .cornerRadius(ResponsiveDesign.spacing(10))
        .accessibilityIdentifier("PoolMirrorCapacityBlockedProactive")
    }

    @ViewBuilder
    private var poolMirrorMaxInvestableOnInputView: some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(8)) {
            HStack {
                Image(systemName: "info.circle.fill")
                    .foregroundColor(AppTheme.accentOrange)
                    .font(ResponsiveDesign.scaledSystemFont(size: ResponsiveDesign.iconSize()))
                Text("Hinweis")
                    .font(ResponsiveDesign.headlineFont())
                    .foregroundColor(AppTheme.primaryText)
            }

            Text(self.viewModel.poolMirrorMaxInvestableOnInputMessage)
                .font(ResponsiveDesign.bodyFont())
                .foregroundColor(AppTheme.primaryText)
                .multilineTextAlignment(.leading)
        }
        .padding()
        .background(AppTheme.accentOrange.opacity(0.12))
        .overlay(
            RoundedRectangle(cornerRadius: ResponsiveDesign.spacing(10))
                .stroke(AppTheme.accentOrange.opacity(0.35), lineWidth: 1)
        )
        .cornerRadius(ResponsiveDesign.spacing(10))
        .accessibilityIdentifier("PoolMirrorMaxInvestableOnInput")
    }

    @ViewBuilder
    private var poolMirrorCapacityAlertButton: some View {
        let label = {
            HStack(spacing: ResponsiveDesign.spacing(8)) {
                if self.viewModel.isUpdatingPoolMirrorAlert {
                    ProgressView()
                        .controlSize(.small)
                }
                if self.viewModel.poolMirrorAlertSubscribed {
                    Image(systemName: "bell.badge.fill")
                        .font(ResponsiveDesign.bodyFont())
                }
                Text(
                    self.viewModel.poolMirrorAlertSubscribed
                        ? "Benachrichtigung ist aktiv"
                        : "Benachrichtigen, wenn Investieren wieder möglich ist"
                )
                .font(ResponsiveDesign.bodyFont())
            }
            .frame(maxWidth: .infinity)
        }

        if self.viewModel.poolMirrorAlertSubscribed {
            Button {
                Task { await self.viewModel.togglePoolMirrorCapacityAlert() }
            } label: {
                label()
            }
            .buttonStyle(.bordered)
            .tint(AppTheme.accentGreen)
            .disabled(self.viewModel.isUpdatingPoolMirrorAlert)
            .accessibilityIdentifier("PoolMirrorCapacityAlertButton")
        } else {
            Button {
                Task { await self.viewModel.togglePoolMirrorCapacityAlert() }
            } label: {
                label()
            }
            .buttonStyle(.borderedProminent)
            .tint(AppTheme.accentOrange)
            .disabled(self.viewModel.isUpdatingPoolMirrorAlert)
            .accessibilityIdentifier("PoolMirrorCapacityAlertButton")
        }
    }
}

#Preview {
    InvestmentSheet(trader: InvestorTrader(mock: mockTraders[0]), onInvestmentSuccess: nil)
}
