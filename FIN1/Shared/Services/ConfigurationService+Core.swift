import Foundation

extension ConfigurationService {
    // MARK: - ServiceLifecycle
    func start() {
        self.loadConfiguration()
        self.updateAdminModeStatus()
        Task { await self.fetchRemoteDisplayConfig() }
    }

    func stop() {
        // Configuration service doesn't need cleanup
    }

    func reset() {
        configuration = .default
        self.updatePublishedValues()
        self.saveConfiguration()
    }

    // MARK: - Validation
    func validateMinimumCashReserve(_ value: Double) -> Bool { value >= 0.01 && value <= 1_000.0 }
    func validateInitialAccountBalance(_ value: Double) -> Bool { value >= 0.0 && value <= 1_000_000.0 }
    func validatePoolBalanceDistributionThreshold(_ value: Double) -> Bool { value >= 1.0 && value <= 100.0 }
    func validateTraderCommissionRate(_ rate: Double) -> Bool { rate >= 0.0 && rate <= 1.0 }
    func validateAppServiceChargeRate(_ rate: Double) -> Bool { rate >= 0.0 && rate <= 0.1 }
    func validateSLAMonitoringInterval(_ interval: TimeInterval) -> Bool { interval >= 60.0 && interval <= 3_600.0 }
    func validateMaximumRiskExposurePercent(_ value: Double) -> Bool { value >= 0.0 && value <= 100.0 }

    func loadConfiguration() {
        queue.async { [weak self] in
            guard let self = self else { return }
            if let data = UserDefaults.standard.data(forKey: self.configurationKey),
               let config = try? JSONDecoder().decode(AppConfiguration.self, from: data) {
                self.configuration = config
                if self.configuration.traderCommissionRate == nil { self.configuration.traderCommissionRate = CalculationConstants.FeeRates.traderCommissionRate }
                if self.configuration.appServiceChargeRate == nil { self.configuration.appServiceChargeRate = CalculationConstants.ServiceCharges.appServiceChargeRate }
                if self.configuration.appServiceChargeRateCompanies == nil { self.configuration.appServiceChargeRateCompanies = self.configuration.appServiceChargeRate }
                if self.configuration.slaMonitoringInterval == 0 { self.configuration.slaMonitoringInterval = 300.0 }
                if self.configuration.showCommissionBreakdownInCreditNote == nil { self.configuration.showCommissionBreakdownInCreditNote = true }
                if self.configuration.showDocumentReferenceLinksInAccountStatement == nil { self.configuration.showDocumentReferenceLinksInAccountStatement = true }
                if self.configuration.maximumRiskExposurePercent == nil { self.configuration.maximumRiskExposurePercent = 2.0 }
                if self.configuration.walletFeatureEnabled == nil { self.configuration.walletFeatureEnabled = false }
                let serviceChargeFlagMissing = self.configuration.serviceChargeInvoiceFromBackend == nil
                if serviceChargeFlagMissing { self.configuration.serviceChargeInvoiceFromBackend = false }
                let legacyFallbackFlagMissing = self.configuration.serviceChargeLegacyClientFallbackEnabled == nil
                if legacyFallbackFlagMissing { self.configuration.serviceChargeLegacyClientFallbackEnabled = true }
                if self.configuration.traderCommissionRate == nil || self.configuration.appServiceChargeRate == nil || self.configuration.appServiceChargeRateCompanies == nil || self.configuration.slaMonitoringInterval == 0 || self.configuration.showCommissionBreakdownInCreditNote == nil || self.configuration.showDocumentReferenceLinksInAccountStatement == nil || self.configuration.maximumRiskExposurePercent == nil || self.configuration.walletFeatureEnabled == nil || serviceChargeFlagMissing || legacyFallbackFlagMissing {
                    self.saveConfiguration()
                }
            } else {
                self.configuration = .default
                self.saveConfiguration()
            }

            Task { @MainActor in
                self.updatePublishedValues()
            }
        }
    }

    func saveConfiguration() {
        queue.async { [weak self] in
            guard let self = self else { return }
            if let data = try? JSONEncoder().encode(self.configuration) {
                UserDefaults.standard.set(data, forKey: self.configurationKey)
            }
        }
    }

    func updatePublishedValues() {
        minimumCashReserve = configuration.minimumCashReserve
        initialAccountBalance = configuration.initialAccountBalance
        poolBalanceDistributionStrategy = configuration.poolBalanceDistributionStrategy
        poolBalanceDistributionThreshold = configuration.poolBalanceDistributionThreshold
        traderCommissionRate = configuration.effectiveTraderCommissionRate
        appServiceChargeRate = configuration.effectiveAppServiceChargeRate
        appServiceChargeRateCompanies = configuration.effectiveAppServiceChargeRateCompanies
        showCommissionBreakdownInCreditNote = configuration.showCommissionBreakdownInCreditNote ?? true
        showDocumentReferenceLinksInAccountStatement = configuration.effectiveShowDocumentReferenceLinksInAccountStatement
        maximumRiskExposurePercent = configuration.effectiveMaximumRiskExposurePercent
        walletFeatureEnabled = configuration.effectiveWalletFeatureEnabled
        serviceChargeInvoiceFromBackend = configuration.effectiveServiceChargeInvoiceFromBackend
        serviceChargeLegacyClientFallbackEnabled = configuration.effectiveServiceChargeLegacyClientFallbackEnabled
        minimumInvestmentAmount = configuration.effectiveMinimumInvestment
        maximumInvestmentAmount = configuration.effectiveMaximumInvestment
        slaMonitoringInterval = configuration.slaMonitoringInterval
    }

    func setupUserRoleObservation() {
        self.updateAdminModeStatus()
    }

    func updateAdminModeStatus() {
        Task { @MainActor [weak self] in
            self?.isAdminMode = self?.userService.currentUser?.role == .admin
        }
    }

    func fetchRemoteDisplayConfig() async {
        let client: (any ParseAPIClientProtocol)? = queue.sync { parseAPIClient }
        guard let client = client else { return }
        do {
            let response: GetConfigResponse = try await client.callFunction(
                "getConfig",
                parameters: ["environment": "production"]
            )
            queue.async(flags: .barrier) { [weak self] in
                guard let self = self else { return }
                var changed = false

                if let f = response.financial {
                    let initial = f.initialAccountBalance ?? 0.0
                    if self.configuration.initialAccountBalance != initial { self.configuration.initialAccountBalance = initial; changed = true }
                    if let v = f.traderCommissionRate { self.configuration.traderCommissionRate = v; changed = true }
                    if let v = f.appServiceChargeRate ?? f.platformServiceChargeRate { self.configuration.appServiceChargeRate = v; changed = true }
                    if let v = f.appServiceChargeRateCompanies ?? f.platformServiceChargeRateCompanies {
                        self.configuration.appServiceChargeRateCompanies = v; changed = true
                    } else if self.configuration.appServiceChargeRateCompanies == nil {
                        self.configuration.appServiceChargeRateCompanies = self.configuration.appServiceChargeRate; changed = true
                    }
                    if let v = f.minimumCashReserve { self.configuration.minimumCashReserve = v; changed = true }
                }
                if let v = response.display?.showCommissionBreakdownInCreditNote { self.configuration.showCommissionBreakdownInCreditNote = v; changed = true }
                if let v = response.display?.showDocumentReferenceLinksInAccountStatement { self.configuration.showDocumentReferenceLinksInAccountStatement = v; changed = true }
                if let v = response.display?.maximumRiskExposurePercent { self.configuration.maximumRiskExposurePercent = v; changed = true }
                if let v = response.display?.walletFeatureEnabled { self.configuration.walletFeatureEnabled = v; changed = true }
                if let v = response.display?.serviceChargeInvoiceFromBackend { self.configuration.serviceChargeInvoiceFromBackend = v; changed = true }
                if let v = response.display?.serviceChargeLegacyClientFallbackEnabled { self.configuration.serviceChargeLegacyClientFallbackEnabled = v; changed = true }
                if let lim = response.limits {
                    if self.configuration.minInvestment != lim.minInvestment { self.configuration.minInvestment = lim.minInvestment; changed = true }
                    if self.configuration.maxInvestment != lim.maxInvestment { self.configuration.maxInvestment = lim.maxInvestment; changed = true }
                }

                if changed {
                    self.saveConfiguration()
                    Task { @MainActor in self.updatePublishedValues() }
                }
            }
        } catch {
            print("⚠️ ConfigurationService: Failed to fetch remote config: \(error.localizedDescription)")
        }
    }

    func refreshConfigurationFromServerIfAvailable() async {
        await self.fetchRemoteDisplayConfig()
    }

    func getParseAPIClient() -> (any ParseAPIClientProtocol)? {
        queue.sync { parseAPIClient }
    }
}
