import Foundation
import SwiftUI

// MARK: - Commission Breakdown Sheet

/// Displays detailed commission calculation breakdown for a trade
/// Shows individual investor contributions and total commission
struct CommissionBreakdownSheet: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: CommissionBreakdownViewModel
    @Environment(\.themeManager) private var themeManager

    init(tradeId: String, services: AppServices) {
        self._viewModel = StateObject(wrappedValue: CommissionBreakdownViewModel(
            tradeId: tradeId,
            services: services
        ))
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: ResponsiveDesign.spacing(0)) {
                if self.viewModel.isLoading {
                    ProgressView()
                        .padding()
                } else if self.viewModel.breakdownItems.isEmpty {
                    self.emptyStateView
                } else if let errorMessage = viewModel.errorMessage {
                    self.errorStateView(message: errorMessage)
                } else {
                    self.breakdownContentView
                }
            }
            .background(AppTheme.sectionBackground)
            .navigationTitle("Trader Commission Calculating")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        self.dismiss()
                    }
                }
            }
        }
        .task {
            await self.viewModel.loadBreakdown()
        }
    }

    // MARK: - View Components

    private var emptyStateView: some View {
        VStack(spacing: ResponsiveDesign.spacing(16)) {
            Text("Keine Investoren")
                .font(ResponsiveDesign.headlineFont())
                .foregroundColor(AppTheme.fontColor)
            Text("Für diesen Trade wurden keine Investoren-Provisionen berechnet.")
                .font(ResponsiveDesign.bodyFont())
                .foregroundColor(AppTheme.secondaryText)
                .multilineTextAlignment(.center)
        }
        .padding()
    }

    private func errorStateView(message: String) -> some View {
        VStack(spacing: ResponsiveDesign.spacing(16)) {
            Image(systemName: "exclamationmark.triangle")
                .font(ResponsiveDesign.scaledSystemFont(size: ResponsiveDesign.iconSize() * 2))
                .foregroundColor(.orange)
            Text("Fehler beim Laden")
                .font(ResponsiveDesign.headlineFont())
                .foregroundColor(AppTheme.fontColor)
            Text(message)
                .font(ResponsiveDesign.bodyFont())
                .foregroundColor(AppTheme.secondaryText)
                .multilineTextAlignment(.center)
            Button("Erneut versuchen") {
                Task {
                    await self.viewModel.loadBreakdown()
                }
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }

    private var breakdownContentView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // Table header
                HStack(spacing: ResponsiveDesign.spacing(12)) {
                    Text("Investor")
                        .font(ResponsiveDesign.bodyFont())
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Text("Gross profit")
                        .font(ResponsiveDesign.bodyFont())
                        .fontWeight(.semibold)
                        .frame(width: 110, alignment: .trailing)

                    Text("× \(self.viewModel.formattedCommissionRate)")
                        .font(ResponsiveDesign.bodyFont())
                        .fontWeight(.semibold)
                        .frame(width: 50, alignment: .center)

                    Text("Provision")
                        .font(ResponsiveDesign.bodyFont())
                        .fontWeight(.semibold)
                        .frame(width: 90, alignment: .trailing)
                }
                .padding(.horizontal, ResponsiveDesign.spacing(16))
                .padding(.vertical, ResponsiveDesign.spacing(6))
                .background(AppTheme.inputFieldBackground)

                // Table rows
                ForEach(self.viewModel.breakdownItems) { item in
                    HStack(spacing: ResponsiveDesign.spacing(12)) {
                        Text(item.investorName)
                            .font(ResponsiveDesign.bodyFont())
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        Text(item.grossProfit.formatted(.currency(code: "EUR")))
                            .font(ResponsiveDesign.bodyFont())
                            .frame(width: 110, alignment: .trailing)

                        Text("=")
                            .font(ResponsiveDesign.bodyFont())
                            .frame(width: 50, alignment: .center)

                        Text(item.commission.formatted(.currency(code: "EUR")))
                            .font(ResponsiveDesign.bodyFont())
                            .fontWeight(.medium)
                            .frame(width: 90, alignment: .trailing)
                    }
                    .padding(.horizontal, ResponsiveDesign.spacing(16))
                    .padding(.vertical, ResponsiveDesign.spacing(4))
                }

                // Total row
                HStack(spacing: ResponsiveDesign.spacing(12)) {
                    Text("Total:")
                        .font(ResponsiveDesign.bodyFont())
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Spacer()
                        .frame(width: 110)

                    Spacer()
                        .frame(width: 50)

                    Text(self.viewModel.totalCommission.formatted(.currency(code: "EUR")))
                        .font(ResponsiveDesign.bodyFont())
                        .fontWeight(.bold)
                        .frame(width: 90, alignment: .trailing)
                }
                .padding(.horizontal, ResponsiveDesign.spacing(16))
                .padding(.vertical, ResponsiveDesign.spacing(6))
                .background(AppTheme.inputFieldBackground.opacity(0.5))
            }
            .padding(.vertical, ResponsiveDesign.spacing(8))
        }
    }
}
