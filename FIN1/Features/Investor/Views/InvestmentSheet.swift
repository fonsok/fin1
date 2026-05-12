import SwiftUI

// MARK: - Investment Sheet Wrapper
/// Wrapper view that handles dependency injection from environment
struct InvestmentSheet: View {
    let trader: MockTrader
    let onInvestmentSuccess: (() -> Void)?

    @Environment(\.appServices) private var services

    var body: some View {
        InvestmentSheetContent(
            trader: trader,
            onInvestmentSuccess: onInvestmentSuccess,
            services: services
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
                        InvestmentHeaderView(trader: trader)

                        // Investment Form
                        InvestmentFormView(
                            investmentAmount: $viewModel.investmentAmount,
                            selectedInvestmentSelection: $viewModel.selectedInvestmentSelection,
                            numberOfInvestments: $viewModel.numberOfInvestments,
                            configurationService: services.configurationService
                        )

                        // Cash Balance Warning
                        if viewModel.showInsufficientCashBalanceWarning {
                            insufficientCashBalanceWarningView
                        }

                        if viewModel.showInvestmentSlotLimitHint {
                            investmentSlotLimitHintView
                        }

                        // Investment Selection Section
                        InvestmentSelectionView(
                            selectedInvestmentSelection: viewModel.selectedInvestmentSelection,
                            numberOfInvestments: viewModel.numberOfInvestments,
                            amountPerInvestment: viewModel.amountPerInvestment
                        )

                        // Investment Summary
                        InvestmentSummaryView(
                            viewModel: investmentSummaryViewModel,
                            remainingBalance: viewModel.remainingBalanceAfterInvestment,
                            currentBalance: viewModel.currentCashBalance
                        )

                        // Commission Confirmation
                        CommissionConfirmationView(
                            traderUsername: trader.username,
                            commissionPercentage: services.configurationService.traderCommissionPercentage,
                            isConfirmed: $viewModel.isCommissionConfirmed
                        )

                        // Action Buttons
                        InvestmentActionButtonsView(
                            canProceed: viewModel.canProceed,
                            isLoading: viewModel.isLoading,
                            onCreateInvestment: {
                                Task {
                                    await viewModel.createInvestment()
                                }
                            },
                            onCancel: { dismiss() }
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
                        dismiss()
                    }
                }
            }
        }
        .alert("Investment nicht möglich", isPresented: $viewModel.showInvestmentError) {
            Button("OK") { }
        } message: {
            Text(viewModel.investmentErrorMessage)
        }
        .alert("Investment Created", isPresented: $viewModel.showSuccess) {
            Button("OK") {
                // This will be handled automatically by the timer
            }
            .accessibilityIdentifier("InvestmentSuccessOKButton")
        } message: {
            Text("Your investment has been successfully created! Returning to dashboard...")
        }
        .accessibilityIdentifier("InvestmentSuccessAlert")
        .onChange(of: viewModel.investmentAmount) {
            updateInvestmentSummary()
        }
        .onChange(of: viewModel.numberOfInvestments) {
            updateInvestmentSummary()
        }
        .onAppear {
            Task { @MainActor in
                await viewModel.prepareForInvestingFlow()
                _ = viewModel.validateUserCanInvest()
                updateInvestmentSummary()
            }
        }
    }

    // MARK: - Helper Methods

    private func updateInvestmentSummary() {
        investmentSummaryViewModel.update(
            amountPerInvestment: viewModel.amountPerInvestment,
            numberOfInvestments: viewModel.numberOfInvestments,
            totalInvestmentAmount: viewModel.totalInvestmentAmount
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

            Text(viewModel.insufficientCashBalanceMessage)
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

            Text(viewModel.investmentSlotLimitHintMessage)
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
