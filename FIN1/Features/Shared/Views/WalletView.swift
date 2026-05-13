import SwiftUI

// MARK: - Wallet View
/// Main wallet view showing balance, quick actions, and transaction history.
/// Subviews are in Wallet/ (WalletBalanceCard, WalletQuickActionsSection, etc.).
struct WalletView: View {
    @ObservedObject var viewModel: WalletViewModel
    @State private var showTransactionHistory = false

    var body: some View {
        ZStack {
            AppTheme.screenBackground
                .ignoresSafeArea()

            if self.viewModel.isLoading && self.viewModel.currentBalance == 0.0 && self.viewModel.transactions.isEmpty {
                self.loadingView
            } else if let error = viewModel.errorMessage {
                self.errorView(error: error)
            } else {
                self.contentView
            }
        }
        .navigationTitle("Konto")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    Task {
                        await self.viewModel.refresh()
                    }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .foregroundColor(AppTheme.accentLightBlue)
                        .rotationEffect(.degrees(self.viewModel.isLoading ? 360 : 0))
                        .animation(
                            self.viewModel.isLoading ? .linear(duration: 1).repeatForever(autoreverses: false) : .default,
                            value: self.viewModel.isLoading
                        )
                }
            }
        }
        .sheet(isPresented: self.$viewModel.showDepositSheet) {
            WalletDepositSheet(viewModel: self.viewModel) {
                self.viewModel.showDepositSheet = false
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: self.$viewModel.showWithdrawalSheet) {
            WalletWithdrawalSheet(viewModel: self.viewModel) {
                self.viewModel.showWithdrawalSheet = false
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: self.$showTransactionHistory) {
            TransactionHistoryView(viewModel: self.viewModel)
        }
        .alert("Erfolg", isPresented: self.$viewModel.showSuccessMessage) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(self.viewModel.successMessage)
        }
        .task {
            await self.viewModel.loadWalletData()
        }
    }

    // MARK: - Loading

    private var loadingView: some View {
        VStack(spacing: ResponsiveDesign.spacing(4)) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: AppTheme.accentLightBlue))
                .scaleEffect(1.2)
            Text("Lade Kontodaten...")
                .font(ResponsiveDesign.bodyFont())
                .foregroundColor(AppTheme.secondaryText)
        }
        .transition(.opacity)
    }

    // MARK: - Error

    private func errorView(error: String) -> some View {
        VStack(spacing: ResponsiveDesign.spacing(4)) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(ResponsiveDesign.scaledSystemFont(size: ResponsiveDesign.iconSize() * 2))
                .foregroundColor(AppTheme.accentOrange)
            Text("Fehler beim Laden")
                .font(ResponsiveDesign.headlineFont())
                .foregroundColor(AppTheme.fontColor)
            Text(error)
                .font(ResponsiveDesign.captionFont())
                .foregroundColor(AppTheme.secondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, ResponsiveDesign.horizontalPadding())
            Button {
                Task {
                    await self.viewModel.loadWalletData()
                }
            } label: {
                Text("Erneut versuchen")
                    .font(ResponsiveDesign.bodyFont())
                    .foregroundColor(.white)
                    .padding(ResponsiveDesign.spacing(4))
                    .background(AppTheme.accentLightBlue)
                    .cornerRadius(ResponsiveDesign.spacing(3))
            }
        }
        .transition(.opacity)
    }

    // MARK: - Content

    private var contentView: some View {
        ScrollView {
            VStack(spacing: ResponsiveDesign.spacing(6)) {
                WalletBalanceCard(formattedBalance: self.viewModel.formattedBalance)
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))

                WalletQuickActionsSection(
                    actionsEnabled: self.viewModel.accountActionsEnabled,
                    onDeposit: {
                        guard self.viewModel.accountActionsEnabled else { return }
                        self.viewModel.showDepositSheet = true
                    },
                    onWithdrawal: {
                        guard self.viewModel.accountActionsEnabled else { return }
                        self.viewModel.showWithdrawalSheet = true
                    }
                )
                .transition(.opacity.combined(with: .move(edge: .top)))

                if !self.viewModel.accountActionsEnabled {
                    Text("Ein-/Auszahlungsaktionen sind derzeit deaktiviert. Kontostand und Historie bleiben jederzeit sichtbar.")
                        .font(ResponsiveDesign.captionFont())
                        .foregroundColor(AppTheme.secondaryText)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, ResponsiveDesign.horizontalPadding())
                }

                WalletRecentTransactionsSection(
                    transactions: self.viewModel.transactions,
                    onShowAll: { self.showTransactionHistory = true }
                )
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
            .padding(.horizontal, ResponsiveDesign.horizontalPadding())
            .padding(.top, ResponsiveDesign.spacing(8))
        }
        .refreshable {
            await self.viewModel.refresh()
        }
        .animation(.easeInOut(duration: 0.3), value: self.viewModel.transactions.count)
    }
}
