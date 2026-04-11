import SwiftUI

// MARK: - Wallet View Wrapper
/// Wrapper to properly initialize WalletViewModel on MainActor
struct WalletViewWrapper: View {
    let services: AppServices
    @StateObject private var viewModel: WalletViewModel
    
    init(services: AppServices) {
        self.services = services
        // Initialize ViewModel on MainActor with user-specific services
        _viewModel = StateObject(wrappedValue: WalletViewModel(
            cashBalanceService: services.cashBalanceService,
            paymentService: services.paymentService,
            userService: services.userService,
            investorCashBalanceService: services.investorCashBalanceService,
            invoiceService: services.invoiceService,
            configurationService: services.configurationService,
            settlementAPIService: services.settlementAPIService,
            parseLiveQueryClient: services.parseLiveQueryClient
        ))
    }
    
    var body: some View {
        WalletView(viewModel: viewModel)
    }
}
