import SwiftUI
import Foundation

// MARK: - Trader Credit Note Detail View

/// Displays detailed commission credit note for a trader
/// Shows individual investor contributions, gross profit breakdown, and total commission
struct TraderCreditNoteDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appServices) private var appServices
    @StateObject private var viewModel: TraderCreditNoteDetailViewModel

    let document: Document
    let tradeNumber: Int?
    /// Steuerung über Admin-Option: Commission-Breakdown-Tabelle anzeigen oder ausblenden.
    let showCommissionBreakdown: Bool

    // MARK: - Initialization

    init(document: Document, showCommissionBreakdown: Bool = true) {
        self.document = document
        self.tradeNumber = document.invoiceData?.tradeNumber
        self.showCommissionBreakdown = showCommissionBreakdown
        self._viewModel = StateObject(wrappedValue: TraderCreditNoteDetailViewModel())
    }

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(spacing: ResponsiveDesign.spacing(24)) {
                // Document Header (einheitliches Layout für alle Dokumente)
                DocumentHeaderLayoutView(
                    accountHolderName: viewModel.accountHolderName,
                    accountHolderAddress: document.invoiceData?.customerInfo.address,
                    accountHolderCity: document.invoiceData != nil ? "\(document.invoiceData!.customerInfo.postalCode) \(document.invoiceData!.customerInfo.city)" : nil,
                    documentDate: document.uploadedAt
                ) {
                    CreditNoteQRCodeView(document: document)
                }

                headerSection
                tradeInfoSection
                if showCommissionBreakdown {
                    commissionBreakdownSection
                }
                notesSections
                footerSection
            }
            .padding(.horizontal, ResponsiveDesign.horizontalPadding())
            .padding(.vertical, ResponsiveDesign.spacing(20))
        }
        .background(DocumentDesignSystem.documentBackground.ignoresSafeArea())
        .navigationTitle("Trader Commission Calculation")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.light, for: .navigationBar)
        .toolbarBackground(DocumentDesignSystem.documentBackground, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Done") { dismiss() }
                    .foregroundColor(DocumentDesignSystem.textColor)
                    .fontWeight(.medium)
            }
        }
        .task {
            viewModel.configure(with: appServices, document: document)
            await viewModel.loadBreakdown()
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(12)) {
            // Belegart "Gutschrift" - größere Schrift, direkt oberhalb Trade Nr.
            Text("Gutschrift")
                .font(ResponsiveDesign.headlineFont())
                .fontWeight(.bold)
                .foregroundColor(DocumentDesignSystem.textColor)

            Text("Commission Credit Note")
                .font(ResponsiveDesign.bodyFont())
                .foregroundColor(DocumentDesignSystem.textColorSecondary)
                .padding(.bottom, ResponsiveDesign.spacing(4))

            if let tradeNumber = tradeNumber {
                Text("Trade #\(String(format: "%03d", tradeNumber))")
                    .font(ResponsiveDesign.bodyFont())
                    .foregroundColor(DocumentDesignSystem.textColorSecondary)
            }

            // Belegnummer (Document Number) - gemäß GoB, unterhalb der Trade-Nummer
            if let documentNumber = document.accountingDocumentNumber {
                HStack {
                    Text("Belegnummer:")
                        .font(ResponsiveDesign.captionFont())
                        .foregroundColor(DocumentDesignSystem.textColorSecondary)
                    Text(documentNumber)
                        .font(ResponsiveDesign.captionFont())
                        .fontWeight(.medium)
                        .foregroundColor(DocumentDesignSystem.textColor)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .documentSection(level: 1)
    }

    // MARK: - Trade Info Section

    private var tradeInfoSection: some View {
        VStack(spacing: ResponsiveDesign.spacing(12)) {
            // Trade Period
            if let dates = viewModel.tradeDates {
                HStack {
                    Text("Zeitraum:")
                        .font(ResponsiveDesign.bodyFont())
                        .foregroundColor(DocumentDesignSystem.textColorSecondary)
                    Spacer()
                    Text("\(formatDate(dates.entry)) - \(formatDate(dates.exit))")
                        .font(ResponsiveDesign.bodyFont())
                        .fontWeight(.medium)
                        .foregroundColor(DocumentDesignSystem.textColor)
                }
            }

            Divider().background(DocumentDesignSystem.textColor.opacity(0.2))

            // Gross Profit Row
            HStack {
                Text("Bruttogewinn (Profit):")
                    .font(ResponsiveDesign.bodyFont())
                    .foregroundColor(DocumentDesignSystem.textColorSecondary)
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(viewModel.tradeGrossProfit.formatted(.currency(code: "EUR")))
                        .font(ResponsiveDesign.bodyFont())
                        .fontWeight(.semibold)
                        .foregroundColor(DocumentDesignSystem.textColor)
                    if viewModel.tradeROI != 0 {
                        Text("+\(String(format: "%.2f", viewModel.tradeROI))%")
                            .font(ResponsiveDesign.captionFont())
                            .foregroundColor(DocumentDesignSystem.textColorSecondary)
                    }
                }
            }

            // Total Commission Row
            HStack {
                Text("Commission (\(viewModel.formattedCommissionPercentage)):")
                    .font(ResponsiveDesign.bodyFont())
                    .foregroundColor(DocumentDesignSystem.textColorSecondary)
                Spacer()
                Text(viewModel.totalCommission.formatted(.currency(code: "EUR")))
                    .font(ResponsiveDesign.bodyFont())
                    .fontWeight(.bold)
                    .foregroundColor(DocumentDesignSystem.textColor)
            }
        }
        .documentSection(level: 2)
    }

    // MARK: - Commission Breakdown Section

    private var commissionBreakdownSection: some View {
        VStack(spacing: ResponsiveDesign.spacing(0)) {
            Text("Commission Calculation Breakdown")
                .font(ResponsiveDesign.headlineFont())
                .fontWeight(.semibold)
                .foregroundColor(DocumentDesignSystem.textColor)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.bottom, ResponsiveDesign.spacing(12))

            if viewModel.isLoading {
                ProgressView().padding()
            } else if let error = viewModel.errorMessage {
                errorView(message: error)
            } else if viewModel.breakdownItems.isEmpty {
                emptyStateView
            } else {
                CreditNoteCommissionTableView(
                    items: viewModel.breakdownItems,
                    totalCommission: viewModel.totalCommission,
                    commissionRateFormatted: viewModel.formattedCommissionRate
                )
            }
        }
    }

    // MARK: - Empty State View

    private var emptyStateView: some View {
        VStack(spacing: ResponsiveDesign.spacing(16)) {
            Image(systemName: "person.2.slash")
                .font(.system(size: 40))
                .foregroundColor(DocumentDesignSystem.textColorTertiary)

            Text("Keine Investoren")
                .font(ResponsiveDesign.headlineFont())
                .foregroundColor(DocumentDesignSystem.textColor)

            Text("No investors participated in this trade")
                .font(ResponsiveDesign.bodyFont())
                .foregroundColor(DocumentDesignSystem.textColorSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .documentSection(level: 2)
    }

    // MARK: - Error View

    private func errorView(message: String) -> some View {
        VStack(spacing: ResponsiveDesign.spacing(12)) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 32))
                .foregroundColor(DocumentDesignSystem.textColorTertiary)

            Text("Error")
                .font(ResponsiveDesign.headlineFont())
                .fontWeight(.semibold)
                .foregroundColor(DocumentDesignSystem.textColor)

            Text(message)
                .font(ResponsiveDesign.bodyFont())
                .foregroundColor(DocumentDesignSystem.textColorSecondary)
                .multilineTextAlignment(.center)

            Button(action: {
                Task { await viewModel.loadBreakdown() }
            }, label: {
                Text("Retry")
                    .font(ResponsiveDesign.bodyFont())
                    .fontWeight(.medium)
                    .foregroundColor(DocumentDesignSystem.textColor)
                    .padding(.horizontal, ResponsiveDesign.spacing(24))
                    .padding(.vertical, ResponsiveDesign.spacing(12))
                    .background(DocumentDesignSystem.sectionBackground(level: 3))
                    .overlay(
                        RoundedRectangle(cornerRadius: ResponsiveDesign.spacing(8))
                            .stroke(DocumentDesignSystem.textColor.opacity(0.3), lineWidth: 1)
                    )
                    .cornerRadius(ResponsiveDesign.spacing(8))
            })
        }
        .frame(maxWidth: .infinity)
        .documentSection(level: 2)
    }

    // MARK: - Notes Sections

    private var notesSections: some View {
        DocumentNotesSection(
            accountNumber: viewModel.accountNumber
        )
    }

    // MARK: - Footer Section

    private var footerSection: some View {
        VStack(spacing: ResponsiveDesign.spacing(8)) {
            Text("Commission is calculated as \(viewModel.formattedCommissionPercentage) of each investor's gross profit from this trade.")
                .font(ResponsiveDesign.captionFont())
                .foregroundColor(DocumentDesignSystem.textColorTertiary)
                .multilineTextAlignment(.center)

            Text("Document generated on \(formatDate(document.uploadedAt))")
                .font(ResponsiveDesign.captionFont())
                .foregroundColor(DocumentDesignSystem.textColorTertiary)
        }
        .padding(.top, ResponsiveDesign.spacing(16))
    }

    // MARK: - Formatting Helpers

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.locale = Locale(identifier: "de_DE")
        return formatter.string(from: date)
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        TraderCreditNoteDetailView(
            document: Document(
                userId: "test",
                name: "Test Credit Note",
                type: .traderCreditNote,
                status: .verified,
                fileURL: "",
                size: 0,
                uploadedAt: Date(),
                tradeId: "trade-001"
            )
        )
    }
}
