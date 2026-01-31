import SwiftUI

// MARK: - Transaction Info Row Component
/// Displays transaction type and comprehensive securities information
struct TransactionInfoRow: View {
    let transactionType: TransactionType
    let wkn: String
    let richtung: String?
    let basiswert: String?
    let emittent: String?

    var body: some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(4)) {
            HStack {
                Text(transactionType.displayName)
                    .font(ResponsiveDesign.bodyFont())
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)

                Text("Wertpapier")
                    .font(ResponsiveDesign.bodyFont())
                    .foregroundColor(.primary)

                Spacer()
            }
            // Detailed description row removed as requested
        }
        .padding(.vertical, ResponsiveDesign.spacing(8))
        .padding(.horizontal, ResponsiveDesign.spacing(12))
        .background(
            RoundedRectangle(cornerRadius: ResponsiveDesign.spacing(8))
                .fill(Color(.systemGray6))
        )
    }

    private func formatSecuritiesInfo() -> String {
        var components: [String] = []

        // Add WKN/ISIN first
        components.append(wkn)

        // Add Richtung if available
        if let richtung = richtung, !richtung.isEmpty {
            components.append(richtung)
        }

        // Add Basiswert if available
        if let basiswert = basiswert, !basiswert.isEmpty {
            components.append(basiswert)
        }

        // Add Emittent if available
        if let emittent = emittent, !emittent.isEmpty {
            components.append(emittent)
        }

        return components.joined(separator: "|")
    }
}

// MARK: - Preview
#Preview {
    TransactionInfoRow(
        transactionType: .buy,
        wkn: "AAPL123",
        richtung: "CALL",
        basiswert: "Apple Inc.",
        emittent: "Goldman Sachs"
    )
    .responsivePadding()
}
