import SwiftUI

// MARK: - Invoice Items Section
/// Displays the invoice items table with header and rows
struct InvoiceItemsSection: View {
    let invoice: Invoice

    var body: some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(12)) {
            // Transaction Type Info Row (header only, detailed description removed)
            if let transactionType = invoice.transactionType {
                TransactionInfoRow(
                    transactionType: transactionType,
                    wkn: self.extractWKNFromInvoice(),
                    richtung: self.extractRichtungFromInvoice(),
                    basiswert: self.extractBasiswertFromInvoice(),
                    emittent: self.extractEmittentFromInvoice()
                )
            }

            Text("Rechnungspositionen")
                .font(ResponsiveDesign.headlineFont())
                .fontWeight(.semibold)

            VStack(spacing: ResponsiveDesign.spacing(0)) {
                // Table Header
                InvoiceItemsTableHeader(invoice: self.invoice)

                // Table Rows
                ForEach(self.invoice.items) { item in
                    InvoiceItemRowView(item: item)
                }
            }
            .background(
                RoundedRectangle(cornerRadius: ResponsiveDesign.spacing(8))
                    .fill(Color(.systemBackground))
                    .shadow(color: .black.opacity(0.05), radius: 1, x: 0, y: 1)
            )
        }
    }

    // MARK: - Helper Methods

    private func extractWKNFromInvoice() -> String {
        // Extract WKN from the first securities item description
        for item in self.invoice.items {
            if item.itemType == .securities {
                let description = item.description
                // New format: Richtung|Basiswert|WKN/ISIN
                let components = description.components(separatedBy: "|")
                if components.count >= 3 {
                    return components[2] // WKN is the third component
                } else if components.count == 2 {
                    // If only 2 components, we don't have WKN in the description
                    // We need to extract it from the invoice's orderId or other sources
                    // For now, return "N/A" and let the extraction methods handle it
                    return "N/A"
                }
                // Fallback: Look for WKN pattern in old format
                if let wknRange = description.range(of: "WKN: ") {
                    let wknStart = wknRange.upperBound
                    let wknEnd = description.index(wknStart, offsetBy: 6) // WKN is typically 6 characters
                    if wknEnd <= description.endIndex {
                        return String(description[wknStart..<wknEnd])
                    }
                }
            }
        }
        return "N/A"
    }

    private func extractRichtungFromInvoice() -> String? {
        // Extract Richtung from the first securities item description
        for item in self.invoice.items {
            if item.itemType == .securities {
                let description = item.description
                // New format: Richtung|Basiswert|WKN/ISIN
                let components = description.components(separatedBy: "|")
                if components.count >= 1 && !components[0].isEmpty {
                    return components[0] // Richtung is the first component
                }
                // Fallback: Look for Richtung pattern like "(CALL)" or "(PUT)"
                if let richtungRange = description.range(of: "(") {
                    let richtungStart = richtungRange.upperBound
                    if let richtungEnd = description.range(of: ")", range: richtungStart..<description.endIndex) {
                        let richtung = String(description[richtungStart..<richtungEnd.upperBound])
                        if richtung.contains("CALL") || richtung.contains("PUT") {
                            return richtung.replacingOccurrences(of: ")", with: "")
                        }
                    }
                }
            }
        }
        return nil
    }

    private func extractBasiswertFromInvoice() -> String? {
        // Extract Basiswert from the first securities item description
        for item in self.invoice.items {
            if item.itemType == .securities {
                let description = item.description
                // New format: Richtung|Basiswert|WKN/ISIN
                let components = description.components(separatedBy: "|")
                if components.count >= 2 && !components[1].isEmpty {
                    return components[1] // Basiswert is the second component
                }
                // Fallback: Look for Basiswert pattern like "DAX" or "Apple Inc."
                // This is typically the first part before any parentheses
                let fallbackComponents = description.components(separatedBy: " (")
                if let firstComponent = fallbackComponents.first {
                    let basiswert = firstComponent.trimmingCharacters(in: .whitespaces)
                    if !basiswert.isEmpty && !basiswert.contains("WKN:") {
                        return basiswert
                    }
                }
            }
        }
        return nil
    }

    private func extractEmittentFromInvoice() -> String? {
        // Extract Emittent from WKN using the same logic as in confirmation views
        let wkn = self.extractWKNFromInvoice()
        if wkn != "N/A" {
            return self.getEmittentFromWKN(wkn)
        }
        return nil
    }

    private func getEmittentFromWKN(_ wkn: String) -> String {
        let issuerCode = String(wkn.prefix(2))
        switch issuerCode {
        case "SG": return "Société Générale"
        case "DB": return "Deutsche Bank"
        case "VT": return "Volksbank"
        case "DZ": return "DZ Bank"
        case "BN": return "BNP Paribas"
        case "CI": return "Citigroup"
        case "GS": return "Goldman Sachs"
        case "HS": return "HSBC"
        case "JP": return "J.P. Morgan"
        case "MS": return "Morgan Stanley"
        case "UB": return "UBS"
        case "VO": return "Vontobel"
        case "AAPL", "TSLA", "MSFT", "GOOGL": return "US Stock"
        case "BMW", "DAX": return "German Stock"
        default: return "Unknown"
        }
    }
}

// MARK: - Invoice Items Table Header
/// Table header for invoice items
struct InvoiceItemsTableHeader: View {
    let invoice: Invoice

    var body: some View {
        HStack(spacing: ResponsiveDesign.spacing(8)) {
            Text("Beschreibung")
                .font(ResponsiveDesign.captionFont())
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            // Only show Stück and Preis columns if there are securities items
            if self.hasSecuritiesItems {
                Text("Stück")
                    .font(ResponsiveDesign.captionFont())
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
                    .frame(minWidth: 50, alignment: .trailing)

                Text("Preis")
                    .font(ResponsiveDesign.captionFont())
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
                    .frame(minWidth: 60, alignment: .trailing)
            }

            Text("Gesamt")
                .font(ResponsiveDesign.captionFont())
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
                .frame(minWidth: 80, alignment: .trailing)
        }
        .padding(.vertical, ResponsiveDesign.spacing(6))
        .padding(.horizontal, ResponsiveDesign.spacing(8))
        .background(Color(.systemGray6))
    }

    private var hasSecuritiesItems: Bool {
        self.invoice.items.contains { $0.itemType == .securities }
    }
}

// MARK: - Preview
#Preview {
    InvoiceItemsSection(invoice: Invoice.sampleInvoice())
        .responsivePadding()
}
