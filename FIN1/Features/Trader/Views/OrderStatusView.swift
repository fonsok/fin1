import SwiftUI

struct OrderStatusView: View {
    @ObservedObject var viewModel: BuyOrderViewModel
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var tabRouter: TabRouter

    var body: some View {
        ZStack {
            Color("ScreenBackground").ignoresSafeArea()

            VStack(spacing: ResponsiveDesign.spacing(20)) {
                switch viewModel.orderStatus {
                case .transmitting:
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(2)
                    Text("Order wird übermittelt...")
                        .font(ResponsiveDesign.headlineFont())
                        .foregroundColor(AppTheme.fontColor)
                case .orderPlaced(let executedPrice, let finalCost):
                    orderPlacedView(executedPrice: executedPrice, finalCost: finalCost)
                case .failed(let error):
                    failureView(error: error)
                case .idle:
                    EmptyView()
                }
            }
            .padding(.horizontal, ResponsiveDesign.spacing(20))
            .padding(.vertical, ResponsiveDesign.spacing(40))
        }
    }

    private func isSuccess(status: BuyOrderStatus) -> Bool {
        if case .orderPlaced = status {
            return true
        }
        return false
    }

    @ViewBuilder
    private func failureView(error: AppError) -> some View {
        VStack(spacing: ResponsiveDesign.spacing(20)) {
            Image(systemName: "xmark.circle.fill")
                .font(ResponsiveDesign.scaledSystemFont(size: 60))
                .foregroundColor(.red)
            Text("Kauf fehlgeschlagen")
                .font(ResponsiveDesign.titleFont())

            Text(error.localizedDescription)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)

            Spacer()

            Button(action: {
                dismiss()
            }) {
                Text(error.localizedDescription.contains("Preis hat sich geändert") ? "Neue Kauf-Order" : "Schließen")
                    .fontWeight(.bold)
                    .foregroundColor(AppTheme.fontColor)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.accentColor)
                    .cornerRadius(ResponsiveDesign.spacing(10))
            }
        }
        .foregroundColor(AppTheme.fontColor)
    }

    @ViewBuilder
    private func orderPlacedView(executedPrice: Double, finalCost: Double) -> some View {
        VStack(spacing: ResponsiveDesign.spacing(20)) {
            Image(systemName: "checkmark.circle.fill")
                .font(ResponsiveDesign.scaledSystemFont(size: 60))
                .foregroundColor(.green)
            Text("ORDER ÜBERMITTELT")
                .font(ResponsiveDesign.titleFont())
                .fontWeight(.bold)
            Text("Ihre Order wurde erfolgreich übermittelt und erscheint nun in den laufenden Transaktionen.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)

            VStack(alignment: .leading, spacing: 8) {
                Text(viewModel.searchResult.underlyingAsset ?? "N/A")
                    .font(ResponsiveDesign.bodyFont())
                Text("Typ: \(viewModel.searchResult.category ?? (viewModel.searchResult.direction ?? "Stock"))")
                Text("WKN: \(viewModel.searchResult.wkn)")
                Text("ISIN: \(viewModel.searchResult.isin)")
            }
            .padding(.horizontal)

            VStack(alignment: .leading, spacing: 12) {
                Text("Order: Kauf \(viewModel.formattedQuantity) Stück des Wertpapiers WKN \(viewModel.searchResult.wkn) zum Kurs \(viewModel.formattedPrice(executedPrice))")
                Text("Der Status Ihrer Order wird automatisch aktualisiert.")
                Text("Bitte prüfen Sie Ihren Depotbestand für weitere Updates.")
            }
            .padding()
            .background(Color("SectionBackground"))
            .cornerRadius(ResponsiveDesign.spacing(8))
            .padding(.horizontal)

            Spacer()

            Button(action: {
                tabRouter.selectedTab = 2 // Navigate to Depot tab
                dismiss()
            }) {
                Text("Zum Depot")
                    .fontWeight(.bold)
                    .foregroundColor(AppTheme.fontColor)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color("AccentGreen"))
                    .cornerRadius(ResponsiveDesign.spacing(10))
            }
        }
        .foregroundColor(AppTheme.fontColor)
        .padding(.top, 40)
    }

    @ViewBuilder
    private func successView(executedPrice: Double, finalCost: Double) -> some View {
        VStack(spacing: ResponsiveDesign.spacing(20)) {
            Image(systemName: "checkmark.circle.fill")
                .font(ResponsiveDesign.scaledSystemFont(size: 60))
                .foregroundColor(.green)
            Text("KAUFBESTÄTIGUNG")
                .font(ResponsiveDesign.titleFont())
                .fontWeight(.bold)
            Text("über")
                .font(ResponsiveDesign.headlineFont())

            VStack(alignment: .leading, spacing: 8) {
                Text(viewModel.searchResult.underlyingAsset ?? "N/A")
                    .font(ResponsiveDesign.bodyFont())
                Text("Typ: \(viewModel.searchResult.category ?? (viewModel.searchResult.direction ?? "Stock"))")
                Text("WKN: \(viewModel.searchResult.wkn)")
                Text("ISIN: \(viewModel.searchResult.isin)")
            }
            .padding(.horizontal)

            VStack(alignment: .leading, spacing: 12) {
                let quantity = Int(viewModel.quantity)
                Text("Die Order Kauf \(viewModel.formattedNumber(quantity)) Stück des Wertpapiers WKN \(viewModel.searchResult.wkn) wurde zum Kurs \(viewModel.formattedPrice(executedPrice)) ausgeführt.")
                Text("Ihr Cashkonto wurde mit dem Betrag von \(viewModel.formattedCost(finalCost)) belastet.")
                Text("Bitte prüfen Sie Ihren Depotbestand.")
            }
            .padding()
            .background(Color("SectionBackground"))
            .cornerRadius(ResponsiveDesign.spacing(8))
            .padding(.horizontal)

            Spacer()

            Button(action: {
                tabRouter.selectedTab = 2 // Navigate to Depot tab
                dismiss()
            }) {
                Text("weiter")
                    .fontWeight(.bold)
                    .foregroundColor(AppTheme.fontColor)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color("AccentGreen"))
                    .cornerRadius(ResponsiveDesign.spacing(10))
            }
        }
        .foregroundColor(AppTheme.fontColor)
        .padding(.top, 40)
    }
}
