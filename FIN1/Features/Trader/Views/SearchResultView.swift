import SwiftUI

// MARK: - Main View
struct SearchResultView: View {
    let results: [SearchResult]
    let filterType: String
    let filterDescription: String
    let warrantDetailsViewModel: WarrantDetailsViewModel
    @State private var selectedResultForOrder: SearchResult?
    @Environment(\.appServices) private var appServices
    @State private var showWarrantDetails = false
    @Environment(\.themeManager) private var themeManager

    var body: some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(16)) {
            if results.isEmpty {
                // No results message
                VStack(spacing: ResponsiveDesign.spacing(12)) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: ResponsiveDesign.iconSize() * 2.4))
                        .foregroundColor(AppTheme.tertiaryText)

                    Text("Keine Treffer zur Filterkombination:")
                        .font(ResponsiveDesign.headlineFont())
                        .foregroundColor(AppTheme.fontColor)
                        .multilineTextAlignment(.center)

                    Text(filterDescription)
                        .font(ResponsiveDesign.bodyFont())
                        .foregroundColor(AppTheme.accentLightBlue)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, ResponsiveDesign.spacing(40))
                .background(AppTheme.sectionBackground)
                .cornerRadius(ResponsiveDesign.spacing(12))
            } else {
                // Results header
                HStack(spacing: ResponsiveDesign.spacing(0)) {
                    Text("\(filterType) - Suchergebnis: ")
                        .foregroundColor(AppTheme.secondaryText)
                    Text("\(results.count) Treffer")
                        .foregroundColor(AppTheme.accentGreen)
                }

                Button(action: {
                    showWarrantDetails = true
                }, label: {
                    HStack {
                        Text("Warrant details/tiles")
                        Image(systemName: "pencil")
                    }
                    .font(ResponsiveDesign.bodyFont())
                    .fontWeight(.light)
                    .foregroundColor(AppTheme.accentLightBlue)
                })

                // Results list with lazy loading for better performance
                LazyVStack(spacing: ResponsiveDesign.spacing(12)) {
                    ForEach(Array(results.enumerated()), id: \.offset) { index, result in
                        let directionLabel = result.direction ?? "-"
                        SearchResultCard(
                            result: result,
                            position: index + 1,
                            traderService: appServices.traderService,
                            directionLabel: directionLabel,
                            warrantDetailsViewModel: warrantDetailsViewModel,
                            onKaufenTapped: {
                                selectedResultForOrder = result
                            }
                        )
                    }
                }
            }
        }
        .sheet(item: $selectedResultForOrder) { result in
            BuyOrderViewWrapper(
                searchResult: result,
                traderService: appServices.traderService,
                cashBalanceService: appServices.cashBalanceService,
                configurationService: appServices.configurationService,
                investmentQuantityCalculationService: appServices.investmentQuantityCalculationService,
                investmentService: appServices.investmentService,
                userService: appServices.userService,
                traderDataService: appServices.traderDataService,
                auditLoggingService: appServices.auditLoggingService,
                transactionLimitService: appServices.transactionLimitService
            )
        }
        .sheet(isPresented: $showWarrantDetails) {
            WarrantDetailsView(viewModel: warrantDetailsViewModel)
        }
    }
}

// MARK: - Subcomponents
struct SearchResultCard: View {
    let result: SearchResult
    let position: Int
    let traderService: any TraderServiceProtocol
    let directionLabel: String
    @ObservedObject var warrantDetailsViewModel: WarrantDetailsViewModel
    var onKaufenTapped: () -> Void
    @StateObject private var viewModel: SearchResultCardViewModel
    @State private var showWatchlistToast = false
    @State private var watchlistToastMessage = ""

    init(result: SearchResult, position: Int, traderService: any TraderServiceProtocol, directionLabel: String, warrantDetailsViewModel: WarrantDetailsViewModel, onKaufenTapped: @escaping () -> Void) {
        self.result = result
        self.position = position
        self.traderService = traderService
        self.directionLabel = directionLabel
        self.warrantDetailsViewModel = warrantDetailsViewModel
        self.onKaufenTapped = onKaufenTapped
        self._viewModel = StateObject(wrappedValue: SearchResultCardViewModel(
            result: result,
            directionLabel: directionLabel,
            warrantDetailsViewModel: warrantDetailsViewModel
        ))
    }

    var body: some View {
        CardContainer(
            position: position,
            showWatchlistIcon: true,
            isInWatchlist: traderService.isInWatchlist(result.wkn),
            onPapersheetTapped: {
                openIssuerProductInfo()
            },
            onWatchlistTapped: {
                toggleWatchlist()
            },
            chevronButton: {
                AnyView(
                    Button(action: {
                        viewModel.toggleAdditionalDetails()
                    }, label: {
                        Image(systemName: viewModel.showAdditionalDetails ? "chevron.up" : "chevron.down")
                            .font(ResponsiveDesign.bodyFont())
                            .foregroundColor(AppTheme.secondaryText)
                    })
                    .buttonStyle(PlainButtonStyle())
                )
            }
        ) {
            VStack(spacing: ResponsiveDesign.spacing(8)) {
                // Main content grid using TileGrid - all logic in ViewModel
                TileGrid(tiles: viewModel.tiles, columns: 2)

                        // Full-width Buy button
                        Button(action: {
                            print("🔘 DEBUG: KAUFEN button tapped in SearchResultCard")
                            onKaufenTapped()
                        }, label: {
                            Text("KAUFEN")
                                .foregroundColor(AppTheme.fontColor)
                                .fontWeight(.bold)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, ResponsiveDesign.spacing(12))
                                .background(AppTheme.buttonColor)
                                .cornerRadius(ResponsiveDesign.spacing(8))
                        })
                        .buttonStyle(PlainButtonStyle())
                        .accessibilityIdentifier("KaufenButton_\(result.wkn)")
            }
        }
        .overlay(
            Group {
                if showWatchlistToast {
                    VStack {
                        Spacer()
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(AppTheme.accentGreen)
                            Text(watchlistToastMessage)
                                .font(ResponsiveDesign.bodyFont())
                                .foregroundColor(AppTheme.fontColor)
                        }
                        .padding(.horizontal, ResponsiveDesign.spacing(20))
                        .padding(.vertical, ResponsiveDesign.spacing(12))
                        .background(AppTheme.sectionBackground)
                        .cornerRadius(ResponsiveDesign.spacing(8))
                        .shadow(radius: 4)
                        Spacer()
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .animation(.easeInOut(duration: 0.3), value: showWatchlistToast)
                }
            }
        )
    }

    private func toggleWatchlist() {
        Task {
            do {
                if traderService.isInWatchlist(result.wkn) {
                    try await traderService.removeFromWatchlist(result.wkn)
                    await MainActor.run {
                        showToast("\(result.wkn) aus Watchlist entfernt")
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    }
                } else {
                    try await traderService.addToWatchlist(result)
                    await MainActor.run {
                        showToast("\(result.wkn) zur Watchlist hinzugefügt")
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    }
                }
            } catch {
                print("❌ Error toggling watchlist: \(error)")
            }
        }
    }

    private func showToast(_ message: String) {
        watchlistToastMessage = message
        showWatchlistToast = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
            showWatchlistToast = false
        }
    }

    private func openIssuerProductInfo() {
        // Open browser with issuer's product info page
        let wkn = result.wkn
        let issuerCode = String(wkn.prefix(2))
        let productInfoURL = "https://www.\(issuerCode.lowercased()).com/products/\(wkn)"

        if let url = URL(string: productInfoURL) {
            UIApplication.shared.open(url)
        }

        print("🔍 Opening product info for WKN: \(wkn) at \(productInfoURL)")
    }
}

// MARK: - Preview
#Preview {
    ZStack {
        AppTheme.screenBackground.ignoresSafeArea()
        SearchResultView(
            results: mockSearchResults,
            filterType: "Call",
            filterDescription: "Typ: Optionsscheine, Richtung: Call, Basiswert: Apple",
            warrantDetailsViewModel: WarrantDetailsViewModel()
        )
        .responsivePadding()
    }
}
