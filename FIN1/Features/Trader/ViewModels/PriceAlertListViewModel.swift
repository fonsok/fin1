import Combine
import Foundation

// MARK: - Price Alert List ViewModel
/// ViewModel for managing price alerts list
@MainActor
final class PriceAlertListViewModel: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var alerts: [PriceAlert] = []
    @Published var activeAlerts: [PriceAlert] = []
    @Published var triggeredAlerts: [PriceAlert] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var selectedAlert: PriceAlert?
    
    // MARK: - Dependencies
    
    let priceAlertService: (any PriceAlertServiceProtocol)?
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    init(priceAlertService: (any PriceAlertServiceProtocol)? = nil) {
        self.priceAlertService = priceAlertService
        self.setupObservers()
    }
    
    // MARK: - Public Methods
    
    func loadAlerts() async {
        await MainActor.run {
            self.isLoading = true
            self.errorMessage = nil
        }
        
        do {
            try await self.priceAlertService?.loadAlerts()
            self.updateAlerts()
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
            }
        }
        
        await MainActor.run {
            self.isLoading = false
        }
    }
    
    func deleteAlert(_ alert: PriceAlert) async {
        do {
            try await self.priceAlertService?.deleteAlert(alert.id)
            await self.loadAlerts()
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
            }
        }
    }
    
    func toggleAlertEnabled(_ alert: PriceAlert) async {
        do {
            try await self.priceAlertService?.setAlertEnabled(alert.id, enabled: !alert.isEnabled)
            await self.loadAlerts()
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func setupObservers() {
        // Observe price alert service updates
        if let service = priceAlertService as? PriceAlertService {
            service.$activeAlerts
                .receive(on: DispatchQueue.main)
                .sink { [weak self] activeAlerts in
                    self?.activeAlerts = activeAlerts
                    self?.updateAlertsLists()
                }
                .store(in: &self.cancellables)
            
            service.$allAlerts
                .receive(on: DispatchQueue.main)
                .sink { [weak self] allAlerts in
                    self?.alerts = allAlerts
                    self?.updateAlertsLists()
                }
                .store(in: &self.cancellables)
        }
        
        // Observe price alert triggered notifications
        NotificationCenter.default.publisher(for: .priceAlertTriggered)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                Task {
                    await self?.loadAlerts()
                }
            }
            .store(in: &self.cancellables)
    }
    
    @MainActor
    private func updateAlerts() {
        if let service = priceAlertService as? PriceAlertService {
            self.alerts = service.allAlerts
            self.updateAlertsLists()
        }
    }
    
    private func updateAlertsLists() {
        self.activeAlerts = self.alerts.filter { $0.status == .active && $0.isEnabled }
        self.triggeredAlerts = self.alerts.filter { $0.status == .triggered }
    }
}
