import Foundation
@preconcurrency import Dispatch
import Combine

// MARK: - Configuration Service Implementation
/// Manages application configuration settings with admin controls
/// Note: Safe to use with DispatchQueue.async closures due to [weak self] capture pattern
final class ConfigurationService: ConfigurationServiceProtocol, ServiceLifecycle, @unchecked Sendable {

    // MARK: - Change Publisher
    lazy var configurationChanged: AnyPublisher<Void, Never> = {
        objectWillChange.map { _ in () }.eraseToAnyPublisher()
    }()

    // MARK: - Published Properties
    @Published var minimumCashReserve: Double = 20.0
    @Published var initialAccountBalance: Double = 0.0
    @Published var poolBalanceDistributionStrategy: PoolBalanceDistributionStrategy = .immediateDistribution // internal(set) for extension access
    @Published var poolBalanceDistributionThreshold: Double = 5.0 // internal(set) for extension access
    @Published var traderCommissionRate: Double = 0.10 // internal(set) for extension access
    @Published var appServiceChargeRate: Double = 0.02 // internal(set) for extension access
    @Published var appServiceChargeRateCompanies: Double = 0.02 // internal(set) for extension access
    @Published var showCommissionBreakdownInCreditNote: Bool = true // internal(set) for extension access
    @Published var showDocumentReferenceLinksInAccountStatement: Bool = true // internal(set) for extension access
    @Published var maximumRiskExposurePercent: Double = 2.0 // internal(set) for extension access
    @Published var walletFeatureEnabled: Bool = false // internal(set) for extension access
    /// ADR-007 Phase-2 rollout flag. Mirrors `AppConfiguration.serviceChargeInvoiceFromBackend`.
    /// When `true`, iOS clients route service-charge-invoice creation through
    /// `bookAppServiceCharge` instead of writing the `Invoice` locally.
    @Published var serviceChargeInvoiceFromBackend: Bool = false
    @Published var serviceChargeLegacyClientFallbackEnabled: Bool = true
    @Published var minimumInvestmentAmount: Double = CalculationConstants.Investment.fallbackMinimumInvestmentAmount
    @Published var maximumInvestmentAmount: Double = CalculationConstants.Investment.fallbackMaximumInvestmentAmount
    @Published var slaMonitoringInterval: TimeInterval = 300.0 // 5 minutes default, internal(set) for extension access
    @Published var isAdminMode: Bool = false

    // MARK: - Parse Server Configuration
    var parseServerURL: String? {
        // Priority:
        // 1) Info.plist override (works on iOS devices)
        // 2) Environment variable (useful for local dev/tests)
        // 3) FIN1 server default (behind nginx on port 80)
        var resolved: String?

        if let value = Bundle.main.object(forInfoDictionaryKey: "FIN1ParseServerURL") as? String,
           !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            resolved = value
        }

        if let value = ProcessInfo.processInfo.environment["PARSE_SERVER_URL"],
           !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            resolved = value
        }

        if resolved == nil {
            // Canonical LAN Parse URL (WiFi NIC on iobox); Ethernet on same host: 192.168.178.20 — see NETZWERK_KONFIGURATION.md
            resolved = "https://192.168.178.24/parse"
        }

        // Simulator: use `FIN1_PARSE_SERVER_URL` from xcconfig (direct LAN HTTP recommended in FIN1-Dev).
        // Optional SSH tunnel: set launch env `PARSE_SERVER_URL=https://localhost:8443/parse` when using
        // `ssh -L 8443:127.0.0.1:443 user@host`.

        return resolved
    }

    var parseApplicationId: String? {
        // Priority:
        // 1) Info.plist (recommended via .xcconfig)
        // 2) Environment variable (useful for local dev/tests)
        // 3) Default
        if let value = Bundle.main.object(forInfoDictionaryKey: "FIN1ParseApplicationId") as? String,
           !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return value
        }
        if let value = ProcessInfo.processInfo.environment["PARSE_APPLICATION_ID"],
           !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return value
        }
        return "fin1-app-id"
    }

    var parseLiveQueryURL: String? {
        // Convert http/https to ws/wss for Live Query
        guard let serverURL = parseServerURL else { return nil }
        return serverURL
            .replacingOccurrences(of: "http://", with: "ws://")
            .replacingOccurrences(of: "https://", with: "wss://")
    }

    // MARK: - Private Properties
    var configuration: AppConfiguration = .default // internal for extension access
    let userService: any UserServiceProtocol // internal for extension access
    let queue = DispatchQueue(label: "com.fin.app.configuration", attributes: .concurrent) // internal for extension access
    let configurationKey = "FIN1_AppConfiguration"
    var parseAPIClient: (any ParseAPIClientProtocol)?

    // MARK: - Initialization
    init(userService: any UserServiceProtocol) {
        self.userService = userService
        loadConfiguration()
        setupUserRoleObservation()
        setupRemoteConfigRefreshOnSignIn()
    }

    /// Injects Parse API client for fetching/saving config from Parse (getConfig / updateConfig).
    func configureParseAPIClient(_ client: (any ParseAPIClientProtocol)?) {
        queue.sync(flags: .barrier) { [weak self] in
            self?.parseAPIClient = client
        }
        Task { [weak self] in
            await self?.fetchRemoteDisplayConfig()
        }
    }

    /// After sign-in, financial parameters must match the authenticated session / server (not cold-start defaults).
    private func setupRemoteConfigRefreshOnSignIn() {
        NotificationCenter.default.publisher(for: .userDidSignIn)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                Task { @MainActor [weak self] in
                    await self?.fetchRemoteDisplayConfig()
                }
            }
            .store(in: &cancellables)
    }

    private var cancellables = Set<AnyCancellable>()
}
