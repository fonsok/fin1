import SwiftUI

// MARK: - Transaction Detail View
/// Detailed view for a single transaction
struct TransactionDetailView: View {
    let transaction: Transaction
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.screenBackground
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: ResponsiveDesign.spacing(6)) {
                        // Header Card
                        headerCard
                        
                        // Details Section
                        detailsSection
                        
                        // Status Section
                        statusSection
                        
                        // Metadata Section (if available)
                        if !transaction.metadata.isEmpty {
                            metadataSection
                        }
                    }
                    .padding(.horizontal, ResponsiveDesign.horizontalPadding())
                    .padding(.top, ResponsiveDesign.spacing(8))
                }
            }
            .navigationTitle("Transaktionsdetails")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Fertig") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    // MARK: - Header Card
    
    private var headerCard: some View {
        VStack(spacing: ResponsiveDesign.spacing(4)) {
            // Icon
            Image(systemName: transaction.type.icon)
                .font(ResponsiveDesign.scaledSystemFont(size: ResponsiveDesign.iconSize() * 2.5))
                .foregroundColor(colorForType(transaction.type))
                .frame(width: ResponsiveDesign.spacing(16), height: ResponsiveDesign.spacing(16))
                .background(colorForType(transaction.type).opacity(0.1))
                .clipShape(Circle())
            
            // Type
            Text(transaction.type.displayName)
                .font(ResponsiveDesign.headlineFont())
                .foregroundColor(AppTheme.fontColor)
            
            // Amount
            Text(transaction.formattedSignedAmount)
                .font(ResponsiveDesign.largeTitleFont())
                .fontWeight(.bold)
                .foregroundColor(transaction.isPositive ? AppTheme.accentGreen : AppTheme.accentRed)
        }
        .frame(maxWidth: .infinity)
        .padding(ResponsiveDesign.spacing(6))
        .background(AppTheme.cardBackground)
        .cornerRadius(ResponsiveDesign.spacing(3))
    }
    
    // MARK: - Details Section
    
    private var detailsSection: some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(4)) {
            Text("Details")
                .font(ResponsiveDesign.headlineFont())
                .foregroundColor(AppTheme.fontColor)
            
            DetailRow(label: "Datum", value: transaction.timestamp.formatted(date: .long, time: .shortened))
            DetailRow(label: "Status", value: transaction.status.displayName)
            DetailRow(label: "Betrag", value: transaction.amount.formatted(.currency(code: transaction.currency)))
            
            if let description = transaction.description {
                DetailRow(label: "Beschreibung", value: description)
            }
            
            if let reference = transaction.reference {
                DetailRow(label: "Referenz", value: reference)
            }
            
            if let balanceAfter = transaction.balanceAfter {
                DetailRow(label: "Guthaben danach", value: balanceAfter.formatted(.currency(code: transaction.currency)))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(ResponsiveDesign.spacing(4))
        .background(AppTheme.cardBackground)
        .cornerRadius(ResponsiveDesign.spacing(3))
    }
    
    // MARK: - Status Section
    
    private var statusSection: some View {
        HStack {
            StatusBadge(status: transaction.status)
            Spacer()
        }
        .padding(ResponsiveDesign.spacing(4))
        .background(AppTheme.cardBackground)
        .cornerRadius(ResponsiveDesign.spacing(3))
    }
    
    // MARK: - Metadata Section
    
    private var metadataSection: some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(4)) {
            Text("Zusätzliche Informationen")
                .font(ResponsiveDesign.headlineFont())
                .foregroundColor(AppTheme.fontColor)
            
            ForEach(Array(transaction.metadata.keys.sorted()), id: \.self) { key in
                if let value = transaction.metadata[key] {
                    DetailRow(label: key.capitalized, value: value)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(ResponsiveDesign.spacing(4))
        .background(AppTheme.cardBackground)
        .cornerRadius(ResponsiveDesign.spacing(3))
    }
    
    // MARK: - Helper Methods
    
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

// MARK: - Detail Row

struct DetailRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(ResponsiveDesign.bodyFont())
                .foregroundColor(AppTheme.secondaryText)
            Spacer()
            Text(value)
                .font(ResponsiveDesign.bodyFont())
                .fontWeight(.medium)
                .foregroundColor(AppTheme.fontColor)
                .multilineTextAlignment(.trailing)
        }
    }
}

// MARK: - Status Badge

struct StatusBadge: View {
    let status: Transaction.TransactionStatus
    
    var body: some View {
        HStack(spacing: ResponsiveDesign.spacing(2)) {
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)
            Text(status.displayName)
                .font(ResponsiveDesign.captionFont())
                .fontWeight(.medium)
                .foregroundColor(statusColor)
        }
        .padding(.horizontal, ResponsiveDesign.spacing(3))
        .padding(.vertical, ResponsiveDesign.spacing(2))
        .background(statusColor.opacity(0.1))
        .cornerRadius(ResponsiveDesign.spacing(3))
    }
    
    private var statusColor: Color {
        switch status {
        case .completed: return AppTheme.accentGreen
        case .pending, .processing: return AppTheme.accentOrange
        case .failed: return AppTheme.accentRed
        case .cancelled: return AppTheme.secondaryText
        }
    }
}
