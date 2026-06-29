import SwiftUI

struct BuyOrderFailureSection: View {
    @ObservedObject var viewModel: BuyOrderViewModel

    var body: some View {
        if self.viewModel.hasOrderFailure, let message = viewModel.orderFailureMessage {
            VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(10)) {
                HStack {
                    Image(systemName: "xmark.octagon.fill")
                        .foregroundColor(.red)
                        .font(ResponsiveDesign.scaledSystemFont(size: ResponsiveDesign.iconSize()))
                    Text("Kauf fehlgeschlagen")
                        .font(ResponsiveDesign.headlineFont())
                        .foregroundColor(.red)
                }

                Text(message)
                    .font(ResponsiveDesign.bodyFont())
                    .foregroundColor(AppTheme.primaryText)
                    .multilineTextAlignment(.leading)

                Text("Ein erneuter Versuch startet mit einer neuen Auftragsreferenz.")
                    .font(ResponsiveDesign.captionFont())
                    .foregroundColor(AppTheme.secondaryText)
                    .multilineTextAlignment(.leading)

                Button {
                    self.viewModel.prepareForPlacement()
                    Task {
                        await self.viewModel.placeOrder()
                    }
                } label: {
                    Text("Erneut versuchen")
                        .font(ResponsiveDesign.bodyFont())
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, ResponsiveDesign.spacing(10))
                        .background(Color.red.opacity(0.15))
                        .cornerRadius(ResponsiveDesign.spacing(8))
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("BuyOrderRetryButton")

                Button {
                    self.viewModel.acknowledgeOrderFailure()
                } label: {
                    Text("Hinweis schließen")
                        .font(ResponsiveDesign.captionFont())
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, ResponsiveDesign.spacing(6))
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("BuyOrderFailureDismissButton")
            }
            .padding()
            .background(Color.red.opacity(0.08))
            .overlay(
                RoundedRectangle(cornerRadius: ResponsiveDesign.spacing(10))
                    .stroke(Color.red.opacity(0.35), lineWidth: 1)
            )
            .cornerRadius(ResponsiveDesign.spacing(10))
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Kauf fehlgeschlagen. \(message)")
        }
    }
}
