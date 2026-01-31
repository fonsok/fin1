import SwiftUI
import Combine

struct MarketDataRow: View {
    let underlyingAsset: String
    @Environment(\.appServices) private var services
    @State private var marketData: MarketData?
    @State private var cancellables = Set<AnyCancellable>()

    var body: some View {
        let displayData = marketData ?? getStaticMarketData(for: underlyingAsset)

        HStack(spacing: ResponsiveDesign.spacing(0)) {
            Text(displayData.price)
                .font(ResponsiveDesign.captionFont())
                .foregroundColor(AppTheme.fontColor.opacity(0.8))

            Text("|")
                .font(ResponsiveDesign.captionFont())
                .foregroundColor(AppTheme.fontColor.opacity(0.8))

            Text(displayData.change)
                .font(ResponsiveDesign.captionFont())
                .foregroundColor(AppTheme.accentGreen.opacity(0.8))

            Text("%")
                .font(ResponsiveDesign.captionFont())
                .foregroundColor(AppTheme.accentGreen.opacity(0.8))

            Text("|")
                .font(ResponsiveDesign.captionFont())
                .foregroundColor(AppTheme.fontColor.opacity(0.8))

            Text(displayData.time)
                .font(ResponsiveDesign.captionFont())
                .foregroundColor(AppTheme.fontColor.opacity(0.8))

            Text("|")
                .font(ResponsiveDesign.captionFont())
                .foregroundColor(AppTheme.fontColor.opacity(0.8))

            Text(displayData.market)
                .font(ResponsiveDesign.captionFont())
                .foregroundColor(AppTheme.fontColor.opacity(0.8))
        }
        .padding(.leading, ResponsiveDesign.spacing(12))
        .onAppear {
            setupMarketDataObserver()
            loadMarketData()
        }
    }
    
    private func setupMarketDataObserver() {
        // Observe market data updates
        NotificationCenter.default.publisher(for: .marketDataDidUpdate)
            .receive(on: DispatchQueue.main)
            .sink { notification in
                guard let userInfo = notification.userInfo,
                      let symbol = userInfo["symbol"] as? String,
                      symbol == underlyingAsset else {
                    return
                }
                
                // Update market data
                if let marketDataService = services.marketDataService,
                   let updatedData = marketDataService.getMarketData(for: symbol) {
                    marketData = updatedData
                }
            }
            .store(in: &cancellables)
    }
    
    private func loadMarketData() {
        // Try to get live market data first
        if let marketDataService = services.marketDataService,
           let liveData = marketDataService.getMarketData(for: underlyingAsset) {
            marketData = liveData
        } else {
            // Fallback to static data
            marketData = getStaticMarketData(for: underlyingAsset)
        }
    }

    private func getStaticMarketData(for underlyingAsset: String) -> MarketData {
        // Use shared MarketPriceService to ensure consistency with MockDataGenerator
        return MarketPriceService.getMarketData(for: underlyingAsset)
    }
}

#Preview {
    VStack(spacing: ResponsiveDesign.spacing(8)) {
        MarketDataRow(underlyingAsset: "DAX")
        MarketDataRow(underlyingAsset: "Apple")
        MarketDataRow(underlyingAsset: "Gold")
    }
    .padding()
    .background(AppTheme.screenBackground)
}
