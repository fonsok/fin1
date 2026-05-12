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
                    TextField("Symbol (e.g., DAX, Apple)", text: $symbol)
                        .textInputAutocapitalization(.never)
                }
                
                // Alert Type Section
                Section("Alert Type") {
                    Picker("Type", selection: $selectedAlertType) {
                        Text("Above").tag(PriceAlertType.above)
                        Text("Below").tag(PriceAlertType.below)
                        Text("Change").tag(PriceAlertType.change)
                    }
                }
                
                // Threshold Section
                Section("Threshold") {
                    if selectedAlertType == .change {
                        TextField("Change Percentage", text: $thresholdChangePercent)
                            .keyboardType(.decimalPad)
                    } else {
                        TextField("Price (€)", text: $thresholdPrice)
                            .keyboardType(.decimalPad)
                    }
                }
                
                // Expiration Section
                Section("Expiration") {
                    Toggle("Set Expiration", isOn: $hasExpiration)
                    
                    if hasExpiration {
                        DatePicker("Expires At", selection: Binding(
                            get: { expiresAt ?? Date().addingTimeInterval(86400 * 7) },
                            set: { expiresAt = $0 }
                        ), displayedComponents: [.date, .hourAndMinute])
                    }
                }
                
                // Notes Section
                Section("Notes (Optional)") {
                    TextField("Add notes...", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle("Create Alert")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Create") {
                        Task { @MainActor in
                            await createAlert()
                        }
                    }
                    .disabled(!isValid)
                }
            }
        }
    }
    
    private var isValid: Bool {
        guard !symbol.isEmpty else { return false }
        
        switch selectedAlertType {
        case .above, .below:
            return !thresholdPrice.isEmpty && Double(thresholdPrice) != nil
        case .change:
            return !thresholdChangePercent.isEmpty && Double(thresholdChangePercent) != nil
        }
    }
    
    private func createAlert() async {
        let price = Double(thresholdPrice)
        let changePercent = Double(thresholdChangePercent)
        
        do {
            _ = try await viewModel.createAlert(
                symbol: symbol,
                alertType: selectedAlertType,
                thresholdPrice: price,
                thresholdChangePercent: changePercent,
                expiresAt: hasExpiration ? expiresAt : nil,
                notes: notes.isEmpty ? nil : notes
            )
            dismiss()
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
        return try await priceAlertService?.createAlert(
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
