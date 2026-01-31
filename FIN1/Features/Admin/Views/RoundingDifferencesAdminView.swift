import SwiftUI

struct RoundingDifferencesAdminView: View {
    @ObservedObject var viewModel: RoundingDifferencesViewModel

    var body: some View {
        List {
            Section(header: Text("Unreconciled")) {
                if viewModel.unreconciledDifferences.isEmpty {
                    Text("No rounding differences")
                        .font(ResponsiveDesign.bodyFont())
                        .foregroundColor(AppTheme.fontColor.opacity(0.7))
                } else {
                    ForEach(viewModel.unreconciledDifferences) { item in
                        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(4)) {
                            Text(item.transactionType.rawValue.replacingOccurrences(of: "_", with: " "))
                                .font(ResponsiveDesign.headlineFont())
                                .foregroundColor(AppTheme.fontColor)
                            Text("TX: \(item.transactionId)")
                                .font(ResponsiveDesign.captionFont())
                                .foregroundColor(AppTheme.fontColor.opacity(0.8))
                            HStack {
                                Text("Original: \(item.originalAmount, format: .currency(code: "EUR"))")
                                Text("Rounded: \(item.roundedAmount, format: .currency(code: "EUR"))")
                                Text("Δ: \(item.difference, format: .currency(code: "EUR"))")
                                    .foregroundColor(item.difference >= 0 ? AppTheme.accentGreen : AppTheme.accentRed)
                            }
                            .font(ResponsiveDesign.captionFont())
                            .foregroundColor(AppTheme.fontColor)
                        }
                        .responsivePadding()
                    }
                }
            }

            Section(header: Text("Summary")) {
                HStack {
                    Text("Total Balance")
                    Spacer()
                    Text(viewModel.totalRoundingBalance, format: .currency(code: "EUR"))
                        .foregroundColor(viewModel.totalRoundingBalance >= 0 ? AppTheme.accentGreen : AppTheme.accentRed)
                }
                .font(ResponsiveDesign.bodyFont())
                .foregroundColor(AppTheme.fontColor)
            }
        }
        .navigationTitle("Rounding Differences")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Reconcile All") {
                    Task { await viewModel.reconcileAll() }
                }
                .disabled(viewModel.unreconciledDifferences.isEmpty)
            }
        }
        .task { await viewModel.load() }
        .background(AppTheme.screenBackground)
    }
}
