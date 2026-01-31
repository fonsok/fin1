import SwiftUI

// MARK: - Wallet View
/// Main wallet view showing balance, quick actions, and transaction history
struct WalletView: View {
    @ObservedObject var viewModel: WalletViewModel
    @State private var showTransactionHistory = false
    
    var body: some View {
        ZStack {
            AppTheme.screenBackground
                .ignoresSafeArea()
            
            if viewModel.isLoading && viewModel.currentBalance == 0.0 && viewModel.transactions.isEmpty {
                // Loading state
                VStack(spacing: ResponsiveDesign.spacing(4)) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: AppTheme.accentLightBlue))
                        .scaleEffect(1.2)
                    Text("Lade Wallet-Daten...")
                        .font(ResponsiveDesign.bodyFont())
                        .foregroundColor(AppTheme.secondaryText)
                }
                .transition(.opacity)
            } else if let error = viewModel.errorMessage {
                // Error state
                VStack(spacing: ResponsiveDesign.spacing(4)) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: ResponsiveDesign.iconSize() * 2))
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
                            await viewModel.loadWalletData()
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
            } else {
                // Content
                ScrollView {
                    VStack(spacing: ResponsiveDesign.spacing(6)) {
                        // Balance Card
                        balanceCard
                            .transition(.opacity.combined(with: .scale(scale: 0.95)))
                        
                        // Quick Actions
                        quickActionsSection
                            .transition(.opacity.combined(with: .move(edge: .top)))
                        
                        // Recent Transactions Preview
                        recentTransactionsSection
                            .transition(.opacity.combined(with: .move(edge: .bottom)))
                    }
                    .padding(.horizontal, ResponsiveDesign.horizontalPadding())
                    .padding(.top, ResponsiveDesign.spacing(8))
                }
                .refreshable {
                    await viewModel.refresh()
                }
                .animation(.easeInOut(duration: 0.3), value: viewModel.transactions.count)
            }
        }
        .navigationTitle("Wallet")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    Task {
                        await viewModel.refresh()
                    }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .foregroundColor(AppTheme.accentLightBlue)
                        .rotationEffect(.degrees(viewModel.isLoading ? 360 : 0))
                        .animation(viewModel.isLoading ? .linear(duration: 1).repeatForever(autoreverses: false) : .default, value: viewModel.isLoading)
                }
            }
        }
        .sheet(isPresented: $viewModel.showDepositSheet) {
            depositSheet
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $viewModel.showWithdrawalSheet) {
            withdrawalSheet
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showTransactionHistory) {
            TransactionHistoryView(viewModel: viewModel)
        }
        .alert("Erfolg", isPresented: $viewModel.showSuccessMessage) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(viewModel.successMessage)
        }
        .task {
            await viewModel.loadWalletData()
        }
    }
    
    // MARK: - Balance Card
    
    private var balanceCard: some View {
        VStack(spacing: ResponsiveDesign.spacing(4)) {
            Text("Aktuelles Guthaben")
                .font(ResponsiveDesign.captionFont())
                .foregroundColor(AppTheme.secondaryText)
            
            Text(viewModel.formattedBalance)
                .font(ResponsiveDesign.largeTitleFont())
                .fontWeight(.bold)
                .foregroundColor(AppTheme.fontColor)
            
            // Demo Mode Badge
            HStack(spacing: ResponsiveDesign.spacing(2)) {
                Image(systemName: "info.circle.fill")
                    .font(ResponsiveDesign.captionFont())
                Text("Demo-Modus")
                    .font(ResponsiveDesign.captionFont())
            }
            .foregroundColor(AppTheme.accentOrange)
            .padding(.horizontal, ResponsiveDesign.spacing(3))
            .padding(.vertical, ResponsiveDesign.spacing(2))
            .background(AppTheme.accentOrange.opacity(0.1))
            .cornerRadius(ResponsiveDesign.spacing(3))
        }
        .frame(maxWidth: .infinity)
        .padding(ResponsiveDesign.spacing(6))
        .background(AppTheme.cardBackground)
        .cornerRadius(ResponsiveDesign.spacing(3))
    }
    
    // MARK: - Quick Actions
    
    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(4)) {
            Text("Schnellaktionen")
                .font(ResponsiveDesign.headlineFont())
                .foregroundColor(AppTheme.fontColor)
            
            HStack(spacing: ResponsiveDesign.spacing(4)) {
                // Deposit Button
                Button {
                    viewModel.showDepositSheet = true
                } label: {
                    VStack(spacing: ResponsiveDesign.spacing(2)) {
                        Image(systemName: "arrow.down.circle.fill")
                            .font(.system(size: ResponsiveDesign.iconSize()))
                            .foregroundColor(.white)
                        Text("Einzahlen")
                            .font(ResponsiveDesign.captionFont())
                            .foregroundColor(.white)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(ResponsiveDesign.spacing(4))
                    .background(AppTheme.accentGreen)
                    .cornerRadius(ResponsiveDesign.spacing(3))
                }
                
                // Withdrawal Button
                Button {
                    viewModel.showWithdrawalSheet = true
                } label: {
                    VStack(spacing: ResponsiveDesign.spacing(2)) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: ResponsiveDesign.iconSize()))
                            .foregroundColor(.white)
                        Text("Auszahlen")
                            .font(ResponsiveDesign.captionFont())
                            .foregroundColor(.white)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(ResponsiveDesign.spacing(4))
                    .background(AppTheme.accentRed)
                    .cornerRadius(ResponsiveDesign.spacing(3))
                }
            }
        }
    }
    
    // MARK: - Recent Transactions
    
    private var recentTransactionsSection: some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(4)) {
            HStack {
                Text("Letzte Transaktionen")
                    .font(ResponsiveDesign.headlineFont())
                    .foregroundColor(AppTheme.fontColor)
                
                Spacer()
                
                Button {
                    showTransactionHistory = true
                } label: {
                    Text("Alle anzeigen")
                        .font(ResponsiveDesign.captionFont())
                        .foregroundColor(AppTheme.accentLightBlue)
                }
            }
            
            if viewModel.transactions.isEmpty {
                emptyTransactionsView
            } else {
                ForEach(Array(viewModel.transactions.prefix(5))) { transaction in
                    WalletTransactionRow(transaction: transaction)
                        .transition(.opacity.combined(with: .move(edge: .trailing)))
                }
            }
        }
    }
    
    private var emptyTransactionsView: some View {
        VStack(spacing: ResponsiveDesign.spacing(4)) {
            Image(systemName: "tray")
                .font(.system(size: ResponsiveDesign.iconSize() * 2))
                .foregroundColor(AppTheme.secondaryText.opacity(0.6))
            Text("Noch keine Transaktionen")
                .font(ResponsiveDesign.bodyFont())
                .foregroundColor(AppTheme.secondaryText)
            Text("Ihre Transaktionen werden hier angezeigt")
                .font(ResponsiveDesign.captionFont())
                .foregroundColor(AppTheme.secondaryText.opacity(0.8))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(ResponsiveDesign.spacing(8))
        .background(AppTheme.cardBackground.opacity(0.5))
        .cornerRadius(ResponsiveDesign.spacing(3))
    }
    
    // MARK: - Deposit Sheet
    
    private var depositSheet: some View {
        NavigationStack {
            ZStack {
                AppTheme.screenBackground
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: ResponsiveDesign.spacing(6)) {
                        // Info Section
                        VStack(spacing: ResponsiveDesign.spacing(3)) {
                            Image(systemName: "arrow.down.circle.fill")
                                .font(.system(size: ResponsiveDesign.iconSize() * 2))
                                .foregroundColor(AppTheme.accentGreen)
                            
                            Text("Einzahlung")
                                .font(ResponsiveDesign.headlineFont())
                                .foregroundColor(AppTheme.fontColor)
                            
                            Text("Geben Sie den Betrag ein, den Sie einzahlen möchten")
                                .font(ResponsiveDesign.captionFont())
                                .foregroundColor(AppTheme.secondaryText)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.top, ResponsiveDesign.spacing(6))
                        
                        // Quick Amount Buttons
                        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(3)) {
                            Text("Schnellbeträge")
                                .font(ResponsiveDesign.captionFont())
                                .foregroundColor(AppTheme.secondaryText)
                            
                            LazyVGrid(columns: [
                                GridItem(.flexible()),
                                GridItem(.flexible()),
                                GridItem(.flexible()),
                                GridItem(.flexible())
                            ], spacing: ResponsiveDesign.spacing(3)) {
                                ForEach([50.0, 100.0, 500.0, 1000.0], id: \.self) { amount in
                                    Button {
                                        viewModel.depositAmount = String(format: "%.2f", amount)
                                    } label: {
                                        Text(amount.formatted(.currency(code: "EUR").precision(.fractionLength(0))))
                                            .font(ResponsiveDesign.captionFont())
                                            .fontWeight(.medium)
                                            .foregroundColor(viewModel.depositAmount == String(format: "%.2f", amount) ? .white : AppTheme.fontColor)
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, ResponsiveDesign.spacing(2))
                                            .background(
                                                viewModel.depositAmount == String(format: "%.2f", amount) ?
                                                AppTheme.accentLightBlue : AppTheme.cardBackground
                                            )
                                            .cornerRadius(ResponsiveDesign.spacing(2))
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, ResponsiveDesign.horizontalPadding())
                        
                        // Amount Input
                        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(2)) {
                            Text("Betrag")
                                .font(ResponsiveDesign.bodyFont())
                                .foregroundColor(AppTheme.fontColor)
                            
                            HStack {
                                Text("€")
                                    .font(ResponsiveDesign.bodyFont())
                                    .foregroundColor(AppTheme.secondaryText)
                                
                                TextField("0,00", text: $viewModel.depositAmount)
                                    .keyboardType(.decimalPad)
                                    .font(ResponsiveDesign.titleFont())
                                    .foregroundColor(AppTheme.fontColor)
                            }
                            .padding(ResponsiveDesign.spacing(4))
                            .background(AppTheme.cardBackground)
                            .cornerRadius(ResponsiveDesign.spacing(3))
                            
                            // Limits Info
                            HStack {
                                Text("Min: \(CalculationConstants.PaymentLimits.minimumDeposit.formatted(.currency(code: "EUR")))")
                                    .font(ResponsiveDesign.captionFont())
                                    .foregroundColor(AppTheme.secondaryText)
                                
                                Spacer()
                                
                                Text("Max: \(CalculationConstants.PaymentLimits.maximumDeposit.formatted(.currency(code: "EUR")))")
                                    .font(ResponsiveDesign.captionFont())
                                    .foregroundColor(AppTheme.secondaryText)
                            }
                        }
                        .padding(.horizontal, ResponsiveDesign.horizontalPadding())
                        
                        // Error Message
                        if let error = viewModel.errorMessage {
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(AppTheme.accentRed)
                                Text(error)
                                    .font(ResponsiveDesign.captionFont())
                                    .foregroundColor(AppTheme.accentRed)
                            }
                            .padding(.horizontal, ResponsiveDesign.horizontalPadding())
                        }
                        
                        // Deposit Button
                        Button {
                            Task {
                                await viewModel.deposit()
                            }
                        } label: {
                            HStack {
                                if viewModel.isLoading {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                } else {
                                    Text("Einzahlen")
                                        .font(ResponsiveDesign.bodyFont())
                                        .fontWeight(.semibold)
                                }
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(ResponsiveDesign.spacing(4))
                            .background(
                                (viewModel.isLoading || viewModel.depositAmount.isEmpty) ?
                                AppTheme.secondaryText : AppTheme.accentGreen
                            )
                            .cornerRadius(ResponsiveDesign.spacing(3))
                        }
                        .disabled(viewModel.isLoading || viewModel.depositAmount.isEmpty)
                        .padding(.horizontal, ResponsiveDesign.horizontalPadding())
                        
                        // Demo Mode Notice
                        VStack(spacing: ResponsiveDesign.spacing(2)) {
                            HStack {
                                Image(systemName: "info.circle.fill")
                                    .font(ResponsiveDesign.captionFont())
                                Text("Demo-Modus")
                                    .font(ResponsiveDesign.captionFont())
                                    .fontWeight(.semibold)
                            }
                            .foregroundColor(AppTheme.accentOrange)
                            
                            Text("Diese Einzahlung wird simuliert. Keine echten Zahlungen werden verarbeitet.")
                                .font(ResponsiveDesign.captionFont())
                                .foregroundColor(AppTheme.secondaryText)
                                .multilineTextAlignment(.center)
                        }
                        .padding(ResponsiveDesign.spacing(4))
                        .background(AppTheme.accentOrange.opacity(0.1))
                        .cornerRadius(ResponsiveDesign.spacing(3))
                        .padding(.horizontal, ResponsiveDesign.horizontalPadding())
                        
                        Spacer(minLength: ResponsiveDesign.spacing(8))
                    }
                }
            }
            .navigationTitle("Einzahlung")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Abbrechen") {
                        viewModel.showDepositSheet = false
                    }
                }
            }
        }
    }
    
    // MARK: - Withdrawal Sheet
    
    private var withdrawalSheet: some View {
        NavigationStack {
            ZStack {
                AppTheme.screenBackground
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: ResponsiveDesign.spacing(6)) {
                        // Info Section
                        VStack(spacing: ResponsiveDesign.spacing(3)) {
                            Image(systemName: "arrow.up.circle.fill")
                                .font(.system(size: ResponsiveDesign.iconSize() * 2))
                                .foregroundColor(AppTheme.accentRed)
                            
                            Text("Auszahlung")
                                .font(ResponsiveDesign.headlineFont())
                                .foregroundColor(AppTheme.fontColor)
                            
                            Text("Geben Sie den Betrag ein, den Sie auszahlen möchten")
                                .font(ResponsiveDesign.captionFont())
                                .foregroundColor(AppTheme.secondaryText)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.top, ResponsiveDesign.spacing(6))
                        
                        // Available Balance Card
                        VStack(spacing: ResponsiveDesign.spacing(2)) {
                            Text("Verfügbares Guthaben")
                                .font(ResponsiveDesign.captionFont())
                                .foregroundColor(AppTheme.secondaryText)
                            
                            Text(viewModel.formattedBalance)
                                .font(ResponsiveDesign.titleFont())
                                .fontWeight(.bold)
                                .foregroundColor(AppTheme.fontColor)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(ResponsiveDesign.spacing(4))
                        .background(AppTheme.cardBackground)
                        .cornerRadius(ResponsiveDesign.spacing(3))
                        .padding(.horizontal, ResponsiveDesign.horizontalPadding())
                        
                        // Quick Amount Buttons
                        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(3)) {
                            Text("Schnellbeträge")
                                .font(ResponsiveDesign.captionFont())
                                .foregroundColor(AppTheme.secondaryText)
                            
                            LazyVGrid(columns: [
                                GridItem(.flexible()),
                                GridItem(.flexible()),
                                GridItem(.flexible()),
                                GridItem(.flexible())
                            ], spacing: ResponsiveDesign.spacing(3)) {
                                ForEach([50.0, 100.0, 500.0, 1000.0], id: \.self) { amount in
                                    Button {
                                        let maxAmount = min(amount, viewModel.currentBalance)
                                        viewModel.withdrawalAmount = String(format: "%.2f", maxAmount)
                                    } label: {
                                        Text(amount.formatted(.currency(code: "EUR").precision(.fractionLength(0))))
                                            .font(ResponsiveDesign.captionFont())
                                            .fontWeight(.medium)
                                            .foregroundColor(viewModel.withdrawalAmount == String(format: "%.2f", amount) ? .white : AppTheme.fontColor)
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, ResponsiveDesign.spacing(2))
                                            .background(
                                                viewModel.withdrawalAmount == String(format: "%.2f", amount) ?
                                                AppTheme.accentLightBlue : AppTheme.cardBackground
                                            )
                                            .cornerRadius(ResponsiveDesign.spacing(2))
                                    }
                                    .disabled(amount > viewModel.currentBalance)
                                    .opacity(amount > viewModel.currentBalance ? 0.5 : 1.0)
                                }
                            }
                        }
                        .padding(.horizontal, ResponsiveDesign.horizontalPadding())
                        
                        // Amount Input
                        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(2)) {
                            Text("Betrag")
                                .font(ResponsiveDesign.bodyFont())
                                .foregroundColor(AppTheme.fontColor)
                            
                            HStack {
                                Text("€")
                                    .font(ResponsiveDesign.bodyFont())
                                    .foregroundColor(AppTheme.secondaryText)
                                
                                TextField("0,00", text: $viewModel.withdrawalAmount)
                                    .keyboardType(.decimalPad)
                                    .font(ResponsiveDesign.titleFont())
                                    .foregroundColor(AppTheme.fontColor)
                            }
                            .padding(ResponsiveDesign.spacing(4))
                            .background(AppTheme.cardBackground)
                            .cornerRadius(ResponsiveDesign.spacing(3))
                            
                            // Limits Info
                            HStack {
                                Text("Min: \(CalculationConstants.PaymentLimits.minimumWithdrawal.formatted(.currency(code: "EUR")))")
                                    .font(ResponsiveDesign.captionFont())
                                    .foregroundColor(AppTheme.secondaryText)
                                
                                Spacer()
                                
                                Text("Max: \(CalculationConstants.PaymentLimits.maximumWithdrawal.formatted(.currency(code: "EUR")))")
                                    .font(ResponsiveDesign.captionFont())
                                    .foregroundColor(AppTheme.secondaryText)
                            }
                        }
                        .padding(.horizontal, ResponsiveDesign.horizontalPadding())
                        
                        // Error Message
                        if let error = viewModel.errorMessage {
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(AppTheme.accentRed)
                                Text(error)
                                    .font(ResponsiveDesign.captionFont())
                                    .foregroundColor(AppTheme.accentRed)
                            }
                            .padding(.horizontal, ResponsiveDesign.horizontalPadding())
                        }
                        
                        // Withdrawal Button
                        Button {
                            Task {
                                await viewModel.withdraw()
                            }
                        } label: {
                            HStack {
                                if viewModel.isLoading {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                } else {
                                    Text("Auszahlen")
                                        .font(ResponsiveDesign.bodyFont())
                                        .fontWeight(.semibold)
                                }
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(ResponsiveDesign.spacing(4))
                            .background(
                                (viewModel.isLoading || viewModel.withdrawalAmount.isEmpty) ?
                                AppTheme.secondaryText : AppTheme.accentRed
                            )
                            .cornerRadius(ResponsiveDesign.spacing(3))
                        }
                        .disabled(viewModel.isLoading || viewModel.withdrawalAmount.isEmpty)
                        .padding(.horizontal, ResponsiveDesign.horizontalPadding())
                        
                        // Demo Mode Notice
                        VStack(spacing: ResponsiveDesign.spacing(2)) {
                            HStack {
                                Image(systemName: "info.circle.fill")
                                    .font(ResponsiveDesign.captionFont())
                                Text("Demo-Modus")
                                    .font(ResponsiveDesign.captionFont())
                                    .fontWeight(.semibold)
                            }
                            .foregroundColor(AppTheme.accentOrange)
                            
                            Text("Diese Auszahlung wird simuliert. Keine echten Zahlungen werden verarbeitet.")
                                .font(ResponsiveDesign.captionFont())
                                .foregroundColor(AppTheme.secondaryText)
                                .multilineTextAlignment(.center)
                        }
                        .padding(ResponsiveDesign.spacing(4))
                        .background(AppTheme.accentOrange.opacity(0.1))
                        .cornerRadius(ResponsiveDesign.spacing(3))
                        .padding(.horizontal, ResponsiveDesign.horizontalPadding())
                        
                        Spacer(minLength: ResponsiveDesign.spacing(8))
                    }
                }
            }
            .navigationTitle("Auszahlung")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Abbrechen") {
                        viewModel.showWithdrawalSheet = false
                    }
                }
            }
        }
    }
}

// MARK: - Wallet Transaction Row

struct WalletTransactionRow: View {
    let transaction: Transaction
    
    var body: some View {
        HStack(spacing: ResponsiveDesign.spacing(4)) {
            // Icon
            Image(systemName: transaction.type.icon)
                .font(.system(size: ResponsiveDesign.iconSize()))
                .foregroundColor(colorForType(transaction.type))
                .frame(width: ResponsiveDesign.spacing(8), height: ResponsiveDesign.spacing(8))
                .background(colorForType(transaction.type).opacity(0.1))
                .cornerRadius(ResponsiveDesign.spacing(3))
            
            // Details
            VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(2)) {
                Text(transaction.type.displayName)
                    .font(ResponsiveDesign.bodyFont())
                    .foregroundColor(AppTheme.fontColor)
                
                if let description = transaction.description {
                    Text(description)
                        .font(ResponsiveDesign.captionFont())
                        .foregroundColor(AppTheme.secondaryText)
                }
                
                Text(transaction.timestamp.formatted(date: .abbreviated, time: .shortened))
                    .font(ResponsiveDesign.captionFont())
                    .foregroundColor(AppTheme.secondaryText)
            }
            
            Spacer()
            
            // Amount
            Text(transaction.formattedSignedAmount)
                .font(ResponsiveDesign.bodyFont())
                .fontWeight(.semibold)
                .foregroundColor(transaction.isPositive ? AppTheme.accentGreen : AppTheme.accentRed)
        }
        .padding(ResponsiveDesign.spacing(4))
        .background(AppTheme.cardBackground)
        .cornerRadius(ResponsiveDesign.spacing(3))
    }
    
    private func colorForType(_ type: Transaction.TransactionType) -> Color {
        switch type.color {
        case "green": return AppTheme.accentGreen
        case "red": return AppTheme.accentRed
        case "blue": return AppTheme.accentLightBlue
        case "orange": return AppTheme.accentOrange
        default: return AppTheme.secondaryText
        }
    }
}

// Preview removed to avoid build errors - use actual app navigation instead
