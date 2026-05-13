import SwiftUI

// MARK: - Create Price Alert View
/// View for creating a new price alert
struct CreatePriceAlertView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: CreatePriceAlertViewModel
    @State private var selectedAlertType: PriceAlertType = .above
    @State private var symbol: String = ""
    @State private var thresholdPrice: String = ""
    @State private var thresholdChangePercent: String = ""
    @State private var notes: String = ""
    @State private var expiresAt: Date?
    @State private var hasExpiration: Bool = false
    
    init(priceAlertService: (any PriceAlertServiceProtocol)?) {
        _viewModel = StateObject(wrappedValue: CreatePriceAlertViewModel(priceAlertService: priceAlertService))
    }
    
    var body: some View {
        NavigationStack {
            Form {
                // Symbol Section
                Section("Symbol") {
                    TextField("Symbol (e.g., DAX, Apple)", text: self.$symbol)
                        .textInputAutocapitalization(.never)
                }
                
                // Alert Type Section
                Section("Alert Type") {
                    Picker("Type", selection: self.$selectedAlertType) {
                        Text("Above").tag(PriceAlertType.above)
                        Text("Below").tag(PriceAlertType.below)
                        Text("Change").tag(PriceAlertType.change)
                    }
                }
                
                // Threshold Section
                Section("Threshold") {
                    if self.selectedAlertType == .change {
                        TextField("Change Percentage", text: self.$thresholdChangePercent)
                            .keyboardType(.decimalPad)
                    } else {
                        TextField("Price (€)", text: self.$thresholdPrice)
                            .keyboardType(.decimalPad)
                    }
                }
                
                // Expiration Section
                Section("Expiration") {
                    Toggle("Set Expiration", isOn: self.$hasExpiration)
                    
                    if self.hasExpiration {
                        DatePicker("Expires At", selection: Binding(
                            get: { self.expiresAt ?? Date().addingTimeInterval(86_400 * 7) },
                            set: { self.expiresAt = $0 }
                        ), displayedComponents: [.date, .hourAndMinute])
                    }
                }
                
                // Notes Section
                Section("Notes (Optional)") {
                    TextField("Add notes...", text: self.$notes, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle("Create Alert")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        self.dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Create") {
                        Task { @MainActor in
                            await self.createAlert()
                        }
                    }
                    .disabled(!self.isValid)
                }
            }
        }
    }
    
    private var isValid: Bool {
        guard !self.symbol.isEmpty else { return false }
        
        switch self.selectedAlertType {
        case .above, .below:
            return !self.thresholdPrice.isEmpty && Double(self.thresholdPrice) != nil
        case .change:
            return !self.thresholdChangePercent.isEmpty && Double(self.thresholdChangePercent) != nil
        }
    }
    
    private func createAlert() async {
        let price = Double(thresholdPrice)
        let changePercent = Double(thresholdChangePercent)
        
        do {
            _ = try await self.viewModel.createAlert(
                symbol: self.symbol,
                alertType: self.selectedAlertType,
                thresholdPrice: price,
                thresholdChangePercent: changePercent,
                expiresAt: self.hasExpiration ? self.expiresAt : nil,
                notes: self.notes.isEmpty ? nil : self.notes
            )
            self.dismiss()
        } catch {
            // Handle error (could show alert)
            print("Error creating alert: \(error.localizedDescription)")
        }
    }
}

// MARK: - Create Price Alert ViewModel
@MainActor
final class CreatePriceAlertViewModel: ObservableObject {
    private let priceAlertService: (any PriceAlertServiceProtocol)?
    
    init(priceAlertService: (any PriceAlertServiceProtocol)?) {
        self.priceAlertService = priceAlertService
    }
    
    func createAlert(
        symbol: String,
        alertType: PriceAlertType,
        thresholdPrice: Double?,
        thresholdChangePercent: Double?,
        expiresAt: Date?,
        notes: String?
    ) async throws -> PriceAlert {
        return try await self.priceAlertService?.createAlert(
            symbol: symbol,
            alertType: alertType,
            thresholdPrice: thresholdPrice,
            thresholdChangePercent: thresholdChangePercent,
            expiresAt: expiresAt,
            notes: notes
        ) ?? PriceAlert(
            from: ParsePriceAlert(
                userId: "",
                symbol: symbol,
                alertType: alertType,
                thresholdPrice: thresholdPrice,
                thresholdChangePercent: thresholdChangePercent,
                expiresAt: expiresAt,
                notes: notes
            )
        )
    }
}
