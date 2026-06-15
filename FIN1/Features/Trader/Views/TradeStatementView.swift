import SwiftUI

// MARK: - Trade Statement View
/// Displays a comprehensive trade statement similar to German financial documents
struct TradeStatementView: View {
    @ObservedObject var viewModel: TradeStatementViewModel
    @State private var showingPDFPreview = false
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appServices) private var services
    let showCustomBackButton: Bool
    let isInvoiceComparisonMode: Bool
    let comparisonNavigationTitle: String?

    // Server-driven Collection Bill texts (with strong local fallback)
    @State private var referenceText: String = TradeStatementReferenceSection.defaultReferenceText
    @State private var legalDisclaimerText: String = TradeStatementDisplayDataBuilder.defaultLegalDisclaimer
    @State private var footerNoteText: String = TradeStatementReferenceSection.defaultFooterNote
    @State private var taxNoteSnippet: String?
    @State private var legalNoteSnippet: String?

    init(
        viewModel: TradeStatementViewModel,
        showCustomBackButton: Bool = true,
        isInvoiceComparisonMode: Bool = false,
        comparisonNavigationTitle: String? = nil
    ) {
        self.viewModel = viewModel
        self.showCustomBackButton = showCustomBackButton
        self.isInvoiceComparisonMode = isInvoiceComparisonMode
        self.comparisonNavigationTitle = comparisonNavigationTitle
    }

    var body: some View {
        GeometryReader { geometry in
            // Calculate document width for proper display in both orientations
            let screenWidth = geometry.size.width
            let screenHeight = geometry.size.height
            let isLandscape = screenWidth > screenHeight

            // In landscape, use more of the available width for better readability
            // In portrait, maintain a narrower document-like appearance
            let documentWidth: CGFloat = {
                if isLandscape {
                    // In landscape, use up to 70% of screen width, minimum 400pt for readability
                    return max(400, min(screenWidth * 0.7, 600))
                } else {
                    // In portrait, use 95% of screen width with aspect ratio constraint
                    let a4AspectRatio: CGFloat = 210.0 / 297.0
                    let maxWidth = screenWidth * 0.95
                    let maxHeight = screenHeight * 0.9
                    return min(maxWidth, maxHeight * a4AspectRatio)
                }
            }()
            let a4Width = documentWidth

            ScrollView([.vertical, .horizontal], showsIndicators: true) {
                VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(16)) {
                    if self.viewModel.displayDataSource == .belegMetadataUnavailable {
                        self.belegMetadataUnavailableContent
                    } else {
                        if self.isInvoiceComparisonMode {
                            self.comparisonDetailBanner
                        }
                        // Document Header (einheitliches Layout für alle Dokumente)
                        if let displayProperties = viewModel.displayProperties {
                            DocumentHeaderLayoutView(
                                accountHolderName: displayProperties.depotHolder,
                                accountHolderAddress: self.viewModel.buyInvoice?.customerInfo.address,
                                accountHolderCity: self.viewModel.buyInvoice != nil ? "\(self.viewModel.buyInvoice!.customerInfo.postalCode) \(self.viewModel.buyInvoice!.customerInfo.city)" : nil,
                                documentDate: self.viewModel.trade.endDate
                            ) {
                                CollectionBillQRCodeView(trade: self.viewModel.trade, displayProperties: displayProperties)
                            }
                        }

                        // Document Number Section (Name removed - already shown in DocumentHeaderLayoutView)
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

                        // Account Information Section
                        if let displayProperties = viewModel.displayProperties {
                            TradeStatementHeaderView(
                                depotNumber: displayProperties.depotNumber,
                                depotHolder: displayProperties.depotHolder,
                                tradeNumber: self.viewModel.trade.tradeNumber
                            )
                        }

                        // KAUF Section
                        if let displayProperties = viewModel.displayProperties, displayProperties.hasBuyTransaction {
                            TradeStatementBuySection(
                                securityIdentifier: displayProperties.securityIdentifier,
                                underlyingAsset: self.viewModel.fullTrade?.underlyingAsset,
                                orderVolume: displayProperties.buyOrderVolume,
                                executedVolume: displayProperties.buyExecutedVolume,
                                price: displayProperties.buyPrice,
                                exchangeRate: displayProperties.buyExchangeRate,
                                conversionFactor: displayProperties.buyConversionFactor,
                                custodyType: displayProperties.buyCustodyType,
                                depository: displayProperties.buyDepository,
                                depositoryCountry: displayProperties.buyDepositoryCountry,
                                profitLoss: displayProperties.buyProfitLoss,
                                profitLossColor: displayProperties.buyProfitLossColor,
                                valueDate: displayProperties.buyValueDate,
                                tradingVenue: displayProperties.buyTradingVenue,
                                closingDate: displayProperties.buyClosingDate,
                                marketValue: displayProperties.buyMarketValue,
                                commission: displayProperties.buyCommission,
                                ownExpenses: displayProperties.buyOwnExpenses,
                                externalExpenses: displayProperties.buyExternalExpenses,
                                assessmentBasis: displayProperties.buyAssessmentBasis,
                                withheldTax: displayProperties.buyWithheldTax,
                                finalAmount: displayProperties.buyFinalAmount,
                                finalAmountColor: displayProperties.buyFinalAmountColor
                            )
                        }

                        // VERKAUF Section - Multiple Sell Orders
                        if let displayProperties = viewModel.displayProperties, displayProperties.hasSellTransaction {
                            TradeStatementSellSection(
                                sellOrderData: displayProperties.sellOrderData,
                                securityIdentifier: displayProperties.securityIdentifier,
                                underlyingAsset: self.viewModel.fullTrade?.underlyingAsset,
                                tradingVenue: displayProperties.sellTradingVenue,
                                profitLoss: displayProperties.sellProfitLoss,
                                profitLossColor: displayProperties.sellProfitLossColor,
                                assessmentBasis: displayProperties.sellAssessmentBasis,
                                withheldTax: displayProperties.sellWithheldTax,
                                finalAmountColor: displayProperties.sellFinalAmountColor
                            )
                        }

                        if let displayProperties = viewModel.displayProperties {
                            DocumentNotesSection(
                                accountNumber: displayProperties.accountNumber,
                                taxNote: self.taxNoteSnippet,
                                legalNote: self.legalNoteSnippet
                            )
                        }

                        // Reference Information and Legal Disclaimer
                        if let displayProperties = viewModel.displayProperties {
                            TradeStatementReferenceSection(
                                taxReportTransactionNumber: displayProperties.taxReportTransactionNumber,
                                accountNumber: displayProperties.accountNumber,
                                referenceText: self.referenceText,
                                legalDisclaimer: self.legalDisclaimerText,
                                footerNote: self.footerNoteText
                            )
                        }

                        // QR Code already shown in header section above
                    }
                }
                .frame(width: a4Width, alignment: .leading)
                .padding(ResponsiveDesign.spacing(16))
                .background(
                    // Dokument-Hintergrund mit Design-System
                    RoundedRectangle(cornerRadius: ResponsiveDesign.spacing(8))
                        .fill(DocumentDesignSystem.documentBackground)
                        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
                )
                .padding(ResponsiveDesign.spacing(16))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(AppTheme.screenBackground)
        }
        .navigationTitle(self.resolvedNavigationTitle)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            // Load server-driven snippets for Collection Bill reference texts (if available)
            let provider = LegalSnippetProvider(termsContentService: services.termsContentService)
            let language: TermsOfServiceDataProvider.Language = .german
            let taxMode = self.services.configurationService.taxCollectionMode
            let capitalGainsSide: DocumentTaxNoteTexts.CapitalGainsSide =
                (self.viewModel.displayProperties?.hasSellTransaction == true) ? .sell : .buy

            async let taxTask = provider.loadCapitalGainsTaxNote(
                mode: taxMode,
                side: capitalGainsSide,
                language: language
            )
            async let legalNoteTask = provider.text(
                for: .docLegalNoteWphg,
                language: language,
                documentType: .terms,
                defaultText: DocumentNotesSection.defaultLegalNotePart1 + "\n\n" + DocumentNotesSection.defaultLegalNotePart2,
                placeholders: [:]
            )

            async let referenceTask = provider.text(
                for: .docCollectionBillReferenceInfo,
                language: language,
                documentType: .terms,
                defaultText: TradeStatementReferenceSection.defaultReferenceText,
                placeholders: [:]
            )
            async let legalTask = provider.text(
                for: .docCollectionBillLegalDisclaimer,
                language: language,
                documentType: .terms,
                defaultText: TradeStatementDisplayDataBuilder.defaultLegalDisclaimer,
                placeholders: [:]
            )
            async let footerTask = provider.text(
                for: .docCollectionBillFooterNote,
                language: language,
                documentType: .terms,
                defaultText: TradeStatementReferenceSection.defaultFooterNote,
                placeholders: [:]
            )

            let (tax, legalNote, ref, legal, footer) = await (taxTask, legalNoteTask, referenceTask, legalTask, footerTask)
            self.taxNoteSnippet = tax
            self.legalNoteSnippet = legalNote
            self.referenceText = ref
            self.legalDisclaimerText = legal
            self.footerNoteText = footer
        }
        .toolbarColorScheme(.light, for: .navigationBar)
        .toolbarBackground(DocumentDesignSystem.documentBackground, for: .navigationBar)
        .toolbar {
            if self.showCustomBackButton {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        self.dismiss()
                    }, label: {
                        Image(systemName: "chevron.left")
                            .font(ResponsiveDesign.scaledSystemFont(size: ResponsiveDesign.iconSize(), weight: .medium))
                            .foregroundColor(AppTheme.accentLightBlue)
                    })
                }
            }

            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    // PDF Actions
                    Button(action: {
                        self.viewModel.generatePDFPreview()
                        self.showingPDFPreview = true
                    }, label: {
                        Label("PDF Vorschau", systemImage: "eye")
                    })

                    Button(action: {
                        self.viewModel.generatePDF()
                    }, label: {
                        Label("PDF Generieren", systemImage: "doc.badge.plus")
                    })

                    Button(action: {
                        self.viewModel.sharePDF()
                    }, label: {
                        Label("PDF Teilen", systemImage: "square.and.arrow.up")
                    })

                    Button(action: {
                        self.viewModel.downloadPDFViaBrowser()
                    }, label: {
                        Label("PDF Download", systemImage: "arrow.down.circle")
                    })

                    Divider()

                    // Additional Actions
                    Button(action: {
                        // Mark as read functionality
                        print("Mark collection bill as read")
                    }, label: {
                        Label("Als gelesen markieren", systemImage: "checkmark.circle")
                    })

                    Button(action: {
                        // Print functionality
                        print("Print collection bill")
                    }, label: {
                        Label("Drucken", systemImage: "printer")
                    })
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(ResponsiveDesign.scaledSystemFont(size: ResponsiveDesign.iconSize(), weight: .medium))
                        .foregroundColor(AppTheme.accentLightBlue)
                }
            }
        }
        .sheet(isPresented: self.$showingPDFPreview) {
            if let previewImage = viewModel.pdfPreviewImage {
                PDFPreviewView(image: previewImage)
            }
        }
        .alert("Fehler", isPresented: self.$viewModel.showError) {
            Button("OK") {
                self.viewModel.clearError()
            }
        } message: {
            Text(self.viewModel.errorMessage ?? "Ein unbekannter Fehler ist aufgetreten.")
        }
    }

    // headerSection removed - name is now shown in DocumentHeaderLayoutView, documentNumber shown separately

    private var resolvedNavigationTitle: String {
        if self.isInvoiceComparisonMode, let comparisonNavigationTitle, !comparisonNavigationTitle.isEmpty {
            return comparisonNavigationTitle
        }
        return "Collection Bill"
    }

    private var comparisonDetailBanner: some View {
        Group {
            if !self.viewModel.belegSnapshotMetadataDrifts.isEmpty {
                self.belegDriftWarningBanner
            }
            switch self.viewModel.displayDataSource {
            case .belegMetadataSSOT:
                self.belegMetadataSSOTBanner
            case .invoiceFallback:
                self.invoiceComparisonBanner
            case .belegMetadataUnavailable:
                EmptyView()
            }
        }
    }

    private var belegMetadataUnavailableContent: some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(12)) {
            HStack(alignment: .top, spacing: ResponsiveDesign.spacing(10)) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(AppTheme.accentRed)
                Text(self.viewModel.belegUnavailableMessage ?? TraderMonetaryMessages.belegDetailUnavailable)
                    .font(ResponsiveDesign.bodyFont())
                    .foregroundColor(DocumentDesignSystem.textColor)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let documentNumber = self.viewModel.documentNumber {
                Text("Belegnummer: \(documentNumber)")
                    .font(ResponsiveDesign.captionFont())
                    .foregroundColor(DocumentDesignSystem.textColorSecondary)
            }
            Text("Bitte den Klartext-Beleg auf dem vorherigen Bildschirm verwenden oder den Support kontaktieren.")
                .font(ResponsiveDesign.captionFont())
                .foregroundColor(DocumentDesignSystem.textColorSecondary)
        }
        .documentSection(level: 2)
    }

    private var belegDriftWarningBanner: some View {
        HStack(alignment: .top, spacing: ResponsiveDesign.spacing(10)) {
            Image(systemName: "exclamationmark.triangle")
                .foregroundColor(AppTheme.accentOrange)
            Text(
                "Abweichung zwischen Klartext-Beleg und Server-Metadaten: "
                    + self.viewModel.belegSnapshotMetadataDrifts.map(\.rawValue).joined(separator: ", ")
                    + ". Bitte Admin-Backfill prüfen."
            )
            .font(ResponsiveDesign.captionFont())
            .foregroundColor(DocumentDesignSystem.textColorSecondary)
            .fixedSize(horizontal: false, vertical: true)
        }
        .padding(ResponsiveDesign.spacing(12))
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.accentOrange.opacity(0.12))
        .cornerRadius(ResponsiveDesign.spacing(8))
    }

    private var belegMetadataSSOTBanner: some View {
        HStack(alignment: .top, spacing: ResponsiveDesign.spacing(10)) {
            Image(systemName: "checkmark.seal")
                .foregroundColor(AppTheme.accentGreen)
            Text(
                "Strukturierte Detailansicht aus dem GoB-Server-Beleg (Metadaten). Keine Rechnungssynthese."
            )
            .font(ResponsiveDesign.captionFont())
            .foregroundColor(DocumentDesignSystem.textColorSecondary)
            .fixedSize(horizontal: false, vertical: true)
        }
        .padding(ResponsiveDesign.spacing(12))
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.accentGreen.opacity(0.12))
        .cornerRadius(ResponsiveDesign.spacing(8))
    }

    private var invoiceComparisonBanner: some View {
        HStack(alignment: .top, spacing: ResponsiveDesign.spacing(10)) {
            Image(systemName: "info.circle")
                .foregroundColor(AppTheme.accentOrange)
            Text(
                "Vergleichsansicht aus der Rechnung. Der maßgebliche GoB-Beleg steht im vorherigen Bildschirm (Server-Snapshot)."
            )
            .font(ResponsiveDesign.captionFont())
            .foregroundColor(DocumentDesignSystem.textColorSecondary)
            .fixedSize(horizontal: false, vertical: true)
        }
        .padding(ResponsiveDesign.spacing(12))
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.accentOrange.opacity(0.12))
        .cornerRadius(ResponsiveDesign.spacing(8))
    }
}

// MARK: - Preview
#if DEBUG
struct TradeStatementView_Previews: PreviewProvider {
    static var previews: some View {
        let sampleTrade = TradeOverviewItem(
            tradeId: "sample-trade-id",
            tradeNumber: 288,
            startDate: Date().addingTimeInterval(-86_400),
            endDate: Date(),
            profitLoss: 1_712.57,
            returnPercentage: 23,
            commission: 45.14,
            isCommissionPending: false,
            isActive: false,
            statusText: "",
            statusDetail: "",
            onDetailsTapped: {},
            grossProfit: 1_750.0,
            totalFees: 37.43
        )

        TradeStatementView(viewModel: TradeStatementViewModel(trade: sampleTrade))
    }
}
#endif
