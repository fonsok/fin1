import SwiftUI

// MARK: - Transaction History View
/// Full transaction history view with filtering and search
struct TransactionHistoryView: View {
    @ObservedObject var viewModel: WalletViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedType: Transaction.TransactionType? = nil
    @State private var searchText: String = ""
    
    var filteredTransactions: [Transaction] {
        var filtered = self.viewModel.transactions
        
        // Filter by type
        if let selectedType = selectedType {
            filtered = filtered.filter { $0.type == selectedType }
        }
        
        // Filter by search text
        if !self.searchText.isEmpty {
            filtered = filtered.filter { transaction in
                transaction.type.displayName.localizedCaseInsensitiveContains(self.searchText) ||
                    transaction.description?.localizedCaseInsensitiveContains(self.searchText) ?? false ||
                    transaction.reference?.localizedCaseInsensitiveContains(self.searchText) ?? false
            }
        }
        
        return filtered
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.screenBackground
                    .ignoresSafeArea()
                
                VStack(spacing: ResponsiveDesign.spacing(4)) {
                    // Search and Filter
                    self.searchAndFilterSection
                    
                    // Transactions List
                    if self.filteredTransactions.isEmpty {
                        self.emptyStateView
                    } else {
                        self.transactionsList
                    }
                }
            }
            .navigationTitle("Transaktionshistorie")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Fertig") {
                        self.dismiss()
                    }
                }
            }
        }
    }
    
    // MARK: - Search and Filter
    
    private var searchAndFilterSection: some View {
        VStack(spacing: ResponsiveDesign.spacing(4)) {
            // Search Bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(AppTheme.secondaryText)
                TextField("Suchen...", text: self.$searchText)
                    .textFieldStyle(.plain)
            }
            .padding(ResponsiveDesign.spacing(3))
            .background(AppTheme.cardBackground)
            .cornerRadius(ResponsiveDesign.spacing(3))
            .padding(.horizontal, ResponsiveDesign.horizontalPadding())
            
            // Type Filter
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: ResponsiveDesign.spacing(3)) {
                    // All Types Button
                    TransactionFilterChip(
                        title: "Alle",
                        isSelected: self.selectedType == nil,
                        action: { self.selectedType = nil }
                    )
                    
                    // Type Buttons
                    ForEach(Transaction.TransactionType.allCases, id: \.self) { type in
                        TransactionFilterChip(
                            title: type.displayName,
                            isSelected: self.selectedType == type,
                            action: { self.selectedType = self.selectedType == type ? nil : type }
                        )
                    }
                }
                .padding(.horizontal, ResponsiveDesign.horizontalPadding())
            }
        }
        .padding(.top, ResponsiveDesign.spacing(4))
    }
    
    // MARK: - Transactions List
    
    @State private var selectedTransaction: Transaction?
    
    private var transactionsList: some View {
        ScrollView {
            LazyVStack(spacing: ResponsiveDesign.spacing(3)) {
                ForEach(self.groupedTransactions.keys.sorted(by: >), id: \.self) { date in
                    Section {
                        ForEach(self.groupedTransactions[date] ?? []) { transaction in
                            WalletTransactionRow(transaction: transaction)
                                .onTapGesture {
                                    self.selectedTransaction = transaction
                                }
                        }
                    } header: {
                        HStack {
                            Text(date.formatted(date: .abbreviated, time: .omitted))
                                .font(ResponsiveDesign.headlineFont())
                                .foregroundColor(AppTheme.fontColor)
                            Spacer()
                        }
                        .padding(.horizontal, ResponsiveDesign.horizontalPadding())
                        .padding(.vertical, ResponsiveDesign.spacing(2))
                    }
                }
            }
            .padding(.top, ResponsiveDesign.spacing(4))
        }
        .refreshable {
            Task {
                await self.viewModel.refresh()
            }
        }
        .sheet(item: self.$selectedTransaction) { transaction in
            TransactionDetailView(transaction: transaction)
        }
    }
    
    private var groupedTransactions: [Date: [Transaction]] {
        Dictionary(grouping: self.filteredTransactions) { transaction in
            Calendar.current.startOfDay(for: transaction.timestamp)
        }
    }
    
    // MARK: - Empty State
    
    private var emptyStateView: some View {
        VStack(spacing: ResponsiveDesign.spacing(4)) {
            Image(systemName: "tray")
                .font(ResponsiveDesign.scaledSystemFont(size: ResponsiveDesign.iconSize() * 2))
                .foregroundColor(AppTheme.secondaryText)
            Text("Keine Transaktionen gefunden")
                .font(ResponsiveDesign.headlineFont())
                .foregroundColor(AppTheme.fontColor)
            Text("Versuchen Sie, andere Filter zu verwenden")
                .font(ResponsiveDesign.captionFont())
                .foregroundColor(AppTheme.secondaryText)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Transaction Filter Chip

struct TransactionFilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: self.action) {
            Text(self.title)
                .font(ResponsiveDesign.captionFont())
                .foregroundColor(self.isSelected ? .white : AppTheme.fontColor)
                .padding(.horizontal, ResponsiveDesign.spacing(4))
                .padding(.vertical, ResponsiveDesign.spacing(2))
                .background(self.isSelected ? AppTheme.accentLightBlue : AppTheme.cardBackground)
                .cornerRadius(ResponsiveDesign.spacing(3))
        }
    }
}

// Preview removed to avoid build errors - use actual app navigation instead
