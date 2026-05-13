import SwiftUI

// MARK: - Price Alert Detail View
/// View for displaying price alert details
struct PriceAlertDetailView: View {
    @Environment(\.dismiss) private var dismiss
    let alert: PriceAlert
    let priceAlertService: (any PriceAlertServiceProtocol)?
    @State private var showDeleteConfirmation = false
    
    var body: some View {
        NavigationStack {
            Form {
                // Symbol Section
                Section("Symbol") {
                    Text(self.alert.symbol)
                        .font(ResponsiveDesign.bodyFont())
                }
                
                // Alert Type Section
                Section("Alert Type") {
                    Text(self.alertTypeDescription)
                        .font(ResponsiveDesign.bodyFont())
                }
                
                // Threshold Section
                Section("Threshold") {
                    if let thresholdPrice = alert.thresholdPrice {
                        Text("€\(thresholdPrice, specifier: "%.2f")")
                            .font(ResponsiveDesign.bodyFont())
                    }
                    
                    if let thresholdChange = alert.thresholdChangePercent {
                        Text("\(thresholdChange, specifier: "%.2f")%")
                            .font(ResponsiveDesign.bodyFont())
                    }
                }
                
                // Status Section
                Section("Status") {
                    HStack {
                        Text("Status")
                        Spacer()
                        Text(self.alert.status.rawValue.capitalized)
                            .foregroundColor(self.statusColor)
                    }
                    
                    if self.alert.isEnabled {
                        Text("Enabled")
                            .foregroundColor(AppTheme.accentGreen)
                    } else {
                        Text("Disabled")
                            .foregroundColor(AppTheme.secondaryText)
                    }
                }
                
                // Dates Section
                Section("Dates") {
                    HStack {
                        Text("Created")
                        Spacer()
                        Text(self.alert.createdAt, style: .date)
                            .foregroundColor(AppTheme.secondaryText)
                    }
                    
                    if let triggeredAt = alert.triggeredAt {
                        HStack {
                            Text("Triggered")
                            Spacer()
                            Text(triggeredAt, style: .date)
                                .foregroundColor(AppTheme.accentRed)
                        }
                    }
                    
                    if let expiresAt = alert.expiresAt {
                        HStack {
                            Text("Expires")
                            Spacer()
                            Text(expiresAt, style: .date)
                                .foregroundColor(AppTheme.secondaryText)
                        }
                    }
                }
                
                // Notes Section
                if let notes = alert.notes, !notes.isEmpty {
                    Section("Notes") {
                        Text(notes)
                            .font(ResponsiveDesign.bodyFont())
                    }
                }
                
                // Actions Section
                Section {
                    Button(role: .destructive, action: {
                        self.showDeleteConfirmation = true
                    }) {
                        HStack {
                            Spacer()
                            Text("Delete Alert")
                            Spacer()
                        }
                    }
                }
            }
            .navigationTitle("Alert Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        self.dismiss()
                    }
                }
            }
            .alert("Delete Alert", isPresented: self.$showDeleteConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    Task {
                        try? await self.priceAlertService?.deleteAlert(self.alert.id)
                        self.dismiss()
                    }
                }
            } message: {
                Text("Are you sure you want to delete this price alert?")
            }
        }
    }
    
    private var alertTypeDescription: String {
        switch self.alert.alertType {
        case .above:
            return "Alert when price goes above threshold"
        case .below:
            return "Alert when price goes below threshold"
        case .change:
            return "Alert when price changes"
        }
    }
    
    private var statusColor: Color {
        switch self.alert.status {
        case .active:
            return AppTheme.accentGreen
        case .triggered:
            return AppTheme.accentRed
        case .cancelled:
            return AppTheme.secondaryText
        case .expired:
            return AppTheme.secondaryText
        }
    }
}
