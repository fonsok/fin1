import SwiftUI

// MARK: - Investment Sheet Wrapper
/// Wrapper view that handles dependency injection from environment
struct InvestmentSheet: View {
    let trader: MockTrader
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
    let trader: MockTrader
    let onInvestmentSuccess: (() -> Void)?
    let services: AppServices

    @Environment(\.dismiss) private var dismiss
    @Environment(\.themeManager) private var themeManager

    // MARK: - ViewModels
    @StateObject private var viewModel: InvestmentSheetViewModel
    @StateObject private var investmentSummaryViewModel: InvestmentSummaryViewModel

    init(trader: MockTrader, onInvestmentSuccess: (() -> Void)?, services: AppServices) {
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
                        InvestmentHeaderView(trader: self.trader)

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
                            traderUsername: self.trader.username,
                            commissionPercentage: self.services.configurationService.traderCommissionPercentage,
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
            }
            .navigationTitle("Investment")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        self.dismiss()
                    }
                }
            }
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
        }
        .onChange(of: self.viewModel.numberOfInvestments) {
            self.updateInvestmentSummary()
        }
        .onAppear {
            Task { @MainActor in
                await self.viewModel.prepareForInvestingFlow()
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
}

#Preview {
    InvestmentSheet(trader: mockTraders[0], onInvestmentSuccess: nil)
}
