import SwiftUI

// MARK: - Price Alert List View Wrapper
/// Wrapper to properly inject services from environment
struct PriceAlertListViewWrapper: View {
    @Environment(\.appServices) private var services
    
    var body: some View {
        PriceAlertListView(priceAlertService: self.services.priceAlertService)
    }
}

// MARK: - Price Alert List View
/// View for displaying and managing price alerts
struct PriceAlertListView: View {
    @StateObject private var viewModel: PriceAlertListViewModel
    @State private var showCreateAlert = false
    @State private var selectedAlert: PriceAlert?
    @State private var showDeleteConfirmation = false
    @State private var alertToDelete: PriceAlert?
    
    init(priceAlertService: (any PriceAlertServiceProtocol)?) {
        _viewModel = StateObject(wrappedValue: PriceAlertListViewModel(priceAlertService: priceAlertService))
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.screenBackground
                    .ignoresSafeArea()
                
                if self.viewModel.isLoading && self.viewModel.alerts.isEmpty {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                } else {
                    self.priceAlertContent
                }
            }
            .navigationTitle("Price Alerts")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        self.showCreateAlert = true
                    }, label: {
                        Image(systemName: "plus")
                            .foregroundColor(AppTheme.accentLightBlue)
                    })
                }
            }
            .onAppear {
                Task {
                    await self.viewModel.loadAlerts()
                }
            }
            .sheet(isPresented: self.$showCreateAlert) {
                CreatePriceAlertView(priceAlertService: self.viewModel.priceAlertService)
            }
            .sheet(item: self.$selectedAlert) { alert in
                PriceAlertDetailView(alert: alert, priceAlertService: self.viewModel.priceAlertService)
            }
            .alert("Delete Alert", isPresented: self.$showDeleteConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    if let alert = alertToDelete {
                        Task {
                            await self.viewModel.deleteAlert(alert)
                        }
                    }
                }
            } message: {
                Text("Are you sure you want to delete this price alert?")
            }
        }
    }
    
    // MARK: - Content
    
    private var priceAlertContent: some View {
        ScrollView {
            VStack(spacing: ResponsiveDesign.spacing(16)) {
                // Active Alerts Section
                if !self.viewModel.activeAlerts.isEmpty {
                    VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(12)) {
                        Text("Active Alerts")
                            .font(ResponsiveDesign.headlineFont())
                            .foregroundColor(AppTheme.fontColor)
                            .padding(.horizontal, ResponsiveDesign.spacing(16))
                        
                        ForEach(self.viewModel.activeAlerts) { alert in
                            PriceAlertCard(
                                alert: alert,
                                onTap: {
                                    self.selectedAlert = alert
                                },
                                onToggle: {
                                    Task {
                                        await self.viewModel.toggleAlertEnabled(alert)
                                    }
                                },
                                onDelete: {
                                    self.alertToDelete = alert
                                    self.showDeleteConfirmation = true
                                }
                            )
                            .padding(.horizontal, ResponsiveDesign.spacing(16))
                        }
                    }
                }
                
                // Triggered Alerts Section
                if !self.viewModel.triggeredAlerts.isEmpty {
                    VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(12)) {
                        Text("Triggered Alerts")
                            .font(ResponsiveDesign.headlineFont())
                            .foregroundColor(AppTheme.fontColor)
                            .padding(.horizontal, ResponsiveDesign.spacing(16))
                        
                        ForEach(self.viewModel.triggeredAlerts) { alert in
                            PriceAlertCard(
                                alert: alert,
                                onTap: {
                                    self.selectedAlert = alert
                                },
                                onToggle: {
                                    Task {
                                        await self.viewModel.toggleAlertEnabled(alert)
                                    }
                                },
                                onDelete: {
                                    self.alertToDelete = alert
                                    self.showDeleteConfirmation = true
                                }
                            )
                            .padding(.horizontal, ResponsiveDesign.spacing(16))
                        }
                    }
                }
                
                // Empty State
                if self.viewModel.alerts.isEmpty && !self.viewModel.isLoading {
                    PriceAlertEmptyState {
                        self.showCreateAlert = true
                    }
                    .padding(.top, ResponsiveDesign.spacing(40))
                }
            }
            .padding(.vertical, ResponsiveDesign.spacing(16))
        }
    }
}

// MARK: - Price Alert Card
struct PriceAlertCard: View {
    let alert: PriceAlert
    let onTap: () -> Void
    let onToggle: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        Button(action: self.onTap) {
            VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(12)) {
                HStack {
                    VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(4)) {
                        Text(self.alert.symbol)
                            .font(ResponsiveDesign.headlineFont())
                            .foregroundColor(AppTheme.fontColor)
                        
                        Text(self.alertTypeDescription)
                            .font(ResponsiveDesign.captionFont())
                            .foregroundColor(AppTheme.secondaryText)
                    }
                    
                    Spacer()
                    
                    // Status Badge
                    self.statusBadge
                }
                
                // Alert Details
                HStack {
                    if let thresholdPrice = alert.thresholdPrice {
                        Text("Threshold: €\(thresholdPrice, specifier: "%.2f")")
                            .font(ResponsiveDesign.captionFont())
                            .foregroundColor(AppTheme.secondaryText)
                    }
                    
                    if let thresholdChange = alert.thresholdChangePercent {
                        Text("Change: \(thresholdChange, specifier: "%.2f")%")
                            .font(ResponsiveDesign.captionFont())
                            .foregroundColor(AppTheme.secondaryText)
                    }
                    
                    Spacer()
                    
                    // Toggle Switch
                    Toggle("", isOn: Binding(
                        get: { self.alert.isEnabled },
                        set: { _ in self.onToggle() }
                    ))
                    .labelsHidden()
                }
            }
            .padding(ResponsiveDesign.spacing(16))
            .background(AppTheme.sectionBackground)
            .cornerRadius(ResponsiveDesign.spacing(12))
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var alertTypeDescription: String {
        switch self.alert.alertType {
        case .above:
            return "Alert when price goes above threshold"
        case .below:
            return "Alert when price goes below threshold"
        case .change:
            return "Alert when price changes"
        }
    }
    
    private var statusBadge: some View {
        Text(self.alert.status.rawValue.capitalized)
            .font(ResponsiveDesign.captionFont())
            .foregroundColor(self.statusColor)
            .padding(.horizontal, ResponsiveDesign.spacing(8))
            .padding(.vertical, ResponsiveDesign.spacing(4))
            .background(self.statusColor.opacity(0.2))
            .cornerRadius(ResponsiveDesign.spacing(8))
    }
    
    private var statusColor: Color {
        switch self.alert.status {
        case .active:
            return AppTheme.accentGreen
        case .triggered:
            return AppTheme.accentRed
        case .cancelled:
            return AppTheme.secondaryText
        case .expired:
            return AppTheme.secondaryText
        }
    }
}

// MARK: - Empty State
struct PriceAlertEmptyState: View {
    let onCreateAlert: () -> Void
    
    var body: some View {
        VStack(spacing: ResponsiveDesign.spacing(16)) {
            Image(systemName: "bell.slash")
                .font(ResponsiveDesign.scaledSystemFont(size: ResponsiveDesign.iconSize() * 2))
                .foregroundColor(AppTheme.tertiaryText)
            
            Text("No Price Alerts")
                .font(ResponsiveDesign.headlineFont())
                .foregroundColor(AppTheme.fontColor)
            
            Text("Create a price alert to get notified when prices reach your target")
                .font(ResponsiveDesign.bodyFont())
                .foregroundColor(AppTheme.secondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, ResponsiveDesign.spacing(32))
            
            Button(action: self.onCreateAlert) {
                Text("Create Alert")
                    .font(ResponsiveDesign.bodyFont())
                    .foregroundColor(.white)
                    .padding(.horizontal, ResponsiveDesign.spacing(24))
                    .padding(.vertical, ResponsiveDesign.spacing(12))
                    .background(AppTheme.accentLightBlue)
                    .cornerRadius(ResponsiveDesign.spacing(8))
            }
        }
    }
}
