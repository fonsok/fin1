import SwiftUI

// MARK: - Price Alert List View Wrapper
/// Wrapper to properly inject services from environment
struct PriceAlertListViewWrapper: View {
    @Environment(\.appServices) private var services
    
    var body: some View {
        PriceAlertListView(priceAlertService: services.priceAlertService)
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
                
                if viewModel.isLoading && viewModel.alerts.isEmpty {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                } else {
                    priceAlertContent
                }
            }
            .navigationTitle("Price Alerts")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showCreateAlert = true
                    }, label: {
                        Image(systemName: "plus")
                            .foregroundColor(AppTheme.accentLightBlue)
                    })
                }
            }
            .onAppear {
                Task {
                    await viewModel.loadAlerts()
                }
            }
            .sheet(isPresented: $showCreateAlert) {
                CreatePriceAlertView(priceAlertService: viewModel.priceAlertService)
            }
            .sheet(item: $selectedAlert) { alert in
                PriceAlertDetailView(alert: alert, priceAlertService: viewModel.priceAlertService)
            }
            .alert("Delete Alert", isPresented: $showDeleteConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    if let alert = alertToDelete {
                        Task {
                            await viewModel.deleteAlert(alert)
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
                if !viewModel.activeAlerts.isEmpty {
                    VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(12)) {
                        Text("Active Alerts")
                            .font(ResponsiveDesign.headlineFont())
                            .foregroundColor(AppTheme.fontColor)
                            .padding(.horizontal, ResponsiveDesign.spacing(16))
                        
                        ForEach(viewModel.activeAlerts) { alert in
                            PriceAlertCard(
                                alert: alert,
                                onTap: {
                                    selectedAlert = alert
                                },
                                onToggle: {
                                    Task {
                                        await viewModel.toggleAlertEnabled(alert)
                                    }
                                },
                                onDelete: {
                                    alertToDelete = alert
                                    showDeleteConfirmation = true
                                }
                            )
                            .padding(.horizontal, ResponsiveDesign.spacing(16))
                        }
                    }
                }
                
                // Triggered Alerts Section
                if !viewModel.triggeredAlerts.isEmpty {
                    VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(12)) {
                        Text("Triggered Alerts")
                            .font(ResponsiveDesign.headlineFont())
                            .foregroundColor(AppTheme.fontColor)
                            .padding(.horizontal, ResponsiveDesign.spacing(16))
                        
                        ForEach(viewModel.triggeredAlerts) { alert in
                            PriceAlertCard(
                                alert: alert,
                                onTap: {
                                    selectedAlert = alert
                                },
                                onToggle: {
                                    Task {
                                        await viewModel.toggleAlertEnabled(alert)
                                    }
                                },
                                onDelete: {
                                    alertToDelete = alert
                                    showDeleteConfirmation = true
                                }
                            )
                            .padding(.horizontal, ResponsiveDesign.spacing(16))
                        }
                    }
                }
                
                // Empty State
                if viewModel.alerts.isEmpty && !viewModel.isLoading {
                    PriceAlertEmptyState {
                        showCreateAlert = true
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
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(12)) {
                HStack {
                    VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(4)) {
                        Text(alert.symbol)
                            .font(ResponsiveDesign.headlineFont())
                            .foregroundColor(AppTheme.fontColor)
                        
                        Text(alertTypeDescription)
                            .font(ResponsiveDesign.captionFont())
                            .foregroundColor(AppTheme.secondaryText)
                    }
                    
                    Spacer()
                    
                    // Status Badge
                    statusBadge
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
                        get: { alert.isEnabled },
                        set: { _ in onToggle() }
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
        switch alert.alertType {
        case .above:
            return "Alert when price goes above threshold"
        case .below:
            return "Alert when price goes below threshold"
        case .change:
            return "Alert when price changes"
        }
    }
    
    private var statusBadge: some View {
        Text(alert.status.rawValue.capitalized)
            .font(ResponsiveDesign.captionFont())
            .foregroundColor(statusColor)
            .padding(.horizontal, ResponsiveDesign.spacing(8))
            .padding(.vertical, ResponsiveDesign.spacing(4))
            .background(statusColor.opacity(0.2))
            .cornerRadius(ResponsiveDesign.spacing(8))
    }
    
    private var statusColor: Color {
        switch alert.status {
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
            
            Button(action: onCreateAlert) {
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
