import SwiftUI

// MARK: - Empty State View
struct WatchlistEmptyStateView: View {
    let userRole: UserRole?
    
    var body: some View {
        VStack(spacing: ResponsiveDesign.spacing(16)) {
            Image(systemName: "eye.slash")
                .font(ResponsiveDesign.scaledSystemFont(size: 48))
                .foregroundColor(AppTheme.fontColor.opacity(0.4))
            
            Text("No items in watchlist")
                .font(ResponsiveDesign.headlineFont())
                .foregroundColor(AppTheme.fontColor)
            
            Text(self.userRole == .investor ? 
                "Start watching traders to track their performance" : 
                "Start watching securities to monitor market movements")
                .font(ResponsiveDesign.bodyFont())
                .foregroundColor(AppTheme.fontColor.opacity(0.7))
                .multilineTextAlignment(.center)
            
            Button(action: {
                // TODO: Navigate to discovery/trading view
            }) {
                Text("Browse \(self.userRole == .investor ? "Traders" : "Securities")")
                    .font(ResponsiveDesign.bodyFont())
                    .fontWeight(.medium)
                    .foregroundColor(AppTheme.screenBackground)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(AppTheme.accentLightBlue)
                    .cornerRadius(ResponsiveDesign.spacing(8))
            }
        }
        .padding(ResponsiveDesign.spacing(32))
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Success Message Overlay
struct WatchlistSuccessMessageOverlay: View {
    let message: String
    let isVisible: Bool
    
    var body: some View {
        if self.isVisible {
            VStack {
                Spacer()
                
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(AppTheme.accentGreen)
                    
                    Text(self.message)
                        .font(ResponsiveDesign.bodyFont())
                        .fontWeight(.medium)
                        .foregroundColor(AppTheme.screenBackground)
                    
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(AppTheme.accentGreen.opacity(0.9))
                .cornerRadius(ResponsiveDesign.spacing(8))
                .padding(.horizontal, 16)
                .padding(.bottom, 100)
            }
            .transition(.move(edge: .bottom))
            .animation(.easeInOut(duration: 0.3), value: self.isVisible)
        }
    }
}
