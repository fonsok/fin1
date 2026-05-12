import Foundation
import Combine

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
        setupObservers()
    }
    
    // MARK: - Public Methods
    
    func loadAlerts() async {
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }
        
        do {
            try await priceAlertService?.loadAlerts()
            updateAlerts()
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
            }
        }
        
        await MainActor.run {
            isLoading = false
        }
    }
    
    func deleteAlert(_ alert: PriceAlert) async {
        do {
            try await priceAlertService?.deleteAlert(alert.id)
            await loadAlerts()
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
            }
        }
    }
    
    func toggleAlertEnabled(_ alert: PriceAlert) async {
        do {
            try await priceAlertService?.setAlertEnabled(alert.id, enabled: !alert.isEnabled)
            await loadAlerts()
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
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
                .store(in: &cancellables)
            
            service.$allAlerts
                .receive(on: DispatchQueue.main)
                .sink { [weak self] allAlerts in
                    self?.alerts = allAlerts
                    self?.updateAlertsLists()
                }
                .store(in: &cancellables)
        }
        
        // Observe price alert triggered notifications
        NotificationCenter.default.publisher(for: .priceAlertTriggered)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                Task {
                    await self?.loadAlerts()
                }
            }
            .store(in: &cancellables)
    }
    
    @MainActor
    private func updateAlerts() {
        if let service = priceAlertService as? PriceAlertService {
            alerts = service.allAlerts
            updateAlertsLists()
        }
    }
    
    private func updateAlertsLists() {
        activeAlerts = alerts.filter { $0.status == .active && $0.isEnabled }
        triggeredAlerts = alerts.filter { $0.status == .triggered }
    }
}
