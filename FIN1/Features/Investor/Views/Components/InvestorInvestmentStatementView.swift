import SwiftUI

// MARK: - Investor Investment Statement View
/// Investor-facing statement for a single investment,
/// modeled after TradeStatementView but scaled to the investor's share.
struct InvestorInvestmentStatementView: View {
    @ObservedObject var viewModel: InvestorInvestmentStatementViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appServices) private var services
    @State private var taxNoteSnippet: String?
    @State private var legalNoteSnippet: String?

    init(viewModel: InvestorInvestmentStatementViewModel) {
        self.viewModel = viewModel
    }

    var body: some View {
        GeometryReader { geometry in
            let screenWidth = geometry.size.width
            let screenHeight = geometry.size.height
            let a4AspectRatio: CGFloat = 210.0 / 297.0

            let maxWidth = screenWidth * 0.95
            let maxHeight = screenHeight * 0.9

            let a4Width = min(maxWidth, maxHeight * a4AspectRatio)

            ScrollView([.vertical, .horizontal], showsIndicators: true) {
                VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(16)) {
                    if self.viewModel.isRefreshingFromBackend {
                        HStack(spacing: ResponsiveDesign.spacing(8)) {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("Aktualisiere…")
                                .font(ResponsiveDesign.captionFont())
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, ResponsiveDesign.spacing(4))
                    }
                    if let msg = viewModel.backendRefreshMessage {
                        Text(msg)
                            .font(ResponsiveDesign.captionFont())
                            .foregroundColor(.secondary)
                            .padding(.vertical, ResponsiveDesign.spacing(4))
                    }
                    if let banner = viewModel.belegIntegrityBanner {
                        self.belegIntegrityBannerView(message: banner)
                    }
                    // Document Header (einheitliches Layout für alle Dokumente)
                    DocumentHeaderLayoutView(
                        accountHolderName: self.getInvestorDisplayName(),
                        accountHolderAddress: self.getInvestorAddress(),
                        accountHolderCity: self.getInvestorCity(),
                        documentDate: self.viewModel.investment.createdAt
                    ) {
                        if let documentNumber = viewModel.documentNumber {
                            InvestorCollectionBillQRCodeView(
                                investment: self.viewModel.investment,
                                documentNumber: documentNumber
                            )
                        } else {
                            // Placeholder if no document number
                            RoundedRectangle(cornerRadius: ResponsiveDesign.spacing(8))
                                .fill(Color.gray.opacity(0.3))
                                .frame(width: 120, height: 120)
                        }
                    }

                    // headerSection removed - title already shown in DocumentHeaderView, documentNumber shown below
                    // Show only document number if available
                    if let documentNumber = viewModel.documentNumber {
                        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(4)) {
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
                        .documentSection(level: 1)
                    }
                    if self.viewModel.statementItems.isEmpty, !self.viewModel.isRefreshingFromBackend {
                        self.belegIntegrityBannerView(
                            message: self.viewModel.backendRefreshMessage
                                ?? InvestorMonetaryMessages.noArchivedBeleg
                        )
                    }
                    ForEach(self.viewModel.statementItems) { item in
                        self.statementSection(for: item)
                    }
                    // Notes Sections (Verrechnung, Steuerhinweise, Rechtliche Hinweise)
                    self.notesSections
                }
                .frame(width: a4Width, alignment: .leading)
                .padding(ResponsiveDesign.spacing(16))
                .background(
                    RoundedRectangle(cornerRadius: ResponsiveDesign.spacing(8))
                        .fill(DocumentDesignSystem.documentBackground)
                        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
                )
                .padding(ResponsiveDesign.spacing(16))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(AppTheme.screenBackground)
        }
        .navigationTitle("Collection Bill")
        .navigationBarTitleDisplayMode(.inline)
        .task { await self.viewModel.refreshFromBackend() }
        .task {
            let provider = LegalSnippetProvider(termsContentService: services.termsContentService)
            let language: TermsOfServiceDataProvider.Language = .german
            let taxMode = self.services.configurationService.taxCollectionMode
            async let taxTask = provider.loadCapitalGainsTaxNote(
                mode: taxMode,
                side: .sell,
                language: language
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
        .toolbarColorScheme(.light, for: .navigationBar)
        .toolbarBackground(DocumentDesignSystem.documentBackground, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: {
                    self.dismiss()
                }) {
                    Image(systemName: "chevron.left")
                        .font(ResponsiveDesign.scaledSystemFont(size: ResponsiveDesign.iconSize(), weight: .medium))
                        .foregroundColor(AppTheme.accentLightBlue)
                }
            }
        }
    }

    // MARK: - Sections

    private func belegIntegrityBannerView(message: String) -> some View {
        HStack(alignment: .top, spacing: ResponsiveDesign.spacing(8)) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.orange)
            Text(message)
                .font(ResponsiveDesign.captionFont())
                .foregroundColor(DocumentDesignSystem.textColor)
        }
        .padding(ResponsiveDesign.spacing(8))
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: ResponsiveDesign.spacing(6))
                .fill(Color.orange.opacity(0.12))
        )
    }

    // headerSection removed - name and address are now shown in DocumentHeaderLayoutView

    private func getInvestorDisplayName() -> String {
        // Try to get investor user from UserService
        // Check if current user is the investor
        if let currentUser = services.userService.currentUser,
           currentUser.id == viewModel.investment.investorId {
            return currentUser.displayName
        }
        // Fallback: use username from email or investor ID
        // In a production app, you'd fetch the user by investorId from UserService
        return self.viewModel.investment.investorId.prefix(8).uppercased()
    }

    private func getInvestorAddress() -> String? {
        // Try to get investor user from UserService
        if let currentUser = services.userService.currentUser,
           currentUser.id == viewModel.investment.investorId {
            return currentUser.streetAndNumber.isEmpty ? nil : currentUser.streetAndNumber
        }
        return nil
    }

    private func getInvestorCity() -> String? {
        // Try to get investor user from UserService
        if let currentUser = services.userService.currentUser,
           currentUser.id == viewModel.investment.investorId {
            let postalCode = currentUser.postalCode.isEmpty ? "" : currentUser.postalCode
            let city = currentUser.city.isEmpty ? "" : currentUser.city
            if !postalCode.isEmpty || !city.isEmpty {
                return "\(postalCode) \(city)".trimmingCharacters(in: .whitespaces)
            }
        }
        return nil
    }

    private func statementSection(for item: InvestorInvestmentStatementItem) -> some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(12)) {
            HStack {
                Text("\(self.viewModel.investment.traderName) – Trade #\(item.formattedTradeNumber)")
                    .font(ResponsiveDesign.headlineFont())
                    .foregroundColor(DocumentDesignSystem.textColor)
                Spacer()
                Text(item.tradeDate.formatted(Date.FormatStyle.localizedDate))
                    .font(ResponsiveDesign.captionFont())
                    .foregroundColor(DocumentDesignSystem.textColorSecondary)
            }

            if let belegMsg = item.belegInconsistencyMessage {
                self.belegIntegrityBannerView(message: belegMsg)
            } else if item.isProvisionalLocalEstimate, self.monetaryServerOnly {
                self.belegIntegrityBannerView(message: InvestorMonetaryMessages.provisionalSectionHint)
            } else if item.isProvisionalLocalEstimate {
                Text("Vorläufige Schätzung — archivierter Beleg auf dem Server fehlt noch.")
                    .font(ResponsiveDesign.captionFont())
                    .foregroundColor(.orange)
            }

            if !(self.monetaryServerOnly && item.isProvisionalLocalEstimate) {
                self.monetaryDetailSection(for: item)
            }
        }
        .documentSection(level: 2)
    }

    private var monetaryServerOnly: Bool {
        self.services.configurationService.investorMonetaryServerOnly
    }

    private func monetaryDetailSection(for item: InvestorInvestmentStatementItem) -> some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(12)) {
            Divider()
                .background(DocumentDesignSystem.textColor.opacity(0.2))

            // Buy row
            HStack {
                Text("Buy")
                    .font(ResponsiveDesign.bodyFont())
                    .foregroundColor(DocumentDesignSystem.textColor)
                Spacer()
                Text(
                    "\(NumberFormatter.localizedDecimalFormatter.string(for: item.buyQuantity) ?? "0,00") Stk @ \(item.buyPrice.formattedAsLocalizedCurrency())"
                )
                .font(ResponsiveDesign.bodyFont())
                .foregroundColor(DocumentDesignSystem.textColor)
            }

            HStack {
                Text("Buy Amount")
                    .font(ResponsiveDesign.captionFont())
                    .foregroundColor(DocumentDesignSystem.textColorSecondary)
                Spacer()
                Text(item.buyTotal.formattedAsLocalizedCurrency())
                    .font(ResponsiveDesign.captionFont())
                    .foregroundColor(DocumentDesignSystem.textColor)
            }

            self.feeDetailsSection(title: "Buy Fees", details: item.buyFeeDetails, totalAmount: item.buyFees)

            // Total Buy Cost row
            HStack {
                Text("Total Buy Cost")
                    .font(ResponsiveDesign.bodyFont())
                    .foregroundColor(DocumentDesignSystem.textColor)
                Spacer()
                Text(item.totalBuyCost.formattedAsLocalizedCurrency())
                    .font(ResponsiveDesign.bodyFont())
                    .foregroundColor(DocumentDesignSystem.textColor)
            }

            Divider()
                .background(DocumentDesignSystem.textColor.opacity(0.2))

            // Sell rows
            HStack {
                Text("Sell")
                    .font(ResponsiveDesign.bodyFont())
                    .foregroundColor(DocumentDesignSystem.textColor)
                Spacer()
                Text(
                    "\(NumberFormatter.localizedDecimalFormatter.string(for: item.sellQuantity) ?? "0,00") Stk @ \(item.sellAveragePrice.formattedAsLocalizedCurrency())"
                )
                .font(ResponsiveDesign.bodyFont())
                .foregroundColor(DocumentDesignSystem.textColor)
            }

            HStack {
                Text("Sell Amount")
                    .font(ResponsiveDesign.captionFont())
                    .foregroundColor(DocumentDesignSystem.textColorSecondary)
                Spacer()
                Text(item.sellTotal.formattedAsLocalizedCurrency())
                    .font(ResponsiveDesign.captionFont())
                    .foregroundColor(DocumentDesignSystem.textColor)
            }

            self.feeDetailsSection(title: "Sell Fees", details: item.sellFeeDetails, totalAmount: item.sellFeesDisplayAmount)

            // Net Sell Amount row
            HStack {
                Text("Net Sell Amount")
                    .font(ResponsiveDesign.bodyFont())
                    .foregroundColor(DocumentDesignSystem.textColor)
                Spacer()
                Text(item.netSellAmount.formattedAsLocalizedCurrency())
                    .font(ResponsiveDesign.bodyFont())
                    .foregroundColor(DocumentDesignSystem.textColor)
            }

            Divider()
                .background(DocumentDesignSystem.textColor.opacity(0.2))

            HStack {
                Text("Gross Profit (before commission & taxes)")
                    .font(ResponsiveDesign.bodyFont())
                    .foregroundColor(DocumentDesignSystem.textColor)
                Spacer()
                VStack(alignment: .trailing, spacing: ResponsiveDesign.spacing(2)) {
                    Text(item.grossProfit.formattedAsLocalizedCurrency())
                        .font(ResponsiveDesign.bodyFont())
                        .foregroundColor(item.grossProfit >= 0 ? AppTheme.accentGreen : AppTheme.accentRed)

                    // Return Percentage - uses trade's ROI (same for trader and all investors)
                    // This ensures consistency: if trade returns 100%, all participants see 100%
                    Text("\(item.tradeROI.formattedAsROIPercentage())")
                        .font(ResponsiveDesign.captionFont())
                        .foregroundColor(item.grossProfit >= 0 ? AppTheme.accentGreen : AppTheme.accentRed)
                }
            }

            // Commission row (using pre-calculated value from model - single source of truth)
            HStack {
                Text("Commission (\(self.services.configurationService.investorCommissionPercentage))")
                    .font(ResponsiveDesign.bodyFont())
                    .foregroundColor(DocumentDesignSystem.textColor)
                Spacer()
                Text(item.commission.formattedAsLocalizedCurrency())
                    .font(ResponsiveDesign.bodyFont())
                    .foregroundColor(DocumentDesignSystem.textColor)
            }

            Divider()
                .background(DocumentDesignSystem.textColor.opacity(0.2))

            VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(4)) {
                HStack {
                    Text("Überweisungsbetrag")
                        .font(ResponsiveDesign.bodyFont())
                        .foregroundColor(DocumentDesignSystem.textColor)
                    Spacer()
                    Text(item.transferAmount.formattedAsLocalizedCurrency())
                        .font(ResponsiveDesign.bodyFont())
                        .foregroundColor(DocumentDesignSystem.textColor)
                }

                Text(item.transferAmountCalculationNote)
                    .font(ResponsiveDesign.captionFont())
                    .foregroundColor(DocumentDesignSystem.textColorSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Divider()
                .background(DocumentDesignSystem.textColor.opacity(0.2))

            // Gross Profit (before taxes) row (using pre-calculated value from model)
            HStack {
                Text("Gross Profit (before taxes)")
                    .font(ResponsiveDesign.bodyFont())
                    .foregroundColor(DocumentDesignSystem.textColor)
                Spacer()
                Text(item.grossProfitAfterCommission.formattedAsLocalizedCurrency())
                    .font(ResponsiveDesign.bodyFont())
                    .foregroundColor(item.grossProfitAfterCommission >= 0 ? AppTheme.accentGreen : AppTheme.accentRed)
            }

            HStack {
                Text("Your ownership share")
                    .font(ResponsiveDesign.captionFont())
                    .foregroundColor(DocumentDesignSystem.textColorSecondary)
                Spacer()
                Text("\(NumberFormatter.localizedDecimalFormatter.string(for: (item.ownershipPercentage * 100)) ?? "0,00") %")
                    .font(ResponsiveDesign.captionFont())
                    .foregroundColor(DocumentDesignSystem.textColor)
            }
        }
    }

    private func feeDetailsSection(title: String, details: [InvestorFeeDetail], totalAmount: Double) -> some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(4)) {
            // Total fees row - total value on the right
            HStack {
                Text(title)
                    .font(ResponsiveDesign.captionFont())
                    .foregroundColor(DocumentDesignSystem.textColorSecondary)
                Spacer()
                Text(totalAmount.formattedAsLocalizedCurrency())
                    .font(ResponsiveDesign.captionFont())
                    .foregroundColor(DocumentDesignSystem.textColor)
            }

            // Individual fee items - left-aligned in separate column (not same column as total)
            if !details.isEmpty {
                VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(2)) {
                    ForEach(details) { detail in
                        HStack(alignment: .firstTextBaseline) {
                            HStack(spacing: ResponsiveDesign.spacing(2)) {
                                Text(detail.label)
                                    .font(ResponsiveDesign.captionFont())
                                    .foregroundColor(DocumentDesignSystem.textColorTertiary)
                                if let percentageRate = detail.percentageRate {
                                    Text("(\(percentageRate))")
                                        .font(ResponsiveDesign.captionFont())
                                        .foregroundColor(DocumentDesignSystem.textColorTertiary)
                                }
                            }
                            Text(detail.amount.formattedAsLocalizedCurrency())
                                .font(ResponsiveDesign.captionFont())
                                .foregroundColor(DocumentDesignSystem.textColor)
                        }
                    }
                }
                .padding(.leading, ResponsiveDesign.spacing(8))
            }
        }
    }

    // MARK: - Notes Sections

    private var notesSections: some View {
        DocumentNotesSection(
            accountNumber: self.getAccountNumber(),
            taxNote: self.taxNoteSnippet,
            legalNote: self.legalNoteSnippet
        )
    }

    private func getAccountNumber() -> String {
        // Try to get investor user from UserService
        if let currentUser = services.userService.currentUser,
           currentUser.id == viewModel.investment.investorId {
            // Generate a default depot number if not available (in real app, this would come from user's account)
            return "DE\(String(format: "%020d", abs(currentUser.id.hashValue)))"
        }
        // Fallback: use investment ID to generate account number
        return "DE\(String(format: "%020d", abs(self.viewModel.investment.id.hashValue)))"
    }
}
