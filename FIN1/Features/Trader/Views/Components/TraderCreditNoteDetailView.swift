import Foundation
import SwiftUI

// MARK: - Trader Credit Note Detail View

/// Displays detailed commission credit note for a trader
/// Shows individual investor contributions, gross profit breakdown, and total commission
struct TraderCreditNoteDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appServices) private var appServices
    @StateObject private var viewModel: TraderCreditNoteDetailViewModel
    @State private var taxNoteSnippet: String?
    @State private var legalNoteSnippet: String?

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
                    accountHolderName: self.viewModel.accountHolderName,
                    accountHolderAddress: self.document.invoiceData?.customerInfo.address,
                    accountHolderCity: self.document.invoiceData != nil ? "\(self.document.invoiceData!.customerInfo.postalCode) \(self.document.invoiceData!.customerInfo.city)" : nil,
                    documentDate: self.document.uploadedAt
                ) {
                    CreditNoteQRCodeView(document: self.document)
                }

                self.headerSection
                self.tradeInfoSection
                if self.showCommissionBreakdown {
                    self.commissionBreakdownSection
                }
                self.notesSections
                self.footerSection
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
                Button("Done") { self.dismiss() }
                    .foregroundColor(DocumentDesignSystem.textColor)
                    .fontWeight(.medium)
            }
        }
        .task {
            self.viewModel.configure(with: self.appServices, document: self.document)
            await self.viewModel.loadBreakdown()
        }
        .task {
            let provider = LegalSnippetProvider(termsContentService: appServices.termsContentService)
            let language: TermsOfServiceDataProvider.Language = .german
            let taxPlaceholders = ["TAX_RATE": CalculationConstants.TaxRates.capitalGainsTaxWithSoli]
            async let taxTask = provider.text(
                for: .docTaxNoteSell,
                language: language,
                documentType: .terms,
                defaultText: DocumentNotesSection.defaultTaxNote,
                placeholders: taxPlaceholders
            )
            async let legalTask = provider.text(
                for: .docLegalNoteWphg,
                language: language,
                documentType: .terms,
                defaultText: DocumentNotesSection.defaultLegalNotePart1 + "\n\n" + DocumentNotesSection.defaultLegalNotePart2,
                placeholders: [:]
            )
            let (tax, legal) = await (taxTask, legalTask)
            self.taxNoteSnippet = tax
            self.legalNoteSnippet = legal
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
                    Text("\(self.formatDate(dates.entry)) - \(self.formatDate(dates.exit))")
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
                    Text(self.viewModel.tradeGrossProfit.formatted(.currency(code: "EUR")))
                        .font(ResponsiveDesign.bodyFont())
                        .fontWeight(.semibold)
                        .foregroundColor(DocumentDesignSystem.textColor)
                    if self.viewModel.tradeROI != 0 {
                        Text("+\(String(format: "%.2f", self.viewModel.tradeROI))%")
                            .font(ResponsiveDesign.captionFont())
                            .foregroundColor(DocumentDesignSystem.textColorSecondary)
                    }
                }
            }

            // Total Commission Row
            HStack {
                Text("Commission (\(self.viewModel.formattedCommissionPercentage)):")
                    .font(ResponsiveDesign.bodyFont())
                    .foregroundColor(DocumentDesignSystem.textColorSecondary)
                Spacer()
                Text(self.viewModel.totalCommission.formatted(.currency(code: "EUR")))
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

            if self.viewModel.isLoading {
                ProgressView().padding()
            } else if let error = viewModel.errorMessage {
                self.errorView(message: error)
            } else if self.viewModel.breakdownItems.isEmpty {
                self.emptyStateView
            } else {
                CreditNoteCommissionTableView(
                    items: self.viewModel.breakdownItems,
                    totalCommission: self.viewModel.totalCommission,
                    commissionRateFormatted: self.viewModel.formattedCommissionRate
                )
            }
        }
    }

    // MARK: - Empty State View

    private var emptyStateView: some View {
        VStack(spacing: ResponsiveDesign.spacing(16)) {
            Image(systemName: "person.2.slash")
                .font(ResponsiveDesign.scaledSystemFont(size: ResponsiveDesign.iconSize() * 2))
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
                .font(ResponsiveDesign.scaledSystemFont(size: ResponsiveDesign.iconSize() * 1.6))
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
                Task { await self.viewModel.loadBreakdown() }
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
            accountNumber: self.viewModel.accountNumber,
            taxNote: self.taxNoteSnippet,
            legalNote: self.legalNoteSnippet
        )
    }

    // MARK: - Footer Section

    private var footerSection: some View {
        VStack(spacing: ResponsiveDesign.spacing(8)) {
            Text(
                "Commission is calculated as \(self.viewModel.formattedCommissionPercentage) of each investor's gross profit from this trade."
            )
            .font(ResponsiveDesign.captionFont())
            .foregroundColor(DocumentDesignSystem.textColorTertiary)
            .multilineTextAlignment(.center)

            Text("Document generated on \(self.formatDate(self.document.uploadedAt))")
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
