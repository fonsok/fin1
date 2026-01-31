import SwiftUI

// MARK: - Trade Statement View
/// Displays a comprehensive trade statement similar to German financial documents
struct TradeStatementView: View {
    @ObservedObject var viewModel: TradeStatementViewModel
    @State private var showingPDFPreview = false
    @Environment(\.dismiss) private var dismiss
    let showCustomBackButton: Bool

    init(viewModel: TradeStatementViewModel, showCustomBackButton: Bool = true) {
        self.viewModel = viewModel
        self.showCustomBackButton = showCustomBackButton
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
                    // Document Header (einheitliches Layout für alle Dokumente)
                    if let displayProperties = viewModel.displayProperties {
                        DocumentHeaderLayoutView(
                            accountHolderName: displayProperties.depotHolder,
                            accountHolderAddress: viewModel.buyInvoice?.customerInfo.address,
                            accountHolderCity: viewModel.buyInvoice != nil ? "\(viewModel.buyInvoice!.customerInfo.postalCode) \(viewModel.buyInvoice!.customerInfo.city)" : nil,
                            documentDate: viewModel.trade.endDate
                        ) {
                            CollectionBillQRCodeView(trade: viewModel.trade, displayProperties: displayProperties)
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
                            tradeNumber: viewModel.trade.tradeNumber
                        )
                    }

                    // KAUF Section
                    if let displayProperties = viewModel.displayProperties, displayProperties.hasBuyTransaction {
                        TradeStatementBuySection(
                            securityIdentifier: displayProperties.securityIdentifier,
                            underlyingAsset: viewModel.fullTrade?.underlyingAsset,
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
                            underlyingAsset: viewModel.fullTrade?.underlyingAsset,
                            profitLoss: displayProperties.sellProfitLoss,
                            profitLossColor: displayProperties.sellProfitLossColor,
                            assessmentBasis: displayProperties.sellAssessmentBasis,
                            withheldTax: displayProperties.sellWithheldTax,
                            finalAmountColor: displayProperties.sellFinalAmountColor
                        )
                    }

                    // Reference Information and Legal Disclaimer
                    if let displayProperties = viewModel.displayProperties {
                        TradeStatementReferenceSection(
                            taxReportTransactionNumber: displayProperties.taxReportTransactionNumber,
                            accountNumber: displayProperties.accountNumber,
                            legalDisclaimer: displayProperties.legalDisclaimer
                        )
                    }

                    // QR Code already shown in header section above
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
        .navigationTitle("Collection Bill")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.light, for: .navigationBar)
        .toolbarBackground(DocumentDesignSystem.documentBackground, for: .navigationBar)
        .toolbar {
            if showCustomBackButton {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        dismiss()
                    }, label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: ResponsiveDesign.iconSize(), weight: .medium))
                            .foregroundColor(AppTheme.accentLightBlue)
                    })
                }
            }

            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    // PDF Actions
                    Button(action: {
                        viewModel.generatePDFPreview()
                        showingPDFPreview = true
                    }, label: {
                        Label("PDF Vorschau", systemImage: "eye")
                    })

                    Button(action: {
                        viewModel.generatePDF()
                    }, label: {
                        Label("PDF Generieren", systemImage: "doc.badge.plus")
                    })

                    Button(action: {
                        viewModel.sharePDF()
                    }, label: {
                        Label("PDF Teilen", systemImage: "square.and.arrow.up")
                    })

                    Button(action: {
                        viewModel.downloadPDFViaBrowser()
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
                        .font(.system(size: ResponsiveDesign.iconSize(), weight: .medium))
                        .foregroundColor(AppTheme.accentLightBlue)
                }
            }
        }
        .sheet(isPresented: $showingPDFPreview) {
            if let previewImage = viewModel.pdfPreviewImage {
                PDFPreviewView(image: previewImage)
            }
        }
        .alert("Fehler", isPresented: $viewModel.showError) {
            Button("OK") {
                viewModel.clearError()
            }
        } message: {
            Text(viewModel.errorMessage ?? "Ein unbekannter Fehler ist aufgetreten.")
        }
    }

    // headerSection removed - name is now shown in DocumentHeaderLayoutView, documentNumber shown separately
}

// MARK: - Preview
#if DEBUG
struct TradeStatementView_Previews: PreviewProvider {
    static var previews: some View {
        let sampleTrade = TradeOverviewItem(
            tradeId: "sample-trade-id",
            tradeNumber: 288,
            startDate: Date().addingTimeInterval(-86400),
            endDate: Date(),
            profitLoss: 1712.57,
            returnPercentage: 23,
            commission: 45.14,
            isActive: false,
            statusText: "",
            statusDetail: "",
            onDetailsTapped: {},
            grossProfit: 1750.0,
            totalFees: 37.43
        )

        TradeStatementView(viewModel: TradeStatementViewModel(trade: sampleTrade))
    }
}
#endif
